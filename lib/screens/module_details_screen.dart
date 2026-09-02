import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../models/module_model.dart';

class ModuleDetailsScreen extends StatefulWidget {
  final AppController controller;
  final ModuleModel module;
  const ModuleDetailsScreen(
      {super.key, required this.controller, required this.module});
  @override
  State<ModuleDetailsScreen> createState() => _ModuleDetailsScreenState();
}

class _ModuleDetailsScreenState extends State<ModuleDetailsScreen> {
  late final TextEditingController name =
      TextEditingController(text: widget.module.name);
  late final TextEditingController pin =
      TextEditingController(text: widget.module.pin?.toString() ?? '');
  @override
  void dispose() {
    name.dispose();
    pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Module details')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: 12),
          TextField(
              controller: pin,
              enabled: widget.module.pin != null,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ESP32 pin')),
          const SizedBox(height: 16),
          _row('Unique ID', widget.module.id),
          _row('Type', widget.module.type),
          if (widget.module.min != null)
            _row('Minimum', '${widget.module.min}'),
          if (widget.module.max != null)
            _row('Maximum', '${widget.module.max}'),
          if (widget.module.step != null) _row('Step', '${widget.module.step}'),
          if (widget.module.unit.isNotEmpty) _row('Unit', widget.module.unit),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: widget.controller.connected ? _save : null,
              child: const Text('Save changes')),
          OutlinedButton(
              onPressed: widget.controller.connected
                  ? () async {
                      await widget.controller
                          .setModuleEnabled(widget.module.id, false);
                      if (context.mounted) Navigator.pop(context);
                    }
                  : null,
              child: const Text('Hide module')),
        ]),
      );
  Widget _row(String label, String value) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value));
  Future<void> _save() async {
    final newName = name.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Name cannot be empty.')));
      return;
    }
    if (newName != widget.module.name) {
      await widget.controller.renameModule(widget.module.id, newName);
    }
    if (widget.module.pin != null) {
      final newPin = int.tryParse(pin.text);
      if (newPin == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pin must be a whole number.')));
        }
        return;
      }
      if (newPin != widget.module.pin) {
        await widget.controller.setModulePin(widget.module.id, newPin);
      }
    }
    if (mounted) Navigator.pop(context);
  }
}
