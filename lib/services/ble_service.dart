import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/app_settings.dart';

enum BleLinkState { disconnected, scanning, connecting, connected }

class BleService {
  final _state = StreamController<BleLinkState>.broadcast();
  final _devices = StreamController<List<ScanResult>>.broadcast();
  final _messages = StreamController<String>.broadcast();
  final _errors = StreamController<String>.broadcast();
  final Map<String, ScanResult> _found = {};
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _notifySub;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _command;
  AppSettings _settings = const AppSettings();
  bool _manualDisconnect = false;

  Stream<BleLinkState> get state => _state.stream;
  Stream<List<ScanResult>> get devices => _devices.stream;
  Stream<String> get messages => _messages.stream;
  Stream<String> get errors => _errors.stream;
  BluetoothDevice? get device => _device;

  Future<void> configure(AppSettings settings) async {
    _settings = settings;
    FlutterBluePlus.setOperationQueueMode(OperationQueueMode.perDevice);
  }

  Future<void> scan() async {
    try {
      if (!await FlutterBluePlus.isSupported) {
        throw Exception('BLE is not supported on this phone.');
      }
      final adapter = await FlutterBluePlus.adapterState
          .where((s) => s != BluetoothAdapterState.unknown)
          .first;
      if (adapter != BluetoothAdapterState.on) {
        throw Exception('Turn Bluetooth on and allow Nearby Devices access.');
      }
      await FlutterBluePlus.stopScan();
      await _scanSub?.cancel();
      _found.clear();
      _devices.add(const []);
      _state.add(BleLinkState.scanning);
      _scanSub = FlutterBluePlus.onScanResults.listen((results) {
        for (final result in results) {
          final name = result.advertisementData.advName;
          if (name.contains(_settings.deviceName)) {
            _found[result.device.remoteId.str] = result;
          }
        }
        final sorted = _found.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
        _devices.add(sorted);
      }, onError: (Object e) => _errors.add(_friendlyError(e)));
      await FlutterBluePlus.startScan(
        withServices: [Guid(_settings.serviceUuid)],
        withNames: [_settings.deviceName],
        timeout: const Duration(seconds: 12),
        continuousUpdates: true,
        removeIfGone: const Duration(seconds: 5),
      );
      await FlutterBluePlus.isScanning.where((value) => !value).first;
      if (_device == null || !_device!.isConnected) {
        _state.add(BleLinkState.disconnected);
      }
    } catch (e) {
      _state.add(BleLinkState.disconnected);
      _errors.add(_friendlyError(e));
    }
  }

  Future<void> connect(BluetoothDevice device,
      {bool autoConnect = false}) async {
    try {
      _manualDisconnect = false;
      await FlutterBluePlus.stopScan();
      _state.add(BleLinkState.connecting);
      await _connectionSub?.cancel();
      _device = device;
      _connectionSub = device.connectionState.listen((value) async {
        if (value == BluetoothConnectionState.connected) {
          await _prepareCharacteristics();
        } else if (value == BluetoothConnectionState.disconnected) {
          _command = null;
          await _notifySub?.cancel();
          _state.add(BleLinkState.disconnected);
          if (!_manualDisconnect) {
            _errors.add('ESP32 disconnected. Automatic reconnect is waiting.');
          }
        }
      });
      if (!device.isConnected) {
        await device.connect(
          license: License.nonprofit,
          autoConnect: autoConnect,
          mtu: autoConnect ? null : 512,
        );
      } else {
        await _prepareCharacteristics();
      }
    } catch (e) {
      _state.add(BleLinkState.disconnected);
      _errors.add(_friendlyError(e));
    }
  }

  Future<void> reconnect(String remoteId) async {
    await connect(BluetoothDevice.fromId(remoteId), autoConnect: true);
  }

  Future<void> _prepareCharacteristics() async {
    try {
      _state.add(BleLinkState.connecting);
      if (Platform.isAndroid) {
        await _device!.createBond(
            pin: Uint8List.fromList(utf8.encode(_settings.pairingCode)));
      }
      final services = await _device!.discoverServices();
      final service = services
          .where((s) => s.uuid == Guid(_settings.serviceUuid))
          .firstOrNull;
      if (service == null) {
        throw Exception(
            'Configured BLE service was not found. Check UUID settings.');
      }
      _command = service.characteristics
          .where((c) => c.uuid == Guid(_settings.commandUuid))
          .firstOrNull;
      final status = service.characteristics
          .where((c) => c.uuid == Guid(_settings.statusUuid))
          .firstOrNull;
      if (_command == null || status == null) {
        throw Exception('Command or status characteristic was not found.');
      }
      await _notifySub?.cancel();
      await status.setNotifyValue(true);
      _notifySub = status.onValueReceived.listen((bytes) {
        if (bytes.isNotEmpty) {
          _messages.add(utf8.decode(bytes, allowMalformed: true));
        }
      });
      _state.add(BleLinkState.connected);
    } catch (e) {
      _errors.add(_friendlyError(e));
      await disconnect();
    }
  }

  Future<String> send(Map<String, dynamic> json) async {
    if (_command == null || _device?.isConnected != true) {
      throw StateError('Connect to the ESP32 first.');
    }
    final text = jsonEncode(json);
    try {
      await _command!.write(utf8.encode(text), withoutResponse: false);
      return text;
    } catch (e) {
      final message = _friendlyError(e);
      _errors.add(message);
      throw Exception(message);
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    await _device?.disconnect();
    _command = null;
    _state.add(BleLinkState.disconnected);
  }

  Future<void> removeBond() async {
    if (!Platform.isAndroid || _device == null) return;
    try {
      await _device!.removeBond();
    } catch (e) {
      _errors.add('Could not remove Android pairing: ${_friendlyError(e)}');
    }
  }

  String _friendlyError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  Future<void> dispose() async {
    await _scanSub?.cancel();
    await _connectionSub?.cancel();
    await _notifySub?.cancel();
    await _state.close();
    await _devices.close();
    await _messages.close();
    await _errors.close();
  }
}
