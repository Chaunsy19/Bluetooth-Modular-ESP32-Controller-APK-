# Modular ESP32 BLE Control

Bluetooth Modular ESP32 Controller is an Android app and ESP32 firmware system for controlling electronics wirelessly over Bluetooth Low Energy. The ESP32 defines the available hardware modules—such as toggles, PWM sliders, servos, sensors, and buttons—and the app automatically generates the interface from that configuration. This makes it easy to adapt the system for RC vehicles, robots, and other projects without modifying the app each time hardware changes. The long-term goal is to create a flexible, user-friendly receiver platform for people who want configurable control without needing to write code.

The ESP32 defines its available hardware modules. The Flutter Android/iOS app downloads that manifest after connecting and builds the controls dynamically. Adding another supported module requires only one firmware configuration row—no Flutter UI changes.

See [PROTOCOL.md](PROTOCOL.md) for every JSON message and field.

## Download the Android app

There are no requirements for the mobile phone other than the app and BLE connectivity.

Open the repository's [Releases page](https://github.com/Chaunsy19/Bluetooth-Modular-ESP32-Controller-APK-/releases), select the newest release, and download the `.apk` file under **Assets**.

On the Android phone, open the downloaded APK and allow installation from that browser or file manager when Android asks. Google Play Protect may display a warning because this app is installed directly instead of through the Play Store.

Maintainers create a release by pushing a version tag, for example:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions then checks the project, builds the Android APK, and attaches it to a new GitHub Release automatically.

Android production releases use application ID `com.chaunsy19.esp32control` and a permanent private signing key. The ignored files `android/app/upload-keystore.jks` and `android/key.properties` must never be committed. GitHub Actions requires the repository secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD`. Back up the keystore and its credentials securely; losing them prevents future APKs from updating existing installations.

## Architecture

```text
ESP32 module table + Preferences
              ↓ versioned BLE manifest
BLE service → validated models/state → widget registry → module cards
              ↑ commands/events        ↕
                                  layout editor
