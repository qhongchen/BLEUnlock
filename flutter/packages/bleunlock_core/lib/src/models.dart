enum DevicePresenceState {
  close,
  away,
  lost,
}

enum UnlockDeviceLogic {
  anyClose,
  allClose,
}

enum LockDeviceLogic {
  allAway,
  anyAway,
}

class BleDevice {
  const BleDevice({
    required this.platformId,
    this.displayName,
    this.addressHint,
    this.lastRssi,
    this.lastSeenAt,
    this.manufacturerData,
    this.rawAdvertisement,
    this.isSelected = false,
  });

  final String platformId;
  final String? displayName;
  final String? addressHint;
  final int? lastRssi;
  final DateTime? lastSeenAt;
  final List<int>? manufacturerData;
  final Map<String, Object?>? rawAdvertisement;
  final bool isSelected;
}

class ProximityConfig {
  const ProximityConfig({
    this.unlockRssi = -60,
    this.lockRssi = -80,
    this.noSignalTimeout = const Duration(seconds: 60),
    this.lockDelay = const Duration(seconds: 5),
    this.minimumVisibleRssi = -90,
    this.unlockDeviceLogic = UnlockDeviceLogic.anyClose,
    this.lockDeviceLogic = LockDeviceLogic.allAway,
    this.wakeOnProximity = false,
    this.enableMacAutoUnlock = false,
    this.rssiWindowSize = 5,
  });

  final int unlockRssi;
  final int lockRssi;
  final Duration noSignalTimeout;
  final Duration lockDelay;
  final int minimumVisibleRssi;
  final UnlockDeviceLogic unlockDeviceLogic;
  final LockDeviceLogic lockDeviceLogic;
  final bool wakeOnProximity;
  final bool enableMacAutoUnlock;
  final int rssiWindowSize;

  ProximityConfig copyWith({
    int? unlockRssi,
    int? lockRssi,
    Duration? noSignalTimeout,
    Duration? lockDelay,
    int? minimumVisibleRssi,
    UnlockDeviceLogic? unlockDeviceLogic,
    LockDeviceLogic? lockDeviceLogic,
    bool? wakeOnProximity,
    bool? enableMacAutoUnlock,
    int? rssiWindowSize,
  }) {
    return ProximityConfig(
      unlockRssi: unlockRssi ?? this.unlockRssi,
      lockRssi: lockRssi ?? this.lockRssi,
      noSignalTimeout: noSignalTimeout ?? this.noSignalTimeout,
      lockDelay: lockDelay ?? this.lockDelay,
      minimumVisibleRssi: minimumVisibleRssi ?? this.minimumVisibleRssi,
      unlockDeviceLogic: unlockDeviceLogic ?? this.unlockDeviceLogic,
      lockDeviceLogic: lockDeviceLogic ?? this.lockDeviceLogic,
      wakeOnProximity: wakeOnProximity ?? this.wakeOnProximity,
      enableMacAutoUnlock: enableMacAutoUnlock ?? this.enableMacAutoUnlock,
      rssiWindowSize: rssiWindowSize ?? this.rssiWindowSize,
    );
  }
}

class BleScanSample {
  const BleScanSample({
    required this.deviceId,
    required this.rssi,
    required this.seenAt,
    this.displayName,
    this.addressHint,
    this.manufacturerData,
    this.rawAdvertisement,
  });

  final String deviceId;
  final int rssi;
  final DateTime seenAt;
  final String? displayName;
  final String? addressHint;
  final List<int>? manufacturerData;
  final Map<String, Object?>? rawAdvertisement;
}

class DevicePresence {
  const DevicePresence({
    required this.deviceId,
    required this.smoothedRssi,
    required this.state,
    required this.lastStateChangedAt,
    required this.reason,
  });

  final String deviceId;
  final int smoothedRssi;
  final DevicePresenceState state;
  final DateTime lastStateChangedAt;
  final String reason;
}

class PresenceDecision {
  const PresenceDecision({
    required this.shouldLock,
    required this.shouldWake,
    required this.shouldUnlock,
    required this.reason,
    required this.devices,
    required this.deviceStates,
    required this.timestamp,
  });

  final bool shouldLock;
  final bool shouldWake;
  final bool shouldUnlock;
  final String reason;
  final Map<String, BleDevice> devices;
  final Map<String, DevicePresence> deviceStates;
  final DateTime timestamp;
}
