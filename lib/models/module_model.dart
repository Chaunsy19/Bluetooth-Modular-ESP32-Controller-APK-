class ProtocolException implements Exception {
  final String message;
  const ProtocolException(this.message);
  @override
  String toString() => message;
}

class ModuleModel {
  final String id;
  final String type;
  final String name;
  final int? pin;
  final bool enabled;
  final bool deletable;
  final int order;
  final dynamic value;
  final double? min;
  final double? max;
  final double? step;
  final String unit;
  final int decimals;
  final String? label;
  final dynamic commandValue;

  const ModuleModel({
    required this.id,
    required this.type,
    required this.name,
    this.pin,
    this.enabled = true,
    this.deletable = false,
    this.order = 0,
    this.value,
    this.min,
    this.max,
    this.step,
    this.unit = '',
    this.decimals = 0,
    this.label,
    this.commandValue,
  });

  bool get isOutput =>
      const {'toggle', 'slider', 'servo', 'button'}.contains(type);
  bool get isSupported => const {
        'toggle',
        'slider',
        'servo',
        'value',
        'button',
        'text'
      }.contains(type);

  factory ModuleModel.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw ProtocolException('Module $key must be a non-empty string.');
      }
      return value.trim();
    }

    num? number(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! num) {
        throw ProtocolException(
            'Module ${json['id'] ?? ''} $key must be numeric.');
      }
      return value;
    }

    final id = requiredString('id');
    if (!RegExp(r'^[A-Za-z0-9_-]{1,31}$').hasMatch(id)) {
      throw ProtocolException('Invalid module ID: $id');
    }
    final type = requiredString('type');
    final name = requiredString('name');
    final min = number('min')?.toDouble();
    final max = number('max')?.toDouble();
    final step = number('step')?.toDouble();
    if (min != null && max != null && min > max) {
      throw ProtocolException('$id has min greater than max.');
    }
    if (step != null && step <= 0) {
      throw ProtocolException('$id has an invalid step.');
    }
    final common = ModuleModel(
      id: id,
      type: type,
      name: name,
      pin: number('pin')?.toInt(),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      deletable: json['deletable'] is bool ? json['deletable'] as bool : false,
      order: number('order')?.toInt() ?? 0,
      value: json['value'],
      min: min,
      max: max,
      step: step,
      unit: json['unit'] is String ? json['unit'] as String : '',
      decimals: number('decimals')?.toInt().clamp(0, 6) ?? 0,
      label: json['label'] is String ? json['label'] as String : null,
      commandValue: json['command_value'],
    );
    switch (type) {
      case 'toggle':
        if (common.value is! bool) {
          throw ProtocolException('$id toggle value must be boolean.');
        }
        return ToggleModule.from(common);
      case 'slider':
        _validateRange(common);
        return SliderModule.from(common);
      case 'servo':
        _validateRange(common);
        return ServoModule.from(common);
      case 'value':
        return ValueModule.from(common);
      case 'button':
        return ButtonModule.from(common);
      case 'text':
        return TextModule.from(common);
      default:
        return UnsupportedModule.from(common);
    }
  }

  static void _validateRange(ModuleModel module) {
    if (module.min == null ||
        module.max == null ||
        module.step == null ||
        module.value is! num) {
      throw ProtocolException(
          '${module.id} requires numeric min, max, step, and value.');
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        if (pin != null) 'pin': pin,
        'enabled': enabled,
        'deletable': deletable,
        'order': order,
        'value': value,
        if (min != null) 'min': min,
        if (max != null) 'max': max,
        if (step != null) 'step': step,
        if (unit.isNotEmpty) 'unit': unit,
        if (decimals != 0) 'decimals': decimals,
        if (label != null) 'label': label,
        if (commandValue != null) 'command_value': commandValue,
      };

  ModuleModel withChanges(
      {String? name, int? pin, bool? enabled, int? order, dynamic value}) {
    final json = toJson();
    if (name != null) json['name'] = name;
    if (pin != null) json['pin'] = pin;
    if (enabled != null) json['enabled'] = enabled;
    if (order != null) json['order'] = order;
    if (value != null) json['value'] = value;
    return ModuleModel.fromJson(json);
  }
}

class ToggleModule extends ModuleModel {
  ToggleModule.from(ModuleModel m)
      : super(
            id: m.id,
            type: m.type,
            name: m.name,
            pin: m.pin,
            enabled: m.enabled,
            deletable: m.deletable,
            order: m.order,
            value: m.value,
            min: m.min,
            max: m.max,
            step: m.step,
            unit: m.unit,
            decimals: m.decimals,
            label: m.label,
            commandValue: m.commandValue);
}