```

- `lib/services/ble_service.dart`: scan, reconnect, discovery, writes, notifications.
- `lib/services/module_protocol.dart`: atomic chunked-manifest assembly.
- `lib/models/module_model.dart`: base model, typed models, validation, unknown-type fallback.
- `lib/controllers/app_controller.dart`: connection/sync state, commands, caching, slider debounce.
- `lib/widgets/module_card.dart`: registry mapping capabilities to widgets.
- `lib/screens/layout_editor_screen.dart`: reorder and enable/disable.
- `lib/screens/module_details_screen.dart`: rename, validated pin change, and hide.
- `lib/screens/add_module_screen.dart`: create persisted modules with type-specific settings.
- `esp32/ESP32_Control/ESP32_Control.ino`: module definitions, hardware behavior, persistence, validation, and fail-safe.

The ESP32 is the source of truth. Names, enabled state, order, and assigned pins are stored in ESP32 NVS via `Preferences`, so they follow the controller across phones. The phone caches the last validated manifest by BLE device ID for quick restoration, but refreshes it after reconnecting. Hardware types, IDs, ranges, units, and behavior remain firmware-owned.

Regular modules can be converted in the app between on/off output, PWM light, servo, reversible motor/winch, digital input, and analog input. The universal firmware validates and saves the new hardware profile without another firmware upload. A reversible motor profile uses one PWM/enable pin plus two direction pins and must connect through a properly rated H-bridge.

## Requirements

- Flutter 3.47.2 or compatible stable release
- Android Studio with Android SDK/NDK; Xcode and CocoaPods on a Mac for iOS
- Arduino IDE 2 or Arduino CLI
- `esp32 by Espressif Systems` 3.x
- Arduino libraries: `NimBLE-Arduino` 2.x, `ArduinoJson` 7.x, `ESP32Servo` 3.x
- Flutter packages: `flutter_blue_plus 2.3.12`, `shared_preferences 2.5.5`

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Use a physical phone. BLE scanning generally does not work in an emulator.

## Upload the ESP32 firmware

1. Open `esp32/ESP32_Control/ESP32_Control.ino`.
2. Select **DOIT ESP32 DEVKIT V1** and the correct serial port.
3. Upload. If it waits at `Connecting`, hold **BOOT** until transfer begins.
4. Open Serial Monitor at 115200 baud. Look for `ESP32 modular BLE controller ready`.
5. In the phone app, scan for `ESP32-Control`, connect, and wait for **Layout synchronized**.

The first phone to complete encrypted pairing becomes the controller owner. Set a unique six-digit `BLE_PAIRING_CODE` near the top of the sketch and enter the same code in App Settings. To transfer ownership, hold the ESP32 **BOOT** button while powering it on for at least three seconds, then use **Forget ESP32 and phone pairing** in the old phone app. On iOS, also remove the device from Bluetooth settings if necessary.

Arduino CLI equivalent:

```powershell
C:\ArduinoCLI\arduino-cli.exe compile --fqbn esp32:esp32:esp32doit-devkit-v1 esp32\ESP32_Control
C:\ArduinoCLI\arduino-cli.exe upload -p COM_PORT --fqbn esp32:esp32:esp32doit-devkit-v1 esp32\ESP32_Control
```

Replace `COM_PORT` with the ESP32 port shown by `arduino-cli board list`.

## Add or change a module

All default definitions are together near the top of the sketch:

```cpp
Module modules[] = {
  {"relay_1", ModuleType::TOGGLE, "Water Pump", 26, 0, 1, 1, "", 0, 0, nullptr, false},
  {"pwm_1", ModuleType::SLIDER, "Brightness", 25, 0, 100, 1, "%", 0, 0, nullptr, false},
};
```

Fields, in order:

```text
stable ID, type, default name, pin, minimum, maximum, step,
unit, decimals, default value, button label, analog-input flag
```

To add a relay, copy a `TOGGLE` row, give it a new unique ID and unused output pin, then upload. Reconnect or pull down to refresh; the new ON/OFF card appears automatically. Multiple rows may use the same type, but IDs and assigned pins must be unique.

You can also add hardware at runtime: open **Edit layout**, tap **+**, choose the type, enter its name/pin/settings, and tap **Add module**. The ESP32 assigns a stable ID and persists the complete definition. Ordinary modules can be permanently deleted from their Module details page. Safety and Controller Status remain protected. Reset restores the original compiled table if defaults were deleted.

To change type, pin, limits, unit, or default value, edit that row. Keep the ID unchanged so persisted layout stays associated with it. A pin can also be changed from **Edit layout → module details**; firmware rejects incompatible or conflicting assignments.

Persisted names/pins/order override edited defaults. To adopt every newly edited default, press **Reset** in Edit layout. Removing a row from firmware permanently removes that hardware module. **Hide module** only sets `enabled=false` and can be reversed in Edit layout.

To add an entirely new module type, add its enum/manifest behavior in firmware, a parser subtype in `module_model.dart`, and one widget builder registration in `module_card.dart`. Older apps safely show an unsupported card.

## Default wiring

Disconnect power while wiring. ESP32 GPIO is 3.3 V. Use a common ground for external supplies.

| Module | Default pin | Wiring |
|---|---:|---|
| LED toggle | GPIO 2 | Built-in LED, or GPIO → 220–330 Ω → LED anode; cathode → GND |
| Relay toggle | GPIO 26 | GPIO → 3.3 V-compatible relay-module IN; external rated module supply; common GND |
| PWM slider | GPIO 25 | GPIO → driver/MOSFET input. Never drive a motor or power load directly. Add flyback protection for inductive loads. |
| Servo | GPIO 18 | GPIO → signal; separate regulated 5–6 V servo supply; common GND |
| Analog value | GPIO 34 | 0–3.3 V sensor output → GPIO 34; sensor GND → GND |

Never connect mains voltage on a breadboard. Use rated isolation, fusing, drivers, and qualified help.

## Safety and validation

- Toggle and PWM outputs start off.
- Toggle and PWM outputs return to their minimum after a BLE disconnect timeout (3 seconds).
- Servo values, sliders, and other numbers are clamped and snapped to configured ranges.
- Firmware accepts only the recommended DevKit V1 pins: outputs on GPIO 13, 14, 16–19, 21–23, 25–27, 32, or 33; analog inputs on GPIO 32–36 or 39; digital inputs on those output pins plus GPIO 34–36 or 39.
- Analog modules require ADC1-capable pins, avoiding ADC2/Bluetooth conflicts.
- A pin cannot belong to two modules.
- Invalid IDs, commands, JSON, names, values, order lists, and pin changes return errors.
- BLE commands and status require encrypted, bonded connections. The first paired phone's stable BLE identity is retained as owner until a physical BOOT-button reset; rotating over-the-air addresses do not break reconnection.
- Module storage uses fixed arrays/character buffers; dynamic allocation is limited mainly to JSON/BLE library operations.

## Android and iOS permissions

Android `android/app/src/main/AndroidManifest.xml` declares BLE hardware plus Android 12+ `BLUETOOTH_SCAN` and `BLUETOOTH_CONNECT`. Legacy Bluetooth/location permissions are limited to older Android versions. On Android 12+, allow **Nearby devices**. On Android 11 or older, also allow Location and enable Location services.

iOS `ios/Runner/Info.plist` contains `NSBluetoothAlwaysUsageDescription` and the older compatibility description. Build iOS on a Mac, choose an Apple development team in Xcode, connect a physical iPhone, then run `flutter run`. Background BLE is not enabled; automatic reconnect is best-effort while the app is running.

## Test procedure

1. **Relay/toggle:** connect, tap relay ON/OFF, confirm the selected state and GPIO 26 output.
2. **PWM:** move Brightness; confirm the displayed value and PWM on GPIO 25. Writes are debounced by 180 ms.
3. **Servo:** move Rudder from 0–180°; confirm physical travel and value response.
4. **Analog:** vary a safe 0–3.3 V signal on GPIO 34; confirm the card updates about once per second.
5. **Rename:** Edit layout → module pencil → change name → Save. Reconnect and confirm it remains.
6. **Rearrange:** drag module rows in Edit layout. Reconnect and confirm the order remains.
7. **Add/delete:** tap +, add a toggle on an unused valid pin, test it, reconnect to verify persistence, then permanently delete it from Module details.
8. **Hide/enable:** turn a row off in Edit layout; confirm the switch and main screen update immediately, then re-enable it.
9. **Disconnect:** turn Bluetooth off. After 3 seconds confirm toggle/PWM outputs are safe-off. Turn it back on and confirm reconnect plus synchronization.
10. **Firmware-defined module:** add another unique `TOGGLE` row in firmware, upload, reconnect, and confirm the new card appears without changing Flutter.
11. **Invalid pin:** try assigning an already-used or input-only pin to a toggle; confirm the app shows the firmware error.

## Troubleshooting

- **No device found:** use a real phone, confirm Serial Monitor is ready, grant Bluetooth/Nearby Devices, close other BLE apps, and test with nRF Connect.
- **Connects but does not synchronize:** confirm all three UUIDs match and the phone shows firmware protocol version 1. Pull down to request the manifest again.
- **Configuration reverts:** press Save and wait for the success/configuration notification. Reset layout intentionally restores firmware defaults.
- **Output resets ESP32:** use a separate adequate load/servo supply with common ground.
- **Compile says `ledcAttach` missing:** install Espressif ESP32 core 3.x.
- **Old phone layout:** tap **Forget saved ESP32**, reconnect, or pull down to force a fresh manifest.
