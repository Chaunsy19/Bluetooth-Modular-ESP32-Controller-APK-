#include <Arduino.h>
#include <NimBLEDevice.h>
#include <ArduinoJson.h>
#include <ESP32Servo.h>
#include <Preferences.h>

// ================= MODULE CONFIGURATION =================
// Add, remove, or edit rows here. The Flutter app discovers them automatically.
// IDs must stay unique and should never change after deployment. Names may change.
constexpr uint8_t MAX_MODULES = 12;
enum class ModuleType : uint8_t { TOGGLE, SLIDER, SERVO, VALUE, BUTTON, TEXT };

struct Module {
  const char* id;
  ModuleType type;
  const char* defaultName;
  int8_t defaultPin;       // -1 means this module does not use a pin
  double minimum;
  double maximum;
  double step;
  const char* unit;
  uint8_t decimals;
  double defaultValue;
  const char* buttonLabel;
  bool analogInput;
  char name[32];
  int8_t pin;
  bool enabled;
  uint8_t order;
  double value;
  char text[48];
};

Module modules[] = {
  {"led_1", ModuleType::TOGGLE, "LED", 2, 0, 1, 1, "", 0, 0, nullptr, false},
  {"relay_1", ModuleType::TOGGLE, "Water Pump", 26, 0, 1, 1, "", 0, 0, nullptr, false},
  {"pwm_1", ModuleType::SLIDER, "Brightness", 25, 0, 100, 1, "%", 0, 0, nullptr, false},
  {"servo_1", ModuleType::SERVO, "Rudder", 18, 0, 180, 1, "degrees", 0, 90, nullptr, false},
  {"analog_1", ModuleType::VALUE, "Analog Input", 34, 0, 4095, 1, "ADC", 0, 0, nullptr, true},
  {"all_off", ModuleType::BUTTON, "Safety", -1, 0, 0, 0, "", 0, 0, "Turn All Outputs Off", false},
  {"status_1", ModuleType::TEXT, "Controller Status", -1, 0, 0, 0, "", 0, 0, nullptr, false},
};
constexpr uint8_t MODULE_COUNT = sizeof(modules) / sizeof(modules[0]);
static_assert(MODULE_COUNT <= MAX_MODULES, "Increase MAX_MODULES or remove modules");

constexpr char DEVICE_NAME[] = "ESP32-Control";
constexpr char SERVICE_UUID[] = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
constexpr char COMMAND_UUID[] = "beb5483e-36e1-4688-b7f5-ea07361b26a8";
constexpr char STATUS_UUID[]  = "d6f1a100-8c3f-4b9a-923f-1b7350eaf6a4";
constexpr uint8_t PROTOCOL_VERSION = 1;
constexpr uint32_t DISCONNECT_SAFE_OFF_MS = 3000;
constexpr uint32_t SENSOR_REPORT_MS = 1000;
constexpr uint32_t PWM_FREQUENCY = 5000;
constexpr uint8_t PWM_RESOLUTION_BITS = 8;
// ========================================================

NimBLECharacteristic* statusCharacteristic = nullptr;
Preferences preferences;
Servo servos[MAX_MODULES];
bool clientConnected = false;
bool safeOffApplied = true;
bool manifestRequested = false;
uint32_t disconnectedAt = 0;
uint32_t lastSensorReport = 0;
uint32_t configRevision = 1;

const char* typeName(ModuleType type) {
  switch (type) {
    case ModuleType::TOGGLE: return "toggle";
    case ModuleType::SLIDER: return "slider";
    case ModuleType::SERVO: return "servo";
    case ModuleType::VALUE: return "value";
    case ModuleType::BUTTON: return "button";
    case ModuleType::TEXT: return "text";
  }
  return "unknown";
}

int findModule(const char* id) {
  for (uint8_t i = 0; i < MODULE_COUNT; ++i) if (strcmp(modules[i].id, id) == 0) return i;
  return -1;
}

