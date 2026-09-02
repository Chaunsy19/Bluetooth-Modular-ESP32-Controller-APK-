import 'package:flutter/material.dart';

class ControlCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const ControlCard(
      {super.key,
      required this.title,
      required this.icon,
      required this.child});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(icon),
              const SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleMedium)
            ]),
            const SizedBox(height: 12),
            child,
          ]),
        ),
      );
}

class OnOffButtons extends StatelessWidget {
  final bool enabled;
  final bool value;
  final ValueChanged<bool> onChanged;
  const OnOffButtons({
    super.key,
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
                value: true, icon: Icon(Icons.power), label: Text('ON')),
            ButtonSegment(
                value: false, icon: Icon(Icons.power_off), label: Text('OFF')),
          ],
          selected: {value},
          onSelectionChanged:
              enabled ? (selection) => onChanged(selection.first) : null,
        ),
      );
}
