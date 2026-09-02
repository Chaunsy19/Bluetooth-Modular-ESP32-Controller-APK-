import 'package:flutter_test/flutter_test.dart';
import 'package:esp32_control/models/app_settings.dart';

void main() {
  test('default BLE identifiers are complete UUIDs', () {
    const settings = AppSettings();
    expect(settings.serviceUuid.length, 36);
    expect(settings.commandUuid.length, 36);
    expect(settings.statusUuid.length, 36);
    expect(settings.pairingCode, matches(RegExp(r'^\d{6}$')));
    expect(settings.themeMode, 'system');
  });
}
