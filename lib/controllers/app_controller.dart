import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/app_settings.dart';
import '../models/module_model.dart';
import '../services/ble_service.dart';
import '../services/module_protocol.dart';
import '../services/settings_service.dart';

enum SyncState { idle, loadingCache, synchronizing, synchronized, error }

class AppController extends ChangeNotifier {
  final BleService ble;
  final SettingsService storage;
  final ManifestAssembler _assembler = ManifestAssembler();
  final Map<String, Timer> _sliderTimers = {};
  Timer? _manifestRefreshTimer;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  AppSettings settings = const AppSettings();
  BleLinkState linkState = BleLinkState.disconnected;
  SyncState syncState = SyncState.idle;
  List<ScanResult> scanResults = const [];
  List<ModuleModel> modules = const [];
  int manifestRevision = 0;
  String lastCommand = 'None';
  String lastResponse = 'None';
  String? error;

  AppController(this.ble, this.storage);
  bool get connected => linkState == BleLinkState.connected;
  bool get synchronized => syncState == SyncState.synchronized;
  List<ModuleModel> get visibleModules =>
      modules.where((m) => m.enabled).toList();

  Future<void> initialize() async {
    settings = await storage.load();
    await ble.configure(settings);
    _subscriptions.add(ble.state.listen(_handleLinkState));
    _subscriptions.add(ble.devices.listen((value) {
      scanResults = value;
      notifyListeners();
    }));
    _subscriptions.add(ble.errors.listen((value) {
      error = value;
      notifyListeners();
    }));
    _subscriptions.add(ble.messages.listen(_handleMessage));
    final id = await storage.getLastDeviceId();
    if (id != null && id.isNotEmpty) {
      syncState = SyncState.loadingCache;
      final cached = await storage.loadCachedManifest(id);
      if (cached != null) _applyManifest(cached, cache: false);
      await ble.reconnect(id);
    }
    notifyListeners();
  }

  void _handleLinkState(BleLinkState value) {
    linkState = value;
    if (value == BleLinkState.connected) {
      syncState = SyncState.synchronizing;
      requestManifest();
    } else if (value == BleLinkState.disconnected) {
      syncState = SyncState.idle;
      _assembler.reset();
      for (final timer in _sliderTimers.values) {
        timer.cancel();
      }
      _sliderTimers.clear();
    }
    notifyListeners();
  }

  Future<void> scan() async {
    error = null;
    notifyListeners();
    await ble.scan();
  }

  Future<void> connect(BluetoothDevice device) async {
    error = null;
    notifyListeners();
    await ble.connect(device);
    if (ble.device?.isConnected == true) {
      await storage.setLastDeviceId(device.remoteId.str);
    }
  }

  Future<void> disconnect({bool forget = false}) async {
    await ble.disconnect();
    if (forget) {
      await ble.removeBond();
      await storage.clearLastDeviceId();
      modules = const [];
      manifestRevision = 0;
    }
    notifyListeners();
  }

  Future<void> requestManifest() => _send({'command': 'get_modules'});
  Future<void> setModuleValue(String moduleId, dynamic value,
      {bool debounce = false}) async {
    _updateModuleValue(moduleId, value);
    notifyListeners();
    if (!debounce) {
      _sliderTimers.remove(moduleId)?.cancel();
      return _send(
          {'command': 'set_value', 'module_id': moduleId, 'value': value});
    }
    _sliderTimers[moduleId]?.cancel();
    _sliderTimers[moduleId] = Timer(const Duration(milliseconds: 180), () {
      _send({'command': 'set_value', 'module_id': moduleId, 'value': value});
      _sliderTimers.remove(moduleId);
    });
  }

  Future<void> triggerAction(ModuleModel module) => _send({
        'command': 'trigger_action',
        'module_id': module.id,
        if (module.commandValue != null) 'value': module.commandValue
      });
  Future<void> renameModule(String id, String name) async {
    final index = modules.indexWhere((module) => module.id == id);
    if (index >= 0) {
      modules = [...modules]..[index] =
          modules[index].withChanges(name: name.trim());
      notifyListeners();
    }
    await _sendConfiguration(
        {'command': 'rename_module', 'module_id': id, 'name': name.trim()});
  }

  Future<void> setModuleEnabled(String id, bool enabled) async {
    final index = modules.indexWhere((module) => module.id == id);
    if (index >= 0) {
      modules = [...modules]..[index] =
          modules[index].withChanges(enabled: enabled);
      notifyListeners();
    }
    await _sendConfiguration(
        {'command': 'set_module_enabled', 'module_id': id, 'enabled': enabled});
  }