class SliderModule extends ModuleModel {
  SliderModule.from(ModuleModel m)
      : super(
            id: m.id,
            type: m.type,
            name: m.name,
            pin: m.pin,
            enabled: m.enabled,
            deletable: m.deletable,
            order: m.order,
            value: m.value,
            min: m.min,
            max: m.max,
            step: m.step,
            unit: m.unit,
            decimals: m.decimals,
            label: m.label,
            commandValue: m.commandValue);
}

class ServoModule extends ModuleModel {
  ServoModule.from(ModuleModel m)
      : super(
            id: m.id,
            type: m.type,
            name: m.name,
            pin: m.pin,
            enabled: m.enabled,
            deletable: m.deletable,
            order: m.order,
            value: m.value,
            min: m.min,
            max: m.max,
            step: m.step,
            unit: m.unit,
            decimals: m.decimals,
            label: m.label,
            commandValue: m.commandValue);
}

class ValueModule extends ModuleModel {
  ValueModule.from(ModuleModel m)
      : super(
            id: m.id,
            type: m.type,
            name: m.name,
            pin: m.pin,
            enabled: m.enabled,
            deletable: m.deletable,
            order: m.order,
            value: m.value,
            min: m.min,
            max: m.max,
            step: m.step,
            unit: m.unit,
            decimals: m.decimals,
            label: m.label,
            commandValue: m.commandValue);
}

class ButtonModule extends ModuleModel {
  ButtonModule.from(ModuleModel m)
      : super(
            id: m.id,
            type: m.type,
            name: m.name,
            pin: m.pin,
            enabled: m.enabled,
            deletable: m.deletable,
            order: m.order,
            value: m.value,
            min: m.min,
            max: m.max,
            step: m.step,
            unit: m.unit,
            decimals: m.decimals,
            label: m.label,
            commandValue: m.commandValue);
}

class TextModule extends ModuleModel {
  TextModule.from(ModuleModel m)
      : super(
            id: m.id,
            type: m.type,
            name: m.name,
            pin: m.pin,
            enabled: m.enabled,
            deletable: m.deletable,
            order: m.order,
            value: m.value,
            min: m.min,
            max: m.max,
            step: m.step,
            unit: m.unit,
            decimals: m.decimals,
            label: m.label,
            commandValue: m.commandValue);
}

class UnsupportedModule extends ModuleModel {
  UnsupportedModule.from(ModuleModel m)
      : super(
            id: m.id,
            type: m.type,
            name: m.name,
            pin: m.pin,
            enabled: m.enabled,
            deletable: m.deletable,
            order: m.order,
            value: m.value,
            min: m.min,
            max: m.max,
            step: m.step,
            unit: m.unit,
            decimals: m.decimals,
            label: m.label,
            commandValue: m.commandValue);
}

class ModuleManifest {
  final int protocolVersion;
  final String deviceName;
  final int revision;
  final List<ModuleModel> modules;
  const ModuleManifest(
      {required this.protocolVersion,
      required this.deviceName,
      required this.revision,
      required this.modules});

  factory ModuleManifest.fromJson(Map<String, dynamic> json) {
    if (json['protocol_version'] != 1) {
      throw const ProtocolException('Unsupported protocol version.');
    }
    if (json['device_name'] is! String ||
        json['revision'] is! num ||
        json['modules'] is! List) {
      throw const ProtocolException('Invalid manifest.');
    }
    final ids = <String>{};
    final modules = <ModuleModel>[];
    for (final item in json['modules'] as List) {
      if (item is! Map) throw const ProtocolException('Invalid module entry.');
      final module = ModuleModel.fromJson(Map<String, dynamic>.from(item));
      if (!ids.add(module.id)) {
        throw ProtocolException('Duplicate module ID: ${module.id}');
      }
      modules.add(module);
    }
    modules.sort((a, b) => a.order.compareTo(b.order));
    return ModuleManifest(
        protocolVersion: 1,
        deviceName: json['device_name'] as String,
        revision: (json['revision'] as num).toInt(),
        modules: modules);
  }

  Map<String, dynamic> toJson() => {
        'protocol_version': protocolVersion,
        'device_name': deviceName,
        'revision': revision,
        'modules': modules.map((m) => m.toJson()).toList()
      };
}
