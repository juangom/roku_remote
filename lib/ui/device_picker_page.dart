import 'package:flutter/material.dart';

import '../ecp2/discovery.dart';
import '../models/roku_device.dart';
import 'remote_page.dart';

/// Scans the LAN for Roku devices and lets the user pick one.
class DevicePickerPage extends StatefulWidget {
  const DevicePickerPage({super.key});

  @override
  State<DevicePickerPage> createState() => _DevicePickerPageState();
}

class _DevicePickerPageState extends State<DevicePickerPage> {
  final List<RokuDevice> _devices = [];
  bool _scanning = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
      _devices.clear();
    });
    try {
      final found = await RokuDiscovery.discover();
      if (!mounted) return;
      setState(() {
        _devices.addAll(found);
        _scanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _error = 'Scan failed: $e';
      });
    }
  }

  Future<void> _addManually() async {
    final device = await showDialog<RokuDevice>(
      context: context,
      builder: (_) => const _AddDeviceDialog(),
    );
    if (device == null || !mounted) return;
    setState(() => _devices.add(device));
  }

  void _open(RokuDevice device) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RemotePage(device: device)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roku Remote'),
        actions: [
          IconButton(
            tooltip: 'Add by IP',
            onPressed: _addManually,
            icon: const Icon(Icons.add_link),
          ),
          IconButton(
            tooltip: 'Scan',
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _scan,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_scanning && _devices.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Scanning for Roku devices…'),
          ],
        ),
      );
    }
    if (_error != null && _devices.isEmpty) {
      return _message(_error!);
    }
    if (_devices.isEmpty) {
      return _message('No Roku devices found.\nPull to rescan or add by IP.');
    }
    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, i) {
        final d = _devices[i];
        return ListTile(
          leading: const Icon(Icons.tv),
          title: Text(d.name),
          subtitle: Text('${d.model} · ${d.ip}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(d),
        );
      },
    );
  }

  Widget _message(String text) {
    return ListView(
      children: [
        const SizedBox(height: 96),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: FilledButton.icon(
            onPressed: _addManually,
            icon: const Icon(Icons.add_link),
            label: const Text('Add device by IP'),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: OutlinedButton.icon(
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.refresh),
            label: const Text('Scan again'),
          ),
        ),
      ],
    );
  }
}

/// Prompts for an IP address and resolves it to a device, showing progress
/// while the device info request is in flight.
class _AddDeviceDialog extends StatefulWidget {
  const _AddDeviceDialog();

  @override
  State<_AddDeviceDialog> createState() => _AddDeviceDialogState();
}

class _AddDeviceDialogState extends State<_AddDeviceDialog> {
  final _controller = TextEditingController();
  bool _connecting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ip = _controller.text.trim();
    if (ip.isEmpty || _connecting) return;
    setState(() => _connecting = true);
    final device = await RokuDiscovery.fetchDeviceInfo(ip);
    if (!mounted) return;
    Navigator.of(context).pop(device);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_connecting,
      child: AlertDialog(
        title: const Text('Add device by IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '192.168.1.42'),
              autofocus: true,
              enabled: !_connecting,
              onSubmitted: (_) => _submit(),
            ),
            if (_connecting) ...[
              const SizedBox(height: 20),
              const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Connecting…'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _connecting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _connecting ? null : _submit,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
