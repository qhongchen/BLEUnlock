import 'dart:convert';
import 'dart:io';

import 'package:bleunlock_app/src/lock_sync/lock_sync_models.dart';
import 'package:bleunlock_core/bleunlock_core.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

class AppSettings {
  const AppSettings({
    required this.config,
    required this.selectedDeviceIds,
    this.lockSyncConfig = const LockSyncConfig(),
  });

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final configJson = json['config'];
    final selectedIdsJson = json['selectedDeviceIds'];
    final lockSyncJson = json['lockSyncConfig'];

    return AppSettings(
      config: configJson is Map
          ? _configFromJson(configJson.cast<String, Object?>())
          : const ProximityConfig(),
      selectedDeviceIds: selectedIdsJson is List
          ? selectedIdsJson.whereType<String>().toSet()
          : const {},
      lockSyncConfig: lockSyncJson is Map
          ? LockSyncConfig.fromJson(lockSyncJson.cast<String, Object?>())
          : const LockSyncConfig(),
    );
  }

  final ProximityConfig config;
  final Set<String> selectedDeviceIds;
  final LockSyncConfig lockSyncConfig;

  Map<String, Object?> toJson({bool includeLockSyncSharedSecret = true}) {
    final sortedSelectedIds = selectedDeviceIds.toList()..sort();
    final serializedLockSyncConfig = lockSyncConfig.copyWith(
      sharedSecret:
          includeLockSyncSharedSecret ? lockSyncConfig.sharedSecret : '',
    );
    return {
      'version': 2,
      'config': _configToJson(config),
      'selectedDeviceIds': sortedSelectedIds,
      if (!serializedLockSyncConfig.isDefault)
        'lockSyncConfig': lockSyncConfig.toJson(
          includeSharedSecret: includeLockSyncSharedSecret,
        ),
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

class FileAppSettingsRepository implements AppSettingsRepository {
  FileAppSettingsRepository({
    File? file,
    SecureStore? secureStore,
    String lockSyncSharedSecretKey = _defaultLockSyncSharedSecretKey,
  })  : _file = file ?? defaultSettingsFile(),
        _secureStore = secureStore,
        _lockSyncSharedSecretKey = lockSyncSharedSecretKey;

  static const String _defaultLockSyncSharedSecretKey = 'lockSyncSharedSecret';

  final File _file;
  final SecureStore? _secureStore;
  final String _lockSyncSharedSecretKey;

  static File defaultSettingsFile() {
    return File('${_defaultSettingsDirectory().path}/settings.json');
  }

  @override
  Future<AppSettings?> load() async {
    if (!await _file.exists()) {
      return null;
    }

    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map) {
        return null;
      }

      final settings = AppSettings.fromJson(decoded.cast<String, Object?>());
      final lockSyncConfig = await _hydrateLockSyncSharedSecret(
        settings.lockSyncConfig,
      );
      return AppSettings(
        config: settings.config,
        selectedDeviceIds: settings.selectedDeviceIds,
        lockSyncConfig: lockSyncConfig,
      );
    } on FormatException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _persistLockSyncSharedSecret(settings.lockSyncConfig);

    await _file.parent.create(recursive: true);
    await _file.writeAsString(
      jsonEncode(settings.toJson(includeLockSyncSharedSecret: false)),
    );
  }

  Future<LockSyncConfig> _hydrateLockSyncSharedSecret(
    LockSyncConfig config,
  ) async {
    if (!config.isEnabled || config.hasSharedSecret) {
      return config;
    }

    final secureStore = _secureStore;
    if (secureStore == null || !secureStore.capability.isUsable) {
      return config;
    }

    final sharedSecret = await secureStore.readSecret(
      _lockSyncSharedSecretKey,
    );
    if (sharedSecret == null || sharedSecret.trim().isEmpty) {
      return config;
    }

    return config.copyWith(sharedSecret: sharedSecret.trim());
  }

  Future<void> _persistLockSyncSharedSecret(LockSyncConfig config) async {
    final secureStore = _secureStore;
    if (secureStore == null || !secureStore.capability.isUsable) {
      return;
    }

    if (config.hasSharedSecret) {
      await secureStore.writeSecret(
        _lockSyncSharedSecretKey,
        config.sharedSecret.trim(),
      );
      return;
    }

    if (!config.isDefault) {
      await secureStore.deleteSecret(_lockSyncSharedSecretKey);
    }
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

Directory _defaultSettingsDirectory() {
  if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return Directory('$home/Library/Application Support/BLEUnlock');
    }
  }

  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.trim().isNotEmpty) {
      return Directory('$appData/BLEUnlock');
    }
  }

  final xdgConfigHome = Platform.environment['XDG_CONFIG_HOME'];
  if (xdgConfigHome != null && xdgConfigHome.trim().isNotEmpty) {
    return Directory('$xdgConfigHome/BLEUnlock');
  }

  final home = Platform.environment['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    return Directory('$home/.config/BLEUnlock');
  }

  return Directory('${Directory.systemTemp.path}/BLEUnlock');
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
