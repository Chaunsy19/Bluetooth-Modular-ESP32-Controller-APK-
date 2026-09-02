# ESP32 Modular BLE Protocol v1

## Transport

All messages are one UTF-8 JSON object. The phone writes commands to the command characteristic and subscribes to the status characteristic. The existing UUIDs remain unchanged:

| Purpose | UUID |
|---|---|
| Service | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| Commands: phone → ESP32 | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |
| Events/status: ESP32 → phone | `d6f1a100-8c3f-4b9a-923f-1b7350eaf6a4` |

Protocol version `1` uses a maximum command length of 512 bytes. The firmware negotiates a 256-byte MTU. A manifest is deliberately split into one module per notification so it never depends on a single oversized BLE packet.

## Manifest synchronization

Phone request:

```json
{"command":"get_modules"}
```

ESP32 response sequence:

```json
{"event":"manifest_start","protocol_version":1,"device_name":"ESP32-Control","revision":4,"count":2}
{"event":"module_definition","module":{"id":"relay_1","type":"toggle","name":"Water Pump","pin":26,"enabled":true,"order":0,"value":false}}
{"event":"module_definition","module":{"id":"servo_1","type":"servo","name":"Rudder","pin":18,"enabled":true,"order":1,"min":0,"max":180,"step":1,"unit":"degrees","value":90}}
{"event":"manifest_end","revision":4}
```

The app validates the version, count, IDs, types, ranges, and required values. It replaces the displayed manifest only after a matching `manifest_end`. A changed configuration produces:

```json
{"event":"config_changed","revision":5}
```

The app then requests the complete manifest again. It also requests it after every connection.

## Module fields

Common fields:

- `id`: stable unique identifier, 1–31 ASCII letters, digits, `_`, or `-`.
- `type`: widget capability type.
- `name`: persisted display name, 1–31 characters.
- `pin`: ESP32 GPIO when the module uses hardware.
- `enabled`: whether the main screen displays and operates the module.
- `order`: zero-based display position.
- `value`: current value.

Type-specific capabilities:

| Type | Required/optional fields | App control |
|---|---|---|
| `toggle` | Boolean `value` | ON/OFF segmented control |
| `slider` | Numeric `min`, `max`, `step`, `value`; optional `unit` | Debounced slider |
| `servo` | Numeric `min`, `max`, `step`, `value`; optional `unit` | Debounced angle slider |
| `value` | `value`; optional `min`, `max`, `unit`, `decimals` | Read-only formatted value |
| `button` | Optional `label` and `command_value` | One-shot action button |
| `text` | Text `value` | Read-only status text |

An unknown `type` remains in the layout and appears as an **Unsupported module** card.

## Commands

Set an output:

```json
{"command":"set_value","module_id":"relay_1","value":true}
{"command":"set_value","module_id":"pwm_1","value":75}
```

Run an action:

```json
{"command":"trigger_action","module_id":"all_off"}
```

Edit persisted configuration:

```json
{"command":"rename_module","module_id":"relay_1","name":"Main Pump"}
{"command":"set_module_enabled","module_id":"relay_1","enabled":false}
{"command":"set_module_pin","module_id":"relay_1","pin":27}
{"command":"set_module_order","order":["servo_1","relay_1","pwm_1","led_1","analog_1","all_off","status_1"]}
{"command":"reset_layout"}
```

`set_module_order` must contain every existing ID exactly once. “Hide” uses `set_module_enabled`; it does not delete firmware-defined hardware. `set_module_pin` rejects flash pins, input-only pins for outputs, non-ADC pins for analog modules, and pins already assigned to another module.

## Responses and events

```json
{"success":true,"module_id":"relay_1","value":true}
{"success":false,"error":"Invalid or conflicting pin for module type"}
{"event":"value_changed","module_id":"analog_1","value":2048}
```

Numeric output values are clamped and snapped to the module range and step before the success response. Sensor updates are notifications and do not need polling.
