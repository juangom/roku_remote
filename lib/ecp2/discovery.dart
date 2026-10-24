import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/roku_device.dart';

/// Discovers Roku devices on the local network.
///
/// Two mechanisms, both working in ECP "limited" mode:
///  * SSDP `M-SEARCH` for `roku:ecp` on 239.255.255.250:1900.
///  * `GET http://<ip>:8060/query/device-info` for the friendly name/model.
class RokuDiscovery {
  RokuDiscovery._();

  static const ssdpAddress = '239.255.255.250';
  static const ssdpPort = 1900;

  static Future<List<RokuDevice>> discover({
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;

    final message = <String>[
      'M-SEARCH * HTTP/1.1',
      'HOST: $ssdpAddress:$ssdpPort',
      'MAN: "ssdp:discover"',
      'MX: 3',
      'ST: roku:ecp',
      '',
      '',
    ].join('\r\n');

    socket.send(utf8.encode(message), InternetAddress(ssdpAddress), ssdpPort);

    final ips = <String>{};
    final sub = socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final datagram = socket.receive();
        if (datagram == null) return;
        final text = utf8.decode(datagram.data, allowMalformed: true);
        if (text.toUpperCase().contains('ROKU')) {
          ips.add(datagram.address.address);
        }
      }
    });

    await Future<void>.delayed(timeout);
    await sub.cancel();
    socket.close();

    final devices = <RokuDevice>[];
    for (final ip in ips) {
      devices.add(await fetchDeviceInfo(ip));
    }
    devices.sort((a, b) => a.ip.compareTo(b.ip));
    return devices;
  }

  /// Reads device info over plain HTTP (`/query/device-info`), which Roku
  /// answers even in limited mode.
  static Future<RokuDevice> fetchDeviceInfo(
    String ip, {
    int port = 8060,
  }) async {
    try {
      final resp = await http
          .get(Uri.parse('http://$ip:$port/query/device-info'))
          .timeout(const Duration(seconds: 3));
      final xml = resp.body;
      return RokuDevice(
        ip: ip,
        port: port,
        name: _tag(xml, 'user-device-name') ??
            _tag(xml, 'friendly-device-name') ??
            'Roku',
        model: _tag(xml, 'model-name') ?? 'Unknown',
        serial: _tag(xml, 'serial-number') ?? '',
        softwareVersion: _tag(xml, 'software-version') ?? '',
      );
    } catch (_) {
      return RokuDevice(ip: ip, port: port);
    }
  }

  static String? _tag(String xml, String tag) {
    final start = xml.indexOf('<$tag>');
    final end = xml.indexOf('</$tag>');
    if (start == -1 || end == -1) return null;
    return xml.substring(start + tag.length + 2, end);
  }
}