bool pinCanOutput(int pin) {
  return pin >= 0 && pin <= 33 && !(pin >= 6 && pin <= 11) && pin != 20 && pin != 24 && pin != 28 && pin != 29 && pin != 30 && pin != 31;
}

bool pinCanAnalogInput(int pin) {
  return pin == 32 || pin == 33 || pin == 34 || pin == 35 || pin == 36 || pin == 39;
}

bool pinUsedByOther(int pin, int moduleIndex) {
  if (pin < 0) return false;
  for (uint8_t i = 0; i < MODULE_COUNT; ++i) if (i != moduleIndex && modules[i].pin == pin) return true;
  return false;
}

bool validPinForModule(int index, int pin) {
  const Module& module = modules[index];
  if (module.type == ModuleType::BUTTON || module.type == ModuleType::TEXT) return pin == -1;
  if (pinUsedByOther(pin, index)) return false;
  if (module.type == ModuleType::VALUE) return module.analogInput ? pinCanAnalogInput(pin) : pin >= 0 && pin <= 39 && !(pin >= 6 && pin <= 11);
  return pinCanOutput(pin);
}

void sendJson(JsonDocument& document) {
  if (!clientConnected || statusCharacteristic == nullptr) return;
  String output;
  serializeJson(document, output);
  statusCharacteristic->setValue(output.c_str());
  statusCharacteristic->notify();
}

void sendError(const char* message) {
  JsonDocument reply;
  reply["success"] = false;
  reply["error"] = message;
  sendJson(reply);
}

void sendSuccess(const char* moduleId = nullptr) {
  JsonDocument reply;
  reply["success"] = true;
  if (moduleId != nullptr) reply["module_id"] = moduleId;
  sendJson(reply);
}

void notifyValue(uint8_t index) {
  if (!clientConnected || !modules[index].enabled) return;
  JsonDocument event;
  event["event"] = "value_changed";
  event["module_id"] = modules[index].id;
  if (modules[index].type == ModuleType::TOGGLE) event["value"] = modules[index].value >= 0.5;
  else if (modules[index].type == ModuleType::TEXT) event["value"] = modules[index].text;
  else event["value"] = modules[index].value;
  sendJson(event);
}

void notifyConfigChanged() {
  JsonDocument event;
  event["event"] = "config_changed";
  event["revision"] = configRevision;
  sendJson(event);
}

void persistModule(uint8_t index) {
  char key[8];
  snprintf(key, sizeof(key), "n%u", index); preferences.putString(key, modules[index].name);
  snprintf(key, sizeof(key), "p%u", index); preferences.putChar(key, modules[index].pin);
  snprintf(key, sizeof(key), "e%u", index); preferences.putBool(key, modules[index].enabled);
  snprintf(key, sizeof(key), "o%u", index); preferences.putUChar(key, modules[index].order);
}

void bumpRevision() {
  ++configRevision;
  preferences.putUInt("revision", configRevision);
  notifyConfigChanged();
  delay(25);
}

void loadConfiguration() {
  configRevision = preferences.getUInt("revision", 1);
  for (uint8_t i = 0; i < MODULE_COUNT; ++i) {
    char key[8];
    snprintf(key, sizeof(key), "n%u", i);
    String savedName = preferences.getString(key, modules[i].defaultName);
    strlcpy(modules[i].name, savedName.c_str(), sizeof(modules[i].name));
    snprintf(key, sizeof(key), "p%u", i); modules[i].pin = preferences.getChar(key, modules[i].defaultPin);
    snprintf(key, sizeof(key), "e%u", i); modules[i].enabled = preferences.getBool(key, true);
    snprintf(key, sizeof(key), "o%u", i); modules[i].order = preferences.getUChar(key, i);
    modules[i].value = modules[i].defaultValue;
    modules[i].text[0] = '\0';
    if (!validPinForModule(i, modules[i].pin)) modules[i].pin = modules[i].defaultPin;
  }
  bool usedOrder[MAX_MODULES] = {};
  bool orderValid = true;
  for (uint8_t i = 0; i < MODULE_COUNT; ++i) {
    if (modules[i].order >= MODULE_COUNT || usedOrder[modules[i].order]) orderValid = false;
    else usedOrder[modules[i].order] = true;
  }
  if (!orderValid) for (uint8_t i = 0; i < MODULE_COUNT; ++i) modules[i].order = i;
}

