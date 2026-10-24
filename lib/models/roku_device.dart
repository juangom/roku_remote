/// A Roku device discovered on the local network.
class RokuDevice {
  const RokuDevice({
    required this.ip,
    this.port = 8060,
    this.name = 'Roku',
    this.model = 'Unknown',
    this.serial = '',
    this.softwareVersion = '',
  });

  final String ip;
  final int port;
  final String name;
  final String model;
  final String serial;
  final String softwareVersion;

  String get baseUrl => 'http://$ip:$port';

  @override
  String toString() => '$name ($model) — $ip';
}
