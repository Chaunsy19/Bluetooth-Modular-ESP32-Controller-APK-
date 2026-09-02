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
  late String profile = widget.module.type == 'value'
      ? (widget.module.analogInput ? 'analog_input' : 'digital_input')
      : widget.module.type;
  late final name = TextEditingController(text: widget.module.name);
  late final pin =
      TextEditingController(text: widget.module.pin?.toString() ?? '');
  late final pin2 =
      TextEditingController(text: widget.module.pin2?.toString() ?? '');
  late final pin3 =
      TextEditingController(text: widget.module.pin3?.toString() ?? '');
  late final minimum =
      TextEditingController(text: _number(widget.module.min, '0'));
  late final maximum =
      TextEditingController(text: _number(widget.module.max, '100'));
  late final step =
      TextEditingController(text: _number(widget.module.step, '1'));
  late final unit = TextEditingController(text: widget.module.unit);

  bool get editableHardware =>
      !const {'button', 'text'}.contains(widget.module.type);
  bool get usesRange => const {'slider', 'servo', 'motor'}.contains(profile);
  String _number(double? value, String fallback) => value == null
      ? fallback
      : value.toString().replaceFirst(RegExp(r'\.0$'), '');

  @override
  void dispose() {
    for (final c in [name, pin, pin2, pin3, minimum, maximum, step, unit]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Module details')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          TextFormField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Display name')),
          if (editableHardware) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: profile,
              decoration: const InputDecoration(labelText: 'Accessory type'),
              items: const [
                DropdownMenuItem(
                    value: 'toggle', child: Text('On/off light or relay')),
                DropdownMenuItem(
                    value: 'slider', child: Text('Dimmable PWM light')),
                DropdownMenuItem(value: 'servo', child: Text('Servo')),
                DropdownMenuItem(
                    value: 'motor', child: Text('Reversible motor / winch')),
                DropdownMenuItem(
                    value: 'digital_input', child: Text('Digital input')),
                DropdownMenuItem(
                    value: 'analog_input', child: Text('Analog input')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  profile = value;
                  if (value == 'servo') {
                    minimum.text = '0';
                    maximum.text = '180';
                    step.text = '1';
                    unit.text = 'degrees';
                  } else if (value == 'motor') {
                    minimum.text = '-100';
                    maximum.text = '100';
                    step.text = '1';
                    unit.text = '%';
                  } else if (value == 'slider') {
                    minimum.text = '0';
                    maximum.text = '100';
                    step.text = '1';
                    unit.text = '%';
                  } else if (value == 'analog_input') {
                    minimum.text = '0';
                    maximum.text = '4095';
                    unit.text = 'ADC';
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pin,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText:
                      profile == 'motor' ? 'PWM / enable pin' : 'ESP32 pin'),
            ),
            if (profile == 'motor') ...[
              const SizedBox(height: 12),
              TextField(
                  controller: pin2,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Direction A pin')),
              const SizedBox(height: 12),
              TextField(
                  controller: pin3,
                  keyboardType: TextInputType.number,
                  decoration:
                      const InputDecoration(labelText: 'Direction B pin')),
              const SizedBox(height: 8),
              const Text(
                  'Use a properly rated H-bridge. Never power a motor from an ESP32 pin.'),
            ],
            if (usesRange) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: minimum,
                        keyboardType: const TextInputType.numberWithOptions(
                            signed: true, decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Minimum'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: maximum,
                        keyboardType: const TextInputType.numberWithOptions(
                            signed: true, decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'Maximum'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: step,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(labelText: 'Step'))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: unit,
                        decoration: const InputDecoration(labelText: 'Unit'))),
              ]),
            ],
          ],
          const SizedBox(height: 16),
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Unique ID'),
              trailing: Text(widget.module.id)),
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
            child: const Text('Hide module'),
          ),
          if (widget.module.deletable)
            TextButton.icon(
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: widget.controller.connected ? _delete : null,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete module permanently'),
            ),
        ]),
      );

  Future<void> _save() async {
    final newName = name.text.trim();
    if (newName.isEmpty) return _error('Name cannot be empty.');
    if (editableHardware) {
      final primaryPin = int.tryParse(pin.text);
      if (primaryPin == null) {
        return _error('Primary pin must be a whole number.');
      }
      final definition = <String, dynamic>{
        'type': const {'analog_input', 'digital_input'}.contains(profile)
            ? 'value'
            : profile,
        'pin': primaryPin,
        'analog_input': profile == 'analog_input',
      };
      if (profile == 'motor') {
        final directionA = int.tryParse(pin2.text);
        final directionB = int.tryParse(pin3.text);
        if (directionA == null || directionB == null) {
          return _error('Both direction pins are required.');
        }
        definition.addAll({'pin2': directionA, 'pin3': directionB});
      }
      if (usesRange) {
        final min = double.tryParse(minimum.text);
        final max = double.tryParse(maximum.text);
        final increment = double.tryParse(step.text);
        if (min == null ||
            max == null ||
            increment == null ||
            max <= min ||
            increment <= 0) {
          return _error('Enter a valid minimum, maximum, and step.');
        }
        definition.addAll({
          'min': min,
          'max': max,
          'step': increment,
          'unit': unit.text.trim(),
          'value': profile == 'servo' ? 90 : 0
        });
      } else if (profile == 'analog_input') {
        definition.addAll({
          'min': 0,
          'max': 4095,
          'step': 1,
          'unit': 'ADC',
          'value': 0,
          'decimals': 0
        });
      } else if (profile == 'digital_input') {
        definition.addAll({
          'min': 0,
          'max': 1,
          'step': 1,
          'unit': '',
          'value': 0,
          'decimals': 0
        });
      } else {
        definition
            .addAll({'min': 0, 'max': 1, 'step': 1, 'unit': '', 'value': 0});
      }
      await widget.controller.updateModule(widget.module.id, definition);
    }
    if (newName != widget.module.name) {
      await widget.controller.renameModule(widget.module.id, newName);
    }
    if (mounted) Navigator.pop(context);
  }

  void _error(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete module?'),
            content: Text(
                'Delete “${widget.module.name}”? This removes its saved configuration from the ESP32.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.controller.deleteModule(widget.module.id);
    if (mounted) Navigator.pop(context);
  }
}
