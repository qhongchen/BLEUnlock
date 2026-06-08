import 'dart:convert';

import 'package:bleunlock_app/src/lock_sync/lock_sync_models.dart';
import 'package:bleunlock_core/bleunlock_core.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

class AppSettings {
  const AppSettings({
    required this.config,
    required this.selectedDeviceIds,
    this.lockSyncConfig = const LockSyncConfig(),
    this.windowsIdentityProfiles = const {},
  });

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final configJson = json['config'];
    final selectedIdsJson = json['selectedDeviceIds'];
    final lockSyncJson = json['lockSyncConfig'];
    final windowsProfilesJson = json['windowsIdentityProfiles'];

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
      windowsIdentityProfiles: windowsProfilesJson is Map
          ? _windowsIdentityProfilesFromJson(
              windowsProfilesJson.cast<String, Object?>(),
            )
          : const {},
    );
  }

  final ProximityConfig config;
  final Set<String> selectedDeviceIds;
  final LockSyncConfig lockSyncConfig;
  final Map<String, WindowsBleIdentityProfile> windowsIdentityProfiles;

  Map<String, Object?> toJson() {
    final sortedSelectedIds = selectedDeviceIds.toList()..sort();
    final sortedWindowsProfiles = Map.fromEntries(
      windowsIdentityProfiles.entries.toList()
        ..sort((left, right) => left.key.compareTo(right.key)),
    );
    return {
      'version': 2,
      'config': _configToJson(config),
      'selectedDeviceIds': sortedSelectedIds,
      if (!lockSyncConfig.isDefault) 'lockSyncConfig': lockSyncConfig.toJson(),
      if (sortedWindowsProfiles.isNotEmpty)
        'windowsIdentityProfiles': {
          for (final entry in sortedWindowsProfiles.entries)
            entry.key: entry.value.toJson(),
        },
    };
  }
}

class WindowsBleIdentityProfile {
  const WindowsBleIdentityProfile({
    required this.deviceId,
    this.displayName,
    this.addressHint,
    this.broadcastAddresses = const {},
    this.deviceInformationIds = const {},
    this.serviceUuids = const {},
    this.manufacturerCompanyIds = const {},
    this.manufacturerFingerprints = const {},
    this.lastSeenAt,
  });

  factory WindowsBleIdentityProfile.fromJson(Map<String, Object?> json) {
    final deviceId = _stringValue(json['deviceId']);
    return WindowsBleIdentityProfile(
      deviceId: deviceId ?? '',
      displayName: _stringValue(json['displayName']),
      addressHint: _stringValue(json['addressHint']),
      broadcastAddresses: _stringSet(json['broadcastAddresses']),
      deviceInformationIds: _stringSet(json['deviceInformationIds']),
      serviceUuids: _stringSet(json['serviceUuids']),
      manufacturerCompanyIds: _stringSet(json['manufacturerCompanyIds']),
      manufacturerFingerprints: _stringSet(json['manufacturerFingerprints']),
      lastSeenAt: _dateTimeValue(json['lastSeenAt']),
    );
  }

  final String deviceId;
  final String? displayName;
  final String? addressHint;
  final Set<String> broadcastAddresses;
  final Set<String> deviceInformationIds;
  final Set<String> serviceUuids;
  final Set<String> manufacturerCompanyIds;
  final Set<String> manufacturerFingerprints;
  final DateTime? lastSeenAt;

  Map<String, Object?> toJson() {
    return {
      'deviceId': deviceId,
      if (displayName != null) 'displayName': displayName,
      if (addressHint != null) 'addressHint': addressHint,
      if (broadcastAddresses.isNotEmpty)
        'broadcastAddresses': _sortedList(broadcastAddresses),
      if (deviceInformationIds.isNotEmpty)
        'deviceInformationIds': _sortedList(deviceInformationIds),
      if (serviceUuids.isNotEmpty) 'serviceUuids': _sortedList(serviceUuids),
      if (manufacturerCompanyIds.isNotEmpty)
        'manufacturerCompanyIds': _sortedList(manufacturerCompanyIds),
      if (manufacturerFingerprints.isNotEmpty)
        'manufacturerFingerprints': _sortedList(manufacturerFingerprints),
      if (lastSeenAt != null)
        'lastSeenAt': lastSeenAt!.toUtc().toIso8601String(),
    };
  }

  WindowsBleIdentityProfile merge({
    String? displayName,
    String? addressHint,
    Set<String> broadcastAddresses = const {},
    Set<String> deviceInformationIds = const {},
    Set<String> serviceUuids = const {},
    Set<String> manufacturerCompanyIds = const {},
    Set<String> manufacturerFingerprints = const {},
    DateTime? lastSeenAt,
  }) {
    return WindowsBleIdentityProfile(
      deviceId: deviceId,
      displayName: displayName ?? this.displayName,
      addressHint: addressHint ?? this.addressHint,
      broadcastAddresses: _boundedUnion(
        this.broadcastAddresses,
        broadcastAddresses,
      ),
      deviceInformationIds: _boundedUnion(
        this.deviceInformationIds,
        deviceInformationIds,
      ),
      serviceUuids: _boundedUnion(this.serviceUuids, serviceUuids),
      manufacturerCompanyIds: _boundedUnion(
        this.manufacturerCompanyIds,
        manufacturerCompanyIds,
      ),
      manufacturerFingerprints: _boundedUnion(
        this.manufacturerFingerprints,
        manufacturerFingerprints,
      ),
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
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

Map<String, WindowsBleIdentityProfile> _windowsIdentityProfilesFromJson(
  Map<String, Object?> json,
) {
  final profiles = <String, WindowsBleIdentityProfile>{};
  for (final entry in json.entries) {
    final value = entry.value;
    if (value is! Map) {
      continue;
    }
    final profile = WindowsBleIdentityProfile.fromJson(
      value.cast<String, Object?>(),
    );
    final deviceId = profile.deviceId.isEmpty ? entry.key : profile.deviceId;
    profiles[deviceId] = profile.deviceId.isEmpty
        ? WindowsBleIdentityProfile(
            deviceId: deviceId,
            displayName: profile.displayName,
            addressHint: profile.addressHint,
            broadcastAddresses: profile.broadcastAddresses,
            deviceInformationIds: profile.deviceInformationIds,
            serviceUuids: profile.serviceUuids,
            manufacturerCompanyIds: profile.manufacturerCompanyIds,
            manufacturerFingerprints: profile.manufacturerFingerprints,
            lastSeenAt: profile.lastSeenAt,
          )
        : profile;
  }
  return Map.unmodifiable(profiles);
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Set<String> _stringSet(Object? value) {
  if (value is! List) {
    return const {};
  }
  return value
      .whereType<String>()
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
}

DateTime? _dateTimeValue(Object? value) {
  final text = _stringValue(value);
  return text == null ? null : DateTime.tryParse(text);
}

List<String> _sortedList(Set<String> values) {
  return values.toList()..sort();
}

Set<String> _boundedUnion(
  Set<String> previous,
  Set<String> next, {
  int limit = 16,
}) {
  final values = <String>[...previous, ...next]
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();
  if (values.length <= limit) {
    return values.toSet();
  }
  return values.skip(values.length - limit).toSet();
}
