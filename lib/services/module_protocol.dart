import '../models/module_model.dart';

class ManifestAssembler {
  int? _expected;
  int _revision = 0;
  String _deviceName = '';
  final List<Map<String, dynamic>> _modules = [];

  bool get receiving => _expected != null;

  void start(Map<String, dynamic> message) {
    if (message['protocol_version'] != 1 ||
        message['count'] is! num ||
        message['device_name'] is! String) {
      throw const ProtocolException('Invalid manifest_start message.');
    }
    _expected = (message['count'] as num).toInt();
    _revision = (message['revision'] as num?)?.toInt() ?? 0;
    _deviceName = message['device_name'] as String;
    _modules.clear();
  }

  void add(Map<String, dynamic> message) {
    if (!receiving || message['module'] is! Map) {
      throw const ProtocolException('Unexpected module_definition.');
    }
    _modules.add(Map<String, dynamic>.from(message['module'] as Map));
  }

  ModuleManifest finish(Map<String, dynamic> message) {
    if (!receiving ||
        message['revision'] != _revision ||
        _modules.length != _expected) {
      throw const ProtocolException('Incomplete module manifest.');
    }
    final manifest = ModuleManifest.fromJson({
      'protocol_version': 1,
      'device_name': _deviceName,
      'revision': _revision,
      'modules': List.of(_modules)
    });
    _expected = null;
    _modules.clear();
    return manifest;
  }

  void reset() {
    _expected = null;
    _modules.clear();
  }
}
