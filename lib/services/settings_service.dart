import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/app_settings.dart';
import '../models/module_model.dart';

class SettingsService {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<AppSettings> load() async {
    const defaults = AppSettings();
    return AppSettings(
      deviceName: await _prefs.getString('device_name') ?? defaults.deviceName,
      serviceUuid:
          await _prefs.getString('service_uuid') ?? defaults.serviceUuid,
      commandUuid:
          await _prefs.getString('command_uuid') ?? defaults.commandUuid,
      statusUuid: await _prefs.getString('status_uuid') ?? defaults.statusUuid,
    );
  }

  Future<void> save(AppSettings value) async {
    await _prefs.setString('device_name', value.deviceName);
    await _prefs.setString('service_uuid', value.serviceUuid);
    await _prefs.setString('command_uuid', value.commandUuid);
    await _prefs.setString('status_uuid', value.statusUuid);
  }

  Future<String?> getLastDeviceId() => _prefs.getString('last_device_id');
  Future<void> setLastDeviceId(String id) =>
      _prefs.setString('last_device_id', id);
  Future<void> clearLastDeviceId() => _prefs.remove('last_device_id');

  Future<void> cacheManifest(String deviceId, ModuleManifest manifest) =>
      _prefs.setString('manifest_$deviceId', jsonEncode(manifest.toJson()));

  Future<ModuleManifest?> loadCachedManifest(String deviceId) async {
    final text = await _prefs.getString('manifest_$deviceId');
    if (text == null) return null;
    try {
      return ModuleManifest.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } catch (_) {
      await _prefs.remove('manifest_$deviceId');
      return null;
    }
  }
}
