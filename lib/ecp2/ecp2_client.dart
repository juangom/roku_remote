import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

import 'ecp2_auth.dart';

/// Thrown when an ECP-2 request comes back with a non-200 status.
class Ecp2Exception implements Exception {
  Ecp2Exception(this.message);
  final String message;

  @override
  String toString() => 'Ecp2Exception: $message';
}

/// Client for the Roku ECP-2 WebSocket protocol.
///
/// Control goes over `ws://<ip>:8060/ecp-session` with subprotocol `ecp-2`.
/// This works even when the TV is set to ECP "limited" mode, where the plain
/// HTTP `/keypress/<Key>` API returns HTTP 403.
///
/// Protocol reference: docs/ECP2_PROTOCOL.md
class Ecp2Client {
  Ecp2Client({
    required this.host,
    this.port = 8060,
    this.friendlyName = 'flutter_remote',
    this.connectTimeout = const Duration(seconds: 8),
    this.requestTimeout = const Duration(seconds: 6),
  });

  final String host;
  final int port;
  final String friendlyName;
  final Duration connectTimeout;
  final Duration requestTimeout;

  IOWebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;

  int _requestId = 0;
  bool _authenticated = false;
  bool _closingIntentionally = false;
  bool _disconnectNotified = false;

  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  Completer<void> _authCompleter = Completer<void>();

  /// Called once when an established connection drops unexpectedly (not via
  /// [close]), e.g. the TV rebooted or the network went away.
  void Function()? onDisconnected;

  bool get isConnected => _channel != null && _authenticated;

  /// Opens the WebSocket and completes the SHA-1 auth handshake.
  ///
  /// Safe to call again to reconnect: any previous connection is torn down and
  /// the auth state is reset first.
  Future<void> connect() async {
    _closingIntentionally = true;
    await _teardown();
    _closingIntentionally = false;
    _disconnectNotified = false;
    _authCompleter = Completer<void>();

    final uri = Uri.parse('ws://$host:$port/ecp-session');
    final channel = IOWebSocketChannel.connect(
      uri,
      protocols: const ['ecp-2'],
      headers: const {'Origin': 'Android'},
      connectTimeout: connectTimeout,
    );
    _channel = channel;
    _sub = channel.stream.listen(
      _onMessage,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: false,
    );
    await _authCompleter.future.timeout(connectTimeout);
  }

  Future<void> _teardown() async {
    final sub = _sub;
    final channel = _channel;
    _sub = null;
    _channel = null;
    _authenticated = false;
    _failPending(StateError('connection closed'));
    await sub?.cancel();
    if (channel != null) {
      try {
        await channel.sink.close();
      } catch (_) {
        // The socket may already be dead; nothing left to close.
      }
    }
  }

  void _failPending(Object error) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }

  void _onMessage(dynamic data) {
    final Map<String, dynamic> msg;
    try {
      msg = json.decode(data as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (msg['notify'] == 'authenticate' && !_authenticated) {
      _sendAuthenticate(msg['param-challenge'] as String?);
      return;
    }

    final id = msg['response-id']?.toString();
    if (id != null && _pending.containsKey(id)) {
      final completer = _pending.remove(id)!;
      if (!completer.isCompleted) completer.complete(msg);
    }
  }

  void _onError(Object error, StackTrace stack) => _handleDisconnect(error);

  void _onDone() => _handleDisconnect(StateError('connection closed'));

  void _handleDisconnect(Object error) {
    _authenticated = false;
    if (!_authCompleter.isCompleted) _authCompleter.completeError(error);
    _failPending(error);
    if (!_closingIntentionally && !_disconnectNotified) {
      _disconnectNotified = true;
      onDisconnected?.call();
    }
  }

  Future<void> _sendAuthenticate(String? challenge) async {
    if (challenge == null) {
      if (!_authCompleter.isCompleted) {
        _authCompleter.completeError(Ecp2Exception('missing challenge'));
      }
      return;
    }
    try {
      final resp = await _request('authenticate', {
        'param-response': Ecp2Auth.response(challenge),
        'param-client-friendly-name': friendlyName,
      });
      if (_statusOk(resp)) {
        _authenticated = true;
        if (!_authCompleter.isCompleted) _authCompleter.complete();
      } else {
        throw Ecp2Exception('auth failed: ${resp['status-msg']}');
      }
    } catch (e) {
      if (!_authCompleter.isCompleted) _authCompleter.completeError(e);
    }
  }

  bool _statusOk(Map<String, dynamic> resp) =>
      resp['status']?.toString() == '200';

  Future<Map<String, dynamic>> _request(
    String request, [
    Map<String, dynamic> params = const {},
  ]) {
    final channel = _channel;
    if (channel == null) {
      return Future.error(StateError('not connected'));
    }
    final id = (++_requestId).toString();
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    channel.sink.add(json.encode({
      'request': request,
      'request-id': id,
      ...params,
    }));

    return completer.future.timeout(requestTimeout, onTimeout: () {
      _pending.remove(id);
      throw TimeoutException('request $request timed out');
    });
  }

  /// Sends a key press. [key] is a Roku key name (see [RokuKeys]).
  Future<void> keyPress(String key) async {
    final resp = await _request('key-press', {'param-key': key});
    if (!_statusOk(resp)) {
      throw Ecp2Exception('key-press $key: ${resp['status-msg'] ?? resp['status']}');
    }
  }

  /// Types [text] one character at a time via `Lit_<char>` keys.
  Future<void> sendText(String text) async {
    for (final ch in text.split('')) {
      final resp = await _request('key-press', {'param-key': 'Lit_$ch'});
      if (!_statusOk(resp)) {
        throw Ecp2Exception('text "$ch": ${resp['status-msg'] ?? resp['status']}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  Future<Map<String, dynamic>> _queryXml(String request) async {
    final resp = await _request(request);
    if (!_statusOk(resp)) {
      throw Ecp2Exception('$request: ${resp['status-msg'] ?? resp['status']}');
    }
    return resp;
  }

  /// Returns the raw device-info XML string.
  Future<String> deviceInfo() async {
    final resp = await _queryXml('query-device-info');
    final data = resp['content-data'] as String?;
    return data == null ? '' : utf8.decode(base64.decode(data));
  }

  /// Returns the raw installed-apps XML string.
  Future<String> installedApps() async {
    final resp = await _queryXml('query-apps');
    final data = resp['content-data'] as String?;
    return data == null ? '' : utf8.decode(base64.decode(data));
  }

  /// Launches an app by its Roku channel id.
  Future<void> launchApp(String channelId) async {
    final resp = await _request('launch', {'param-channel-id': channelId});
    if (!_statusOk(resp)) {
      throw Ecp2Exception('launch $channelId: ${resp['status-msg'] ?? resp['status']}');
    }
  }

  /// Closes the session. Does not fire [onDisconnected].
  Future<void> close() async {
    _closingIntentionally = true;
    await _teardown();
  }
}