  Future<void> addModule(Map<String, dynamic> definition) =>
      _sendConfiguration({'command': 'add_module', 'module': definition});
  Future<void> deleteModule(String id) async {
    modules = modules.where((module) => module.id != id).toList();
    notifyListeners();
    await _sendConfiguration({'command': 'delete_module', 'module_id': id});
  }

  Future<void> setModulePin(String id, int pin) async {
    final index = modules.indexWhere((module) => module.id == id);
    if (index >= 0) {
      modules = [...modules]..[index] = modules[index].withChanges(pin: pin);
      notifyListeners();
    }
    await _sendConfiguration(
        {'command': 'set_module_pin', 'module_id': id, 'pin': pin});
  }

  Future<void> updateModule(String id, Map<String, dynamic> definition) =>
      _sendConfiguration(
          {'command': 'update_module', 'module_id': id, 'module': definition});

  Future<void> setModuleOrder(List<String> order) =>
      _sendConfiguration({'command': 'set_module_order', 'order': order});
  Future<void> reorderModules(int oldIndex, int newIndex) async {
    final reordered = [...modules];
    final item = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, item);
    modules = reordered;
    notifyListeners();
    await setModuleOrder(reordered.map((module) => module.id).toList());
  }

  Future<void> resetLayout() => _sendConfiguration({'command': 'reset_layout'});

  Future<void> _sendConfiguration(Map<String, dynamic> command) async {
    await _send(command);
    _manifestRefreshTimer?.cancel();
    _manifestRefreshTimer = Timer(const Duration(milliseconds: 350), () {
      if (connected) requestManifest();
    });
  }

  Future<void> sendCustom(String text) async {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('JSON must be an object.');
      }
      await _send(decoded);
    } catch (e) {
      error =
          'Invalid command: ${e.toString().replaceFirst('FormatException: ', '')}';
      notifyListeners();
    }
  }

  Future<void> _send(Map<String, dynamic> command) async {
    try {
      lastCommand = await ble.send(command);
      error = null;
    } catch (e) {
      error = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Bad state: ', '');
    }
    notifyListeners();
  }

  void _handleMessage(String text) {
    lastResponse = text;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw const ProtocolException('Message is not a JSON object.');
      }
      final data = Map<String, dynamic>.from(decoded);
      switch (data['event']) {
        case 'manifest_start':
          syncState = SyncState.synchronizing;
          _assembler.start(data);
          break;
        case 'module_definition':
          _assembler.add(data);
          break;
        case 'manifest_end':
          _applyManifest(_assembler.finish(data));
          break;
        case 'value_changed':
          if (data['module_id'] is String && data.containsKey('value')) {
            _updateModuleValue(data['module_id'] as String, data['value']);
          }
          break;
        case 'config_changed':
          if (connected && data['revision'] != manifestRevision) {
            requestManifest();
          }
          break;
      }
      if (data['success'] == false) {
        error = data['error']?.toString() ?? 'ESP32 rejected the command.';
      }
      if (data['success'] == true &&
          data['module_id'] is String &&
          data.containsKey('value')) {
        _updateModuleValue(data['module_id'] as String, data['value']);
      }
    } catch (e) {
      syncState = SyncState.error;
      error = 'Protocol error: $e';
      _assembler.reset();
    }
    notifyListeners();
  }

  void _applyManifest(ModuleManifest manifest, {bool cache = true}) {
    modules = manifest.modules;
    manifestRevision = manifest.revision;
    syncState = SyncState.synchronized;
    if (cache) {
      final id = ble.device?.remoteId.str;
      if (id != null) storage.cacheManifest(id, manifest);
    }
  }

  void _updateModuleValue(String id, dynamic value) {
    final index = modules.indexWhere((module) => module.id == id);
    if (index < 0) return;
    try {
      final updated = modules[index].withChanges(value: value);
      modules = [...modules]..[index] = updated;
    } catch (_) {
      error = 'ESP32 sent an invalid value for $id.';
    }
  }

  Future<void> saveSettings(AppSettings value) async {
    settings = value;
    await storage.save(value);
    await ble.configure(value);
    notifyListeners();
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    for (final timer in _sliderTimers.values) {
      timer.cancel();
    }
    _manifestRefreshTimer?.cancel();
    ble.dispose();
    super.dispose();
  }
}
