import 'dart:convert';

import 'package:bleunlock_core/bleunlock_core.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

class AppSettings {
  const AppSettings({
    required this.config,
    required this.selectedDeviceIds,
  });

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final configJson = json['config'];
    final selectedIdsJson = json['selectedDeviceIds'];

    return AppSettings(
      config: configJson is Map
          ? _configFromJson(configJson.cast<String, Object?>())
          : const ProximityConfig(),
      selectedDeviceIds: selectedIdsJson is List
          ? selectedIdsJson.whereType<String>().toSet()
          : const {},
    );
  }

  final ProximityConfig config;
  final Set<String> selectedDeviceIds;

  Map<String, Object?> toJson() {
    final sortedSelectedIds = selectedDeviceIds.toList()..sort();
    return {
      'version': 1,
      'config': _configToJson(config),
      'selectedDeviceIds': sortedSelectedIds,
    };
  }
}

abstract interface class AppSettingsRepository {
  Future<AppSettings?> load();

  Future<void> save(AppSettings settings);
}

class SecureStoreAppSettingsRepository implements AppSettingsRepository {
  SecureStoreAppSettingsRepository(
    this._store, {
    String key = _defaultKey,
  }) : _key = key;

  static const String _defaultKey = 'bleunlock.settings.v1';

  final SecureStore _store;
  final String _key;

  @override
  Future<AppSettings?> load() async {
    if (!_store.capability.isUsable) {
      return null;
    }

    final value = await _store.readSecret(_key);
    if (value == null || value.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) {
        return null;
      }

      return AppSettings.fromJson(decoded.cast<String, Object?>());
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    if (!_store.capability.isUsable) {
      return;
    }

    await _store.writeSecret(_key, jsonEncode(settings.toJson()));
  }
}

class InMemoryAppSettingsRepository implements AppSettingsRepository {
  InMemoryAppSettingsRepository({AppSettings? initialSettings})
      : savedSettings = initialSettings;

  AppSettings? savedSettings;

  @override
  Future<AppSettings?> load() async => savedSettings;

  @override
  Future<void> save(AppSettings settings) async {
    savedSettings = settings;
  }
}

Map<String, Object?> _configToJson(ProximityConfig config) {
  return {
    'unlockRssi': config.unlockRssi,
    'lockRssi': config.lockRssi,
    'noSignalTimeoutSeconds': config.noSignalTimeout.inSeconds,
    'lockDelaySeconds': config.lockDelay.inSeconds,
    'minimumVisibleRssi': config.minimumVisibleRssi,
    'unlockDeviceLogic': config.unlockDeviceLogic.name,
    'lockDeviceLogic': config.lockDeviceLogic.name,
    'wakeOnProximity': config.wakeOnProximity,
    'enableMacAutoUnlock': config.enableMacAutoUnlock,
    'rssiWindowSize': config.rssiWindowSize,
  };
}

ProximityConfig _configFromJson(Map<String, Object?> json) {
  return ProximityConfig(
    unlockRssi: _intValue(json['unlockRssi'], -60),
    lockRssi: _intValue(json['lockRssi'], -80),
    noSignalTimeout: Duration(
      seconds: _intValue(json['noSignalTimeoutSeconds'], 60),
    ),
    lockDelay: Duration(seconds: _intValue(json['lockDelaySeconds'], 5)),
    minimumVisibleRssi: _intValue(json['minimumVisibleRssi'], -90),
    unlockDeviceLogic: _unlockLogicValue(json['unlockDeviceLogic']),
    lockDeviceLogic: _lockLogicValue(json['lockDeviceLogic']),
    wakeOnProximity: json['wakeOnProximity'] == true,
    enableMacAutoUnlock: json['enableMacAutoUnlock'] == true,
    rssiWindowSize: _intValue(json['rssiWindowSize'], 5),
  );
}

int _intValue(Object? value, int fallback) {
  return value is int ? value : fallback;
}

UnlockDeviceLogic _unlockLogicValue(Object? value) {
  for (final logic in UnlockDeviceLogic.values) {
    if (logic.name == value) {
      return logic;
    }
  }
  return UnlockDeviceLogic.anyClose;
}

LockDeviceLogic _lockLogicValue(Object? value) {
  for (final logic in LockDeviceLogic.values) {
    if (logic.name == value) {
      return logic;
    }
  }
  return LockDeviceLogic.allAway;
}
