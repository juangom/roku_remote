import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ecp2/ecp2_client.dart';
import '../ecp2/roku_keys.dart';
import '../models/roku_device.dart';

/// The remote control screen: connects to the device over ECP-2 and sends
/// key presses.
class RemotePage extends StatefulWidget {
  const RemotePage({super.key, required this.device});

  final RokuDevice device;

  @override
  State<RemotePage> createState() => _RemotePageState();
}

class _RemotePageState extends State<RemotePage> with WidgetsBindingObserver {
  late final Ecp2Client _client;
  bool _connecting = true;
  bool _muted = false;
  String? _error;
  Future<bool>? _connectFuture;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _client = Ecp2Client(host: widget.device.ip, port: widget.device.port)
      ..onDisconnected = _onDisconnected;
    _connect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // The OS may freeze the process and leave the socket half-open while
        // backgrounded, so drop it and reconnect cleanly on resume.
        _client.close();
      case AppLifecycleState.resumed:
        if (!_client.isConnected) _connect();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onDisconnected() {
    if (!mounted) return;
    _connect();
  }

  Future<void> _connect() async {
    await _connectInternal(showSpinner: true);
  }

  Future<bool> _connectInternal({required bool showSpinner}) {
    return _connectFuture ??= _doConnect(showSpinner: showSpinner);
  }

  Future<bool> _doConnect({required bool showSpinner}) async {
    if (mounted) {
      setState(() {
        if (showSpinner) _connecting = true;
        _error = null;
      });
    }
    try {
      await _client.connect();
      if (mounted) setState(() => _connecting = false);
      return true;
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = '$e';
        });
      }
      return false;
    } finally {
      _connectFuture = null;
    }
  }

  Future<void> _send(String key) async {
    HapticFeedback.lightImpact();
    try {
      await _client.keyPress(key);
      return;
    } on Ecp2Exception catch (e) {
      _showSnackBar('$e');
      return;
    } catch (_) {
      // The connection was likely dropped while the app was suspended:
      // reconnect once and retry the key before surfacing an error.
    }

    // Don't reconnect in the background; resume handles that instead.
    if (_lifecycleState != AppLifecycleState.resumed) return;

    final reconnected = await _connectInternal(showSpinner: false);
    if (!reconnected) return;

    try {
      await _client.keyPress(key);
    } catch (e) {
      _showSnackBar('$e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleMute() async {
    await _send(RokuKeys.mute);
    if (!mounted) return;
    setState(() => _muted = !_muted);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
      ),
      body: _connecting
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : _remoteView(),
    );
  }

  Widget _errorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Could not connect:\n$_error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _connect, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _remoteView() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                children: [
                  _powerRow(),
                  const SizedBox(height: 8),
                  _dpad(),
                ],
              ),
            ),
          ),
          _bottomControls(),
        ],
      ),
    );
  }

  Widget _bottomControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          _navRow(),
          const SizedBox(height: 12),
          _mediaRow(),
          const SizedBox(height: 12),
          _volumeRow(),
        ],
      ),
    );
  }

  Widget _powerRow() {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _send(RokuKeys.power),
              icon: const Icon(Icons.power_settings_new),
              tooltip: 'Power',
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text('Power', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Widget _dpad() {
    const gap = 28.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _circleButton(Icons.keyboard_arrow_up, () => _send(RokuKeys.up),
            tooltip: 'Up'),
        const SizedBox(height: gap),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _circleButton(
                Icons.keyboard_arrow_left, () => _send(RokuKeys.left),
                tooltip: 'Left'),
            const SizedBox(width: gap),
            SizedBox(
              width: 88,
              height: 88,
              child: FilledButton(
                onPressed: () => _send(RokuKeys.select),
                style: FilledButton.styleFrom(shape: const CircleBorder()),
                child: const Text('OK', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: gap),
            _circleButton(
                Icons.keyboard_arrow_right, () => _send(RokuKeys.right),
                tooltip: 'Right'),
          ],
        ),
        const SizedBox(height: gap),
        _circleButton(
            Icons.keyboard_arrow_down, () => _send(RokuKeys.down),
            tooltip: 'Down'),
      ],
    );
  }

  Widget _navRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _pill(Icons.arrow_back, 'Back', () => _send(RokuKeys.back)),
        _pill(Icons.home, 'Home', () => _send(RokuKeys.home)),
        _pill(Icons.star_border, 'Options', () => _send(RokuKeys.info)),
        _pill(Icons.search, 'Search', () => _send(RokuKeys.search)),
      ],
    );
  }

  Widget _mediaRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _pill(Icons.replay, 'Replay', () => _send(RokuKeys.replay)),
        _pill(Icons.fast_rewind, 'Rewind', () => _send(RokuKeys.rewind)),
        _pill(Icons.play_arrow, 'Play/Pause', () => _send(RokuKeys.play)),
        _pill(Icons.fast_forward, 'Forward', () => _send(RokuKeys.fastForward)),
      ],
    );
  }

  Widget _volumeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _pill(Icons.volume_down, 'Vol-', () => _send(RokuKeys.volumeDown)),
        _pill(
          _muted ? Icons.volume_off : Icons.volume_up,
          _muted ? 'Unmute' : 'Mute',
          _toggleMute,
        ),
        _pill(Icons.volume_up, 'Vol+', () => _send(RokuKeys.volumeUp)),
      ],
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap, {String? tooltip}) {
    return SizedBox(
      width: 72,
      height: 72,
      child: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(icon, size: 34),
        tooltip: tooltip,
      ),
    );
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 60,
          height: 60,
          child: IconButton.filledTonal(
            onPressed: onTap,
            icon: Icon(icon, size: 28),
            tooltip: label,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
