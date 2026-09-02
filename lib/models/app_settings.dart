class AppSettings {
  static const defaultDeviceName = 'ESP32-Control';
  static const defaultServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
  static const defaultCommandUuid = 'beb5483e-36e1-4688-b7f5-ea07361b26a8';
  static const defaultStatusUuid = 'd6f1a100-8c3f-4b9a-923f-1b7350eaf6a4';

  final String deviceName;
  final String serviceUuid;
  final String commandUuid;
  final String statusUuid;
  final String pairingCode;
  final String themeMode;

  const AppSettings({
    this.deviceName = defaultDeviceName,
    this.serviceUuid = defaultServiceUuid,
    this.commandUuid = defaultCommandUuid,
    this.statusUuid = defaultStatusUuid,
    this.pairingCode = '123456',
    this.themeMode = 'system',
  });

  AppSettings copyWith({
    String? deviceName,
    String? serviceUuid,
    String? commandUuid,
    String? statusUuid,
    String? pairingCode,
    String? themeMode,
  }) =>
      AppSettings(
        deviceName: deviceName ?? this.deviceName,
        serviceUuid: serviceUuid ?? this.serviceUuid,
        commandUuid: commandUuid ?? this.commandUuid,
        statusUuid: statusUuid ?? this.statusUuid,
        pairingCode: pairingCode ?? this.pairingCode,
        themeMode: themeMode ?? this.themeMode,
      );
}
