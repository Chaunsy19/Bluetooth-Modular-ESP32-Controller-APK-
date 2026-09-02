import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import 'module_details_screen.dart';

class LayoutEditorScreen extends StatefulWidget {
  final AppController controller;
  const LayoutEditorScreen({super.key, required this.controller});
  @override
  State<LayoutEditorScreen> createState() => _LayoutEditorScreenState();
}

class _LayoutEditorScreenState extends State<LayoutEditorScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit layout'), actions: [
        TextButton(
            onPressed: c.connected
                ? () async {
                    await c.resetLayout();
                  }
                : null,
            child: const Text('Reset'))
      ]),
      body: ReorderableListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: c.modules.length,
          onReorderItem: c.reorderModules,
          itemBuilder: (context, index) {
            final m = c.modules[index];
            return Card(
                key: ValueKey(m.id),
                child: ListTile(
                  leading: ReorderableDragStartListener(
                      index: index, child: const Icon(Icons.drag_handle)),
                  title: Text(m.name),
                  subtitle: Text('${m.type} • ${m.id}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(
                        value: m.enabled,
                        onChanged: c.connected
                            ? (value) => c.setModuleEnabled(m.id, value)
                            : null),
                    IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ModuleDetailsScreen(
                                    controller: c, module: m))))
                  ]),
                ));
          }),
    );
  }
}
