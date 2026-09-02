import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  final AppController controller;
  const SettingsScreen({super.key, required this.controller});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  late String _themeMode;

  @override
  void initState() {
    super.initState();
    final s = widget.controller.settings;
    _fields = {
      'name': TextEditingController(text: s.deviceName),
      'service': TextEditingController(text: s.serviceUuid),
      'command': TextEditingController(text: s.commandUuid),
      'status': TextEditingController(text: s.statusUuid),
      'pairing': TextEditingController(text: s.pairingCode),
    };
    _themeMode = s.themeMode;
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
  String? _uuid(String? value) {
    if (_required(value) != null) return 'Required';
    return RegExp(
                r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(value!.trim())
        ? null
        : 'Enter a full 128-bit UUID';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              Text('BLE', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              TextFormField(
                  controller: _fields['name'],
                  decoration:
                      const InputDecoration(labelText: 'ESP32 device name'),
                  validator: _required),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _fields['service'],
                  decoration: const InputDecoration(labelText: 'Service UUID'),
                  validator: _uuid),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _fields['command'],
                  decoration: const InputDecoration(labelText: 'Command UUID'),
                  validator: _uuid),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _fields['status'],
                  decoration: const InputDecoration(labelText: 'Status UUID'),
                  validator: _uuid),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _fields['pairing'],
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                      labelText: 'BLE pairing code',
                      helperText:
                          'Must match the code configured in the ESP32 firmware.'),
                  validator: (value) => RegExp(r'^\d{6}$').hasMatch(value ?? '')
                      ? null
                      : 'Enter exactly 6 digits'),
              const SizedBox(height: 24),
              Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                  initialValue: _themeMode,
                  decoration: const InputDecoration(labelText: 'Theme'),
                  items: const [
                    DropdownMenuItem(
                        value: 'system', child: Text('Use phone setting')),
                    DropdownMenuItem(value: 'light', child: Text('Light')),
                    DropdownMenuItem(value: 'dark', child: Text('Dark')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _themeMode = value);
                  }),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _save, child: const Text('Save settings')),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
            ])),
      );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await widget.controller.saveSettings(AppSettings(
      deviceName: _fields['name']!.text.trim(),
      serviceUuid: _fields['service']!.text.trim(),
      commandUuid: _fields['command']!.text.trim(),
      statusUuid: _fields['status']!.text.trim(),
      pairingCode: _fields['pairing']!.text.trim(),
      themeMode: _themeMode,
    ));
    if (mounted) Navigator.pop(context);
  }
}
