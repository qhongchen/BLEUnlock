class BleScanEvent {
  const BleScanEvent({
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

enum SessionEventKind {
  locked,
  unlocked,
  displaySleep,
  displayWake,
  systemSleep,
  systemWake,
}

class SessionEvent {
  const SessionEvent({
    required this.kind,
    required this.timestamp,
    this.reason,
  });

  final SessionEventKind kind;
  final DateTime timestamp;
  final String? reason;
}

enum TrayStatus {
  normal,
  monitoring,
  locked,
  warning,
}

enum TrayActionKind {
  openSettings,
  startMonitoring,
  pauseMonitoring,
  lockNow,
  quit,
}

class TrayAction {
  const TrayAction({
    required this.kind,
    required this.timestamp,
  });

  final TrayActionKind kind;
  final DateTime timestamp;
}

class UnlockResult {
  const UnlockResult({
    required this.success,
    required this.reason,
  });

  final bool success;
  final String reason;
}
