import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../services/ble_service.dart';
import '../widgets/module_card.dart';
import 'layout_editor_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppController controller;
  const HomeScreen({super.key, required this.controller});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final custom = TextEditingController(text: '{"command":"get_modules"}');
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    custom.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('ESP32 Control'), actions: [
        IconButton(
            tooltip: 'Edit layout',
            onPressed: c.modules.isEmpty
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => LayoutEditorScreen(controller: c))),
            icon: const Icon(Icons.dashboard_customize)),
        IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SettingsScreen(controller: c))),
            icon: const Icon(Icons.settings)),
      ]),
      body: SafeArea(
          child: RefreshIndicator(
              onRefresh: c.connected ? c.requestManifest : () async {},
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _connectionCard(c),
                if (c.error != null)
                  Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: Text(c.error!),
                          trailing: IconButton(
                              onPressed: c.clearError,
                              icon: const Icon(Icons.close)))),
                _syncBanner(c),
                if (c.visibleModules.isEmpty)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              c.connected
                                  ? 'No enabled modules. Open Edit layout to enable one.'
                                  : 'Connect to load the ESP32 module layout.',
                              textAlign: TextAlign.center))),
                for (final module in c.visibleModules)
                  ModuleWidgetRegistry.build(context, module, c),
                ExpansionTile(
                    title: const Text('Advanced'),
                    childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    children: [
                      TextField(
                          controller: custom,
                          minLines: 2,
                          maxLines: 5,
                          decoration: const InputDecoration(
                              labelText: 'Custom JSON command')),
                      const SizedBox(height: 10),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: c.connected
                                  ? () => c.sendCustom(custom.text)
                                  : null,
                              child: const Text('Send JSON'))),
                      const SizedBox(height: 14),
                      SelectableText(
                          'Last sent:\n${c.lastCommand}\n\nLast received:\n${c.lastResponse}'),
                    ]),
              ]))),
    );
  }

  Widget _syncBanner(AppController c) {
    final (icon, label, color) = switch (c.syncState) {
      SyncState.synchronized => (
          Icons.cloud_done,
          'Layout synchronized • revision ${c.manifestRevision}',
          Colors.green
        ),
      SyncState.synchronizing => (
          Icons.sync,
          'Synchronizing modules…',
          Colors.orange
        ),
      SyncState.loadingCache => (
          Icons.offline_bolt,
          'Showing cached layout',
          Colors.orange
        ),
      SyncState.error => (
          Icons.sync_problem,
          'Module synchronization failed',
          Colors.red
        ),
      SyncState.idle => (Icons.cloud_off, 'Not synchronized', Colors.grey),
    };
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(label)
        ]));
  }

  Widget _connectionCard(AppController c) {
    final color = c.connected
        ? Colors.green
        : c.linkState == BleLinkState.connecting
            ? Colors.orange
            : Colors.grey;
    final label = switch (c.linkState) {
      BleLinkState.connected =>
        'Connected to ${c.ble.device?.platformName.isNotEmpty == true ? c.ble.device!.platformName : c.settings.deviceName}',
      BleLinkState.connecting => 'Connecting…',
      BleLinkState.scanning => 'Scanning…',
      BleLinkState.disconnected => 'Disconnected'
    };
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(Icons.circle, size: 14, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(label,
                            style: Theme.of(context).textTheme.titleMedium))
                  ]),
                  const SizedBox(height: 12),
                  if (!c.connected)
                    FilledButton.icon(
                        onPressed: c.linkState == BleLinkState.connecting ||
                                c.linkState == BleLinkState.scanning
                            ? null
                            : c.scan,
                        icon: const Icon(Icons.bluetooth_searching),
                        label: const Text('Scan for ESP32')),
                  if (c.scanResults.isNotEmpty && !c.connected) ...[
                    const SizedBox(height: 8),
                    for (final result in c.scanResults)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.memory),
                          title: Text(result.advertisementData.advName.isEmpty
                              ? c.settings.deviceName
                              : result.advertisementData.advName),
                          subtitle: Text(
                              '${result.device.remoteId.str} • ${result.rssi} dBm'),
                          trailing: FilledButton.tonal(
                              onPressed: c.linkState == BleLinkState.connecting
                                  ? null
                                  : () => c.connect(result.device),
                              child: const Text('Connect')))
                  ],
                  if (c.connected)
                    OutlinedButton.icon(
                        onPressed: () => c.disconnect(),
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect')),
                  if (!c.connected)
                    TextButton(
                        onPressed: () => c.disconnect(forget: true),
                        child: const Text('Forget saved ESP32')),
                ])));
  }
}