double snappedValue(const Module& module, double raw) {
  const double clamped = constrain(raw, module.minimum, module.maximum);
  if (module.step <= 0) return clamped;
  return module.minimum + round((clamped - module.minimum) / module.step) * module.step;
}

void configureModulePin(uint8_t index) {
  Module& module = modules[index];
  if (module.pin < 0) return;
  if (module.type == ModuleType::TOGGLE) { pinMode(module.pin, OUTPUT); digitalWrite(module.pin, LOW); module.value = 0; }
  else if (module.type == ModuleType::SLIDER) { ledcAttach(module.pin, PWM_FREQUENCY, PWM_RESOLUTION_BITS); ledcWrite(module.pin, 0); module.value = module.minimum; }
  else if (module.type == ModuleType::SERVO) { servos[index].setPeriodHertz(50); servos[index].attach(module.pin, 500, 2400); servos[index].write((int)module.value); }
  else if (module.type == ModuleType::VALUE) pinMode(module.pin, INPUT);
}

void detachModulePin(uint8_t index) {
  Module& module = modules[index];
  if (module.pin < 0) return;
  if (module.type == ModuleType::SLIDER) ledcDetach(module.pin);
  if (module.type == ModuleType::SERVO) servos[index].detach();
  if (module.type == ModuleType::TOGGLE) digitalWrite(module.pin, LOW);
  pinMode(module.pin, INPUT);
}

void applyValue(uint8_t index, double value) {
  Module& module = modules[index];
  module.value = snappedValue(module, value);
  if (module.type == ModuleType::TOGGLE) digitalWrite(module.pin, module.value >= 0.5 ? HIGH : LOW);
  else if (module.type == ModuleType::SLIDER) {
    const uint32_t maximumDuty = (1UL << PWM_RESOLUTION_BITS) - 1;
    const uint32_t duty = (uint32_t)((module.value - module.minimum) * maximumDuty / (module.maximum - module.minimum));
    ledcWrite(module.pin, duty);
  } else if (module.type == ModuleType::SERVO) servos[index].write((int)module.value);
}

void safeOutputsOff() {
  for (uint8_t i = 0; i < MODULE_COUNT; ++i) {
    if (modules[i].type == ModuleType::TOGGLE || modules[i].type == ModuleType::SLIDER) {
      applyValue(i, modules[i].minimum);
      if (clientConnected) {
        notifyValue(i);
        delay(20);
      }
    }
  }
  safeOffApplied = true;
}

void addModuleJson(JsonObject object, const Module& module) {
  object["id"] = module.id; object["type"] = typeName(module.type); object["name"] = module.name;
  object["enabled"] = module.enabled; object["order"] = module.order;
  if (module.pin >= 0) object["pin"] = module.pin;
  if (module.type == ModuleType::TOGGLE) object["value"] = module.value >= 0.5;
  else if (module.type == ModuleType::TEXT) object["value"] = module.text;
  else object["value"] = module.value;
  if (module.type == ModuleType::SLIDER || module.type == ModuleType::SERVO || module.type == ModuleType::VALUE) {
    object["min"] = module.minimum; object["max"] = module.maximum;
  }
  if (module.type == ModuleType::SLIDER || module.type == ModuleType::SERVO) object["step"] = module.step;
  if (strlen(module.unit) > 0) object["unit"] = module.unit;
  if (module.type == ModuleType::VALUE) object["decimals"] = module.decimals;
  if (module.type == ModuleType::BUTTON) object["label"] = module.buttonLabel;
}

