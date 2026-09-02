import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';

class AddModuleScreen extends StatefulWidget {
  final AppController controller;
  const AddModuleScreen({super.key, required this.controller});
  @override
  State<AddModuleScreen> createState() => _AddModuleScreenState();
}

class _AddModuleScreenState extends State<AddModuleScreen> {
  final formKey = GlobalKey<FormState>();
  String type = 'toggle';
  final name = TextEditingController(text: 'New Light');
  final pin = TextEditingController();
  final pin2 = TextEditingController();
  final pin3 = TextEditingController();
  final minimum = TextEditingController(text: '0');
  final maximum = TextEditingController(text: '100');
  final step = TextEditingController(text: '1');
  final unit = TextEditingController(text: '%');
  final defaultValue = TextEditingController(text: '0');
  final label = TextEditingController(text: 'Run Action');
  bool get usesPin => const {
        'toggle',
        'slider',
        'servo',
        'motor',
        'value',
        'digital_input'
      }.contains(type);
  bool get usesRange =>
      const {'slider', 'servo', 'motor', 'value'}.contains(type);

  @override
  void dispose() {
    for (final c in [
      name,
      pin,
      pin2,
      pin3,
      minimum,
      maximum,
      step,
      unit,
      defaultValue,
      label
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Add module')),
        body: Form(
            key: formKey,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Module type'),
                items: const [
                  DropdownMenuItem(
                      value: 'toggle', child: Text('Toggle / light / relay')),
                  DropdownMenuItem(value: 'slider', child: Text('PWM slider')),
                  DropdownMenuItem(value: 'servo', child: Text('Servo')),
                  DropdownMenuItem(
                      value: 'motor', child: Text('Reversible motor / winch')),
                  DropdownMenuItem(value: 'value', child: Text('Analog input')),
                  DropdownMenuItem(
                      value: 'digital_input', child: Text('Digital input')),
                  DropdownMenuItem(
                      value: 'button', child: Text('Action button')),
                  DropdownMenuItem(value: 'text', child: Text('Text status')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    type = value;
                    if (value == 'servo') {
                      maximum.text = '180';
                      unit.text = 'degrees';
                      defaultValue.text = '90';
                    } else if (value == 'slider') {
                      maximum.text = '100';
                      unit.text = '%';
                      defaultValue.text = '0';
                    } else if (value == 'value') {
                      maximum.text = '4095';
                      unit.text = 'ADC';
                      defaultValue.text = '0';
                    } else if (value == 'motor') {
                      minimum.text = '-100';
                      maximum.text = '100';
                      unit.text = '%';
                      defaultValue.text = '0';
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: _nameValidator),
              if (usesPin) ...[
                const SizedBox(height: 12),
                TextFormField(
                    controller: pin,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ESP32 pin'),
                    validator: _integerValidator)
              ],
              if (type == 'motor') ...[
                const SizedBox(height: 12),
                TextFormField(
                    controller: pin2,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Direction A pin'),
                    validator: _integerValidator),
                const SizedBox(height: 12),
                TextFormField(
                    controller: pin3,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Direction B pin'),
                    validator: _integerValidator),
                const SizedBox(height: 8),
                const Text(
                    'Connect these three signals to a suitable H-bridge. Never connect a motor directly to the ESP32.'),
              ],
              if (usesRange) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: minimum,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Minimum'),
                          validator: _numberValidator)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextFormField(
                          controller: maximum,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Maximum'),
                          validator: _numberValidator))
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: step,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Step'),
                          validator: _positiveValidator)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: TextFormField(
                          controller: defaultValue,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Default'),
                          validator: _numberValidator))
                ]),
                const SizedBox(height: 12),
                TextFormField(
                    controller: unit,
                    decoration:
                        const InputDecoration(labelText: 'Unit (optional)')),
              ],
              if (type == 'button') ...[
                const SizedBox(height: 12),
                TextFormField(
                    controller: label,
                    decoration:
                        const InputDecoration(labelText: 'Button label'),
                    validator: _nameValidator)
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                  onPressed: widget.controller.connected ? _save : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add module')),
            ])),
      );

  String? _nameValidator(String? v) => v == null || v.trim().isEmpty
      ? 'Required'
      : v.trim().length > 31
          ? 'Maximum 31 characters'
          : null;
  String? _integerValidator(String? v) =>
      int.tryParse(v ?? '') == null ? 'Enter a whole number' : null;
  String? _numberValidator(String? v) =>
      double.tryParse(v ?? '') == null ? 'Enter a number' : null;
  String? _positiveValidator(String? v) {
    final n = double.tryParse(v ?? '');
    return n == null || n <= 0 ? 'Must be greater than zero' : null;
  }

  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    final definition = <String, dynamic>{
      'type': type == 'digital_input' ? 'value' : type,
      'name': name.text.trim()
    };
    if (usesPin) definition['pin'] = int.parse(pin.text);
    if (type == 'motor') {
      definition['pin2'] = int.parse(pin2.text);
      definition['pin3'] = int.parse(pin3.text);
    }
    if (usesRange) {
      final min = double.parse(minimum.text), max = double.parse(maximum.text);
      if (min >= max) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Maximum must be greater than minimum.')));
        return;
      }
      definition.addAll({
        'min': min,
        'max': max,
        'step': double.parse(step.text),
        'unit': unit.text.trim(),
        'value': double.parse(defaultValue.text)
      });
      if (type == 'value') {
        definition['decimals'] = 0;
        definition['analog_input'] = true;
      }
    } else if (type == 'digital_input') {
      definition.addAll({
        'min': 0,
        'max': 1,
        'value': 0,
        'unit': '',
        'decimals': 0,
        'analog_input': false
      });
    } else if (type == 'toggle') {
      definition['value'] = false;
    } else if (type == 'button') {
      definition['label'] = label.text.trim();
    } else if (type == 'text') {
      definition['value'] = '';
    }
    await widget.controller.addModule(definition);
    if (mounted) Navigator.pop(context);
  }
}
