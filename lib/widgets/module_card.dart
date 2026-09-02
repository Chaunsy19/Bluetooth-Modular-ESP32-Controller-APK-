import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../models/module_model.dart';

typedef ModuleCardBuilder = Widget Function(
    BuildContext, ModuleModel, AppController);

class ModuleWidgetRegistry {
  static final Map<String, ModuleCardBuilder> _builders = {
    'toggle': _toggle,
    'slider': _slider,
    'servo': _slider,
    'motor': _motor,
    'value': _value,
    'button': _button,
    'text': _text,
  };

  static Widget build(
      BuildContext context, ModuleModel module, AppController controller) {
    final content =
        (_builders[module.type] ?? _unsupported)(context, module, controller);
    return Card(
      key: ValueKey(module.id),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(_icon(module.type)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(module.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(module.id, style: Theme.of(context).textTheme.bodySmall),
                ])),
          ]),
          const SizedBox(height: 14),
          content,
        ]),
      ),
    );
  }

  static Widget _toggle(BuildContext context, ModuleModel m, AppController c) =>
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
              value: true, label: Text('ON'), icon: Icon(Icons.power)),
          ButtonSegment(
              value: false, label: Text('OFF'), icon: Icon(Icons.power_off))
        ],
        selected: {m.value == true},
        onSelectionChanged: c.connected
            ? (values) => c.setModuleValue(m.id, values.first)
            : null,
      );

  static Widget _slider(BuildContext context, ModuleModel m, AppController c) {
    final minimum = m.min!;
    final maximum = m.max!;
    final step = m.step!;
    final raw = (m.value as num).toDouble().clamp(minimum, maximum);
    final divisions = ((maximum - minimum) / step).round().clamp(1, 1000);
    return Column(children: [
      Text(
          '${_number(raw, step < 1 ? 2 : 0)}${m.unit.isEmpty ? '' : ' ${m.unit}'}',
          style: Theme.of(context).textTheme.headlineSmall),
      Slider(
          value: raw,
          min: minimum,
          max: maximum,
          divisions: divisions,
          label: _number(raw, step < 1 ? 2 : 0),
          onChanged: c.connected
              ? (value) {
                  final snapped =
                      minimum + ((value - minimum) / step).round() * step;
                  c.setModuleValue(m.id, step >= 1 ? snapped.round() : snapped,
                      debounce: true);
                }
              : null),
    ]);
  }

  static Widget _value(BuildContext context, ModuleModel m, AppController c) {
    final value = !m.analogInput && m.value is num
        ? ((m.value as num) == 0 ? 'LOW' : 'HIGH')
        : m.value is num
            ? (m.value as num).toStringAsFixed(m.decimals)
            : m.value?.toString() ?? '—';
    return Text('$value${m.unit.isEmpty ? '' : ' ${m.unit}'}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium);
  }

  static Widget _motor(BuildContext context, ModuleModel m, AppController c) {
    final raw = (m.value as num).toDouble().clamp(-100.0, 100.0);
    return Column(children: [
      Text(
          raw == 0
              ? 'STOP'
              : '${raw.abs().round()}% ${raw > 0 ? 'FORWARD' : 'REVERSE'}',
          style: Theme.of(context).textTheme.headlineSmall),
      Slider(
        value: raw,
        min: -100,
        max: 100,
        divisions: 200,
        label: raw.round().toString(),
        onChanged: c.connected
            ? (value) => c.setModuleValue(m.id, value.round(), debounce: true)
            : null,
        onChangeEnd: c.connected ? (_) => c.setModuleValue(m.id, 0) : null,
      ),
      const Text('Hold to run • release to stop'),
    ]);
  }

  static Widget _button(BuildContext context, ModuleModel m, AppController c) =>
      FilledButton.icon(
          onPressed: c.connected ? () => c.triggerAction(m) : null,
          icon: const Icon(Icons.touch_app),
          label: Text(m.label ?? m.name));
  static Widget _text(BuildContext context, ModuleModel m, AppController c) =>
      SelectableText(m.value?.toString() ?? '',
          style: Theme.of(context).textTheme.bodyLarge);
  static Widget _unsupported(
          BuildContext context, ModuleModel m, AppController c) =>
      ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.extension_off),
          title: const Text('Unsupported module'),
          subtitle: Text('Type “${m.type}” requires a newer app.'));
  static String _number(double value, int decimals) =>
      value.toStringAsFixed(decimals);
  static IconData _icon(String type) => switch (type) {
        'toggle' => Icons.toggle_on,
        'slider' => Icons.tune,
        'servo' => Icons.rotate_right,
        'motor' => Icons.settings_input_component,
        'value' => Icons.monitor_heart_outlined,
        'button' => Icons.smart_button,
        'text' => Icons.info_outline,
        _ => Icons.extension_off
      };
}