void sendManifest() {
  JsonDocument start;
  start["event"] = "manifest_start"; start["protocol_version"] = PROTOCOL_VERSION;
  start["device_name"] = DEVICE_NAME; start["revision"] = configRevision; start["count"] = MODULE_COUNT;
  sendJson(start); delay(35);
  for (uint8_t order = 0; order < MODULE_COUNT; ++order) {
    for (uint8_t i = 0; i < MODULE_COUNT; ++i) if (modules[i].order == order) {
      JsonDocument definition;
      definition["event"] = "module_definition";
      addModuleJson(definition["module"].to<JsonObject>(), modules[i]);
      sendJson(definition); delay(35);
    }
  }
  JsonDocument end;
  end["event"] = "manifest_end"; end["revision"] = configRevision;
  sendJson(end);
}

bool commandHasModule(JsonDocument& command, int& index) {
  if (!command["module_id"].is<const char*>()) { sendError("Missing module_id"); return false; }
  index = findModule(command["module_id"]);
  if (index < 0) { sendError("Unknown module_id"); return false; }
  return true;
}

void handleCommand(const std::string& raw) {
  if (raw.empty() || raw.length() > 512) return sendError("Command is empty or too long");
  JsonDocument command;
  if (deserializeJson(command, raw) || !command.is<JsonObject>()) return sendError("Invalid JSON");
  if (!command["command"].is<const char*>()) return sendError("Missing command");
  const char* action = command["command"];
  if (strcmp(action, "get_modules") == 0) { manifestRequested = true; return; }
  if (strcmp(action, "reset_layout") == 0) {
    for (uint8_t i = 0; i < MODULE_COUNT; ++i) {
      detachModulePin(i); strlcpy(modules[i].name, modules[i].defaultName, sizeof(modules[i].name));
      modules[i].pin = modules[i].defaultPin; modules[i].enabled = true; modules[i].order = i;
      configureModulePin(i); persistModule(i);
    }
    bumpRevision(); sendSuccess(); return;
  }
  if (strcmp(action, "set_module_order") == 0) {
    if (!command["order"].is<JsonArray>() || command["order"].size() != MODULE_COUNT) return sendError("Order must contain every module ID");
    bool seen[MAX_MODULES] = {};
    uint8_t position = 0;
    for (JsonVariant id : command["order"].as<JsonArray>()) {
      if (!id.is<const char*>()) return sendError("Order contains an invalid ID");
      const int found = findModule(id.as<const char*>());
      if (found < 0 || seen[found]) return sendError("Order contains an unknown or duplicate ID");
      seen[found] = true; modules[found].order = position++;
    }
    for (uint8_t i = 0; i < MODULE_COUNT; ++i) persistModule(i);
    bumpRevision(); sendSuccess(); return;
  }
  int index;
  if (!commandHasModule(command, index)) return;
  Module& module = modules[index];
  if (strcmp(action, "set_value") == 0) {
    if (!module.enabled) return sendError("Module is disabled");
    if (module.type == ModuleType::TOGGLE) {
      if (!command["value"].is<bool>()) return sendError("Toggle value must be boolean");
      applyValue(index, command["value"].as<bool>() ? 1 : 0);
    } else if (module.type == ModuleType::SLIDER || module.type == ModuleType::SERVO) {
      if (!command["value"].is<double>() && !command["value"].is<int>()) return sendError("Value must be numeric");
      applyValue(index, command["value"].as<double>());
    } else return sendError("Module is read-only");
    JsonDocument reply; reply["success"] = true; reply["module_id"] = module.id;
    if (module.type == ModuleType::TOGGLE) reply["value"] = module.value >= 0.5; else reply["value"] = module.value;
    sendJson(reply); return;
  }
  if (strcmp(action, "trigger_action") == 0) {
    if (module.type != ModuleType::BUTTON) return sendError("Module is not an action button");
    if (strcmp(module.id, "all_off") == 0) safeOutputsOff();
    sendSuccess(module.id);
    manifestRequested = true;
    return;
  }
  if (strcmp(action, "rename_module") == 0) {
    if (!command["name"].is<const char*>()) return sendError("Name must be text");
    const char* name = command["name"];
    if (strlen(name) < 1 || strlen(name) >= sizeof(module.name)) return sendError("Name must be 1 to 31 characters");
    strlcpy(module.name, name, sizeof(module.name)); persistModule(index); bumpRevision(); sendSuccess(module.id); return;
  }
  if (strcmp(action, "set_module_enabled") == 0) {
    if (!command["enabled"].is<bool>()) return sendError("enabled must be boolean");
    module.enabled = command["enabled"];
    if (!module.enabled && (module.type == ModuleType::TOGGLE || module.type == ModuleType::SLIDER)) applyValue(index, module.minimum);
    persistModule(index); bumpRevision(); sendSuccess(module.id); return;
  }
  if (strcmp(action, "set_module_pin") == 0) {
    if (!command["pin"].is<int>()) return sendError("pin must be an integer");
    const int newPin = command["pin"];
    if (!validPinForModule(index, newPin)) return sendError("Invalid or conflicting pin for module type");
    detachModulePin(index); module.pin = newPin; configureModulePin(index); persistModule(index); bumpRevision(); sendSuccess(module.id); return;
  }
  sendError("Unknown command");
}

class CommandCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* characteristic, NimBLEConnInfo& info) override { handleCommand(characteristic->getValue()); }
};

class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer* server, NimBLEConnInfo& info) override {
    clientConnected = true; safeOffApplied = false;
    const int status = findModule("status_1"); if (status >= 0) strlcpy(modules[status].text, "Connected", sizeof(modules[status].text));
  }
  void onDisconnect(NimBLEServer* server, NimBLEConnInfo& info, int reason) override {
    clientConnected = false; disconnectedAt = millis(); manifestRequested = false; NimBLEDevice::startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  preferences.begin("modules", false);
  loadConfiguration();
  for (uint8_t i = 0; i < MODULE_COUNT; ++i) configureModulePin(i);
  const int status = findModule("status_1"); if (status >= 0) strlcpy(modules[status].text, "Ready", sizeof(modules[status].text));
  safeOutputsOff();

  NimBLEDevice::init(DEVICE_NAME); NimBLEDevice::setMTU(256);
  NimBLEServer* server = NimBLEDevice::createServer(); server->setCallbacks(new ServerCallbacks());
  NimBLEService* service = server->createService(SERVICE_UUID);
  NimBLECharacteristic* command = service->createCharacteristic(COMMAND_UUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  command->setCallbacks(new CommandCallbacks());
  statusCharacteristic = service->createCharacteristic(STATUS_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  statusCharacteristic->setValue("{\"event\":\"ready\"}"); service->start();
  NimBLEAdvertising* advertising = NimBLEDevice::getAdvertising(); advertising->setName(DEVICE_NAME);
  advertising->addServiceUUID(SERVICE_UUID); advertising->enableScanResponse(true); advertising->start();
  Serial.println("ESP32 modular BLE controller ready");
}

void loop() {
  const uint32_t now = millis();
  if (manifestRequested && clientConnected) { manifestRequested = false; sendManifest(); }
  if (!clientConnected && !safeOffApplied && now - disconnectedAt >= DISCONNECT_SAFE_OFF_MS) { safeOutputsOff(); Serial.println("BLE timeout: outputs switched off"); }
  if (clientConnected && now - lastSensorReport >= SENSOR_REPORT_MS) {
    lastSensorReport = now;
    for (uint8_t i = 0; i < MODULE_COUNT; ++i) if (modules[i].enabled && modules[i].type == ModuleType::VALUE) {
      modules[i].value = modules[i].analogInput ? analogRead(modules[i].pin) : digitalRead(modules[i].pin);
      notifyValue(i); delay(20);
    }
  }
  delay(10);
}
