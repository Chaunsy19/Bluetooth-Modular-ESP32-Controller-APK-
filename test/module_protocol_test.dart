import 'package:esp32_control/models/module_model.dart';
import 'package:esp32_control/services/module_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses supported and unsupported module types safely', () {
    final toggle = ModuleModel.fromJson({
      'id': 'relay_1',
      'type': 'toggle',
      'name': 'Pump',
      'pin': 26,
      'value': false,
      'enabled': true,
      'order': 0,
    });
    final future = ModuleModel.fromJson({
      'id': 'future_1',
      'type': 'future_type',
      'name': 'Future',
      'value': 1,
      'enabled': true,
      'order': 1,
    });
    expect(toggle, isA<ToggleModule>());
    expect(future, isA<UnsupportedModule>());
  });

  test('assembles a chunked manifest atomically', () {
    final assembler = ManifestAssembler();
    assembler.start({
      'event': 'manifest_start',
      'protocol_version': 1,
      'device_name': 'ESP32-Control',
      'revision': 4,
      'count': 1
    });
    assembler.add({
      'event': 'module_definition',
      'module': {
        'id': 'servo_1',
        'type': 'servo',
        'name': 'Rudder',
        'pin': 18,
        'enabled': true,
        'order': 0,
        'value': 90,
        'min': 0,
        'max': 180,
        'step': 1,
        'unit': 'degrees',
      }
    });
    final manifest = assembler.finish({'event': 'manifest_end', 'revision': 4});
    expect(manifest.revision, 4);
    expect(manifest.modules.single, isA<ServoModule>());
  });

  test('rejects duplicate IDs', () {
    final module = {
      'id': 'same',
      'type': 'toggle',
      'name': 'One',
      'value': false
    };
    expect(
        () => ModuleManifest.fromJson({
              'protocol_version': 1,
              'device_name': 'ESP32',
              'revision': 1,
              'modules': [
                module,
                {...module, 'name': 'Two'}
              ],
            }),
        throwsA(isA<ProtocolException>()));
  });

  test('parses reversible motor and input hardware metadata', () {
    final motor = ModuleModel.fromJson({
      'id': 'winch_1',
      'type': 'motor',
      'name': 'Winch',
      'pin': 25,
      'pin2': 26,
      'pin3': 27,
      'value': 0,
      'min': -100,
      'max': 100,
      'step': 1,
    });
    final input = ModuleModel.fromJson({
      'id': 'battery_1',
      'type': 'value',
      'name': 'Battery sensor',
      'pin': 34,
      'analog_input': true,
      'value': 2048,
    });
    expect(motor, isA<MotorModule>());
    expect(motor.pin2, 26);
    expect(motor.pin3, 27);
    expect(input.analogInput, isTrue);
  });
}
