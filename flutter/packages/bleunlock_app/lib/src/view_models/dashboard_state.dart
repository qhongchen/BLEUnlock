import 'dart:convert';

import 'package:bleunlock_app/src/lock_sync/lock_sync_models.dart';
import 'package:bleunlock_core/bleunlock_core.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

const _windowsCredentialProviderMissingCapability =
    'credential provider component is not installed';

class DashboardSnapshot {
  const DashboardSnapshot({
    this.platformLabel = 'unknown',
    required this.monitoringStatus,
    required this.stateLabel,
    required this.bestRssi,
    required this.selectedDeviceCount,
    required this.lastActionLabel,
    required this.bluetoothCapabilityLabel,
    required this.autoLockCapabilityLabel,
    required this.wakeCapabilityLabel,
    required this.autoUnlockCapabilityLabel,
    required this.trayCapabilityLabel,
    required this.startupCapabilityLabel,
    required this.startupEnabled,
    required this.autoUnlockSecretConfigured,
    required this.autoUnlockSecretEditable,
    required this.autoUnlockPermissionSettingsAvailable,
  });

  const DashboardSnapshot.initial()
      : platformLabel = 'unknown',
        monitoringStatus = 'Monitoring paused',
        stateLabel = 'Idle',
        bestRssi = null,
        selectedDeviceCount = 0,
        lastActionLabel = 'None',
        bluetoothCapabilityLabel = 'Pending plugin',
        autoLockCapabilityLabel = 'Pending plugin',
        wakeCapabilityLabel = 'Pending plugin',
        autoUnlockCapabilityLabel = 'unsupported',
        trayCapabilityLabel = 'Pending plugin',
        startupCapabilityLabel = 'Pending plugin',
        startupEnabled = false,
        autoUnlockSecretConfigured = false,
        autoUnlockSecretEditable = false,
        autoUnlockPermissionSettingsAvailable = false;

  final String platformLabel;
  final String monitoringStatus;
  final String stateLabel;
  final int? bestRssi;
  final int selectedDeviceCount;
  final String lastActionLabel;
  final String bluetoothCapabilityLabel;
  final String autoLockCapabilityLabel;
  final String wakeCapabilityLabel;
  final String autoUnlockCapabilityLabel;
  final String trayCapabilityLabel;
  final String startupCapabilityLabel;
  final bool startupEnabled;
  final bool autoUnlockSecretConfigured;
  final bool autoUnlockSecretEditable;
  final bool autoUnlockPermissionSettingsAvailable;

  String get bestRssiLabel => bestRssi == null ? '-- dBm' : '$bestRssi dBm';

  String get selectedDevicesLabel => selectedDeviceCount.toString();

  String get startupEnabledLabel => startupEnabled ? 'enabled' : 'disabled';

  String get autoUnlockSecretLabel =>
      autoUnlockSecretConfigured ? 'configured' : 'missing';

  bool get isWindowsPlatform => _isWindowsPlatformLabel(platformLabel);

  bool get isWindowsV1AutoUnlockUnsupported {
    return isWindowsPlatform &&
        _isUnsupportedCapabilityLabel(autoUnlockCapabilityLabel);
  }

  bool get isWindowsCredentialProviderReady {
    return isWindowsPlatform &&
        _isSupportedCapabilityLabel(autoUnlockCapabilityLabel);
  }

  bool get isWindowsCredentialProviderMissing {
    return isWindowsPlatform &&
        _isWindowsCredentialProviderMissing(autoUnlockCapabilityLabel);
  }

  String? get windowsV1ReadinessLabel {
    if (!isWindowsPlatform) {
      return null;
    }
    return _windowsCredentialProviderReadinessLabel(
      autoUnlockCapabilityLabel,
    );
  }

  Map<String, Object?> toDiagnosticJson() {
    return {
      'platformLabel': platformLabel,
      'monitoringStatus': monitoringStatus,
      'stateLabel': stateLabel,
      if (bestRssi != null) 'bestRssi': bestRssi,
      'selectedDeviceCount': selectedDeviceCount,
      'lastActionLabel': lastActionLabel,
      'bluetoothCapabilityLabel': bluetoothCapabilityLabel,
      'autoLockCapabilityLabel': autoLockCapabilityLabel,
      'wakeCapabilityLabel': wakeCapabilityLabel,
      'autoUnlockCapabilityLabel': autoUnlockCapabilityLabel,
      'trayCapabilityLabel': trayCapabilityLabel,
      'startupCapabilityLabel': startupCapabilityLabel,
      'startupEnabled': startupEnabled,
      'autoUnlockSecretConfigured': autoUnlockSecretConfigured,
      'autoUnlockSecretEditable': autoUnlockSecretEditable,
      'autoUnlockPermissionSettingsAvailable':
          autoUnlockPermissionSettingsAvailable,
      'isWindowsCredentialProviderReady': isWindowsCredentialProviderReady,
      'isWindowsCredentialProviderMissing': isWindowsCredentialProviderMissing,
      if (windowsV1ReadinessLabel != null)
        'windowsV1ReadinessLabel': windowsV1ReadinessLabel,
    };
  }
}

class DashboardDeviceView {
  const DashboardDeviceView({
    required this.id,
    required this.idLabel,
    required this.name,
    required this.rssiLabel,
    required this.lastSeenLabel,
    required this.presenceLabel,
    required this.isSelected,
  });

  factory DashboardDeviceView.fromDevice({
    required BleDevice device,
    required DevicePresence? presence,
  }) {
    final displayName = _normalizedText(device.displayName);
    final addressHint = _normalizedText(device.addressHint);
    final broadcastAddressLabel =
        _windowsBroadcastAddressLabel(device.rawAdvertisement);
    return DashboardDeviceView(
      id: device.platformId,
      idLabel:
          broadcastAddressLabel ?? 'ID ${_shortPlatformId(device.platformId)}',
      name: displayName ?? addressHint ?? _shortPlatformId(device.platformId),
      rssiLabel: _rssiLabel(device),
      lastSeenLabel: 'Last seen ${_timeLabel(device.lastSeenAt)}',
      presenceLabel: _presenceLabel(presence?.state),
      isSelected: device.isSelected,
    );
  }

  final String id;
  final String idLabel;
  final String name;
  final String rssiLabel;
  final String lastSeenLabel;
  final String presenceLabel;
  final bool isSelected;

  Map<String, Object?> toDiagnosticJson() {
    return {
      'id': id,
      'idLabel': idLabel,
      'name': name,
      'rssiLabel': rssiLabel,
      'lastSeenLabel': lastSeenLabel,
      'presenceLabel': presenceLabel,
      'isSelected': isSelected,
    };
  }
}

enum DashboardLogCategory {
  scan,
  decision,
  action,
  error,
}

enum DashboardLogLevel {
  info,
  error,
}

enum DashboardSessionState {
  unlocked,
  locked,
  displaySleep,
  displayWake,
  systemSleep,
  systemWake,
}

extension DashboardLogCategoryLabel on DashboardLogCategory {
  String get label {
    switch (this) {
      case DashboardLogCategory.scan:
        return 'scan';
      case DashboardLogCategory.decision:
        return 'decision';
      case DashboardLogCategory.action:
        return 'action';
      case DashboardLogCategory.error:
        return 'error';
    }
  }
}

extension DashboardLogLevelLabel on DashboardLogLevel {
  String get label {
    switch (this) {
      case DashboardLogLevel.info:
        return 'info';
      case DashboardLogLevel.error:
        return 'error';
    }
  }
}

extension DashboardSessionStateLabel on DashboardSessionState {
  String get label {
    switch (this) {
      case DashboardSessionState.unlocked:
        return 'unlocked';
      case DashboardSessionState.locked:
        return 'locked';
      case DashboardSessionState.displaySleep:
        return 'displaySleep';
      case DashboardSessionState.displayWake:
        return 'displayWake';
      case DashboardSessionState.systemSleep:
        return 'systemSleep';
      case DashboardSessionState.systemWake:
        return 'systemWake';
    }
  }

  bool get isLockedLike {
    switch (this) {
      case DashboardSessionState.locked:
      case DashboardSessionState.displaySleep:
      case DashboardSessionState.systemSleep:
        return true;
      case DashboardSessionState.unlocked:
      case DashboardSessionState.displayWake:
      case DashboardSessionState.systemWake:
        return false;
    }
  }
}

class DashboardLogEntry {
  const DashboardLogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
    this.platform = 'app',
    this.displayName,
    this.addressHint,
    this.deviceId,
    this.rssi,
    this.reason,
    this.manufacturerData,
    this.rawAdvertisement,
    this.sessionState,
  });

  final DateTime timestamp;
  final DashboardLogCategory category;
  final String message;
  final String platform;
  final String? displayName;
  final String? addressHint;
  final String? deviceId;
  final int? rssi;
  final String? reason;
  final List<int>? manufacturerData;
  final Map<String, Object?>? rawAdvertisement;
  final DashboardSessionState? sessionState;

  DashboardLogLevel get level {
    switch (category) {
      case DashboardLogCategory.error:
        return DashboardLogLevel.error;
      case DashboardLogCategory.scan:
      case DashboardLogCategory.decision:
      case DashboardLogCategory.action:
        return DashboardLogLevel.info;
    }
  }

  String get timeLabel {
    return _timeLabel(timestamp);
  }

  String get detailLabel {
    return [
      'level=${level.label}',
      'platform=$platform',
      if (displayName != null) 'name=$displayName',
      if (addressHint != null) 'address=$addressHint',
      if (deviceId != null) 'device=$deviceId',
      if (rssi != null) 'rssi=$rssi',
      if (reason != null) 'reason=$reason',
      if (sessionState != null) 'session=${sessionState!.label}',
    ].join(' ');
  }

  Map<String, Object?> toDiagnosticJson() {
    return {
      'timestamp': timestamp.toUtc().toIso8601String(),
      'level': level.label,
      'category': category.label,
      'platform': platform,
      'message': message,
      if (displayName != null) 'displayName': displayName,
      if (addressHint != null) 'addressHint': addressHint,
      if (deviceId != null) 'deviceId': deviceId,
      if (rssi != null) 'rssi': rssi,
      if (reason != null) 'reason': reason,
      if (sessionState != null) 'sessionState': sessionState!.label,
      if (manufacturerDataHex != null)
        'manufacturerDataHex': manufacturerDataHex,
      if (rawAdvertisement != null) 'rawAdvertisement': rawAdvertisement,
    };
  }

  String? get manufacturerDataHex {
    final bytes = manufacturerData;
    if (bytes == null) {
      return null;
    }
    return _bytesToHex(bytes);
  }

  String get diagnosticJsonLine => jsonEncode(toDiagnosticJson());
}

class DashboardLogFilter {
  const DashboardLogFilter({
    this.category,
    this.level,
    this.sessionState,
    this.includeLowValueDiagnostics = false,
    this.query = '',
  });

  final DashboardLogCategory? category;
  final DashboardLogLevel? level;
  final DashboardSessionState? sessionState;
  final bool includeLowValueDiagnostics;
  final String query;

  List<DashboardLogEntry> apply(Iterable<DashboardLogEntry> logs) {
    return logs.where(matches).toList(growable: false);
  }

  bool matches(DashboardLogEntry entry) {
    if (category != null && entry.category != category) {
      return false;
    }
    if (level != null && entry.level != level) {
      return false;
    }
    if (sessionState != null && entry.sessionState != sessionState) {
      return false;
    }
    if (!includeLowValueDiagnostics && _isLowValueDiagnostic(entry)) {
      return false;
    }

    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return true;
    }

    return _searchableText(entry).contains(normalizedQuery);
  }

  bool _isLowValueDiagnostic(DashboardLogEntry entry) {
    return entry.category == DashboardLogCategory.decision &&
        (entry.reason == 'belowVisibleThreshold' ||
            entry.reason == 'unmonitored');
  }

  String _searchableText(DashboardLogEntry entry) {
    return [
      entry.message,
      entry.platform,
      entry.category.label,
      entry.level.label,
      if (entry.displayName != null) entry.displayName,
      if (entry.addressHint != null) entry.addressHint,
      if (entry.deviceId != null) entry.deviceId,
      if (entry.rssi != null) entry.rssi.toString(),
      if (entry.reason != null) entry.reason,
      if (entry.sessionState != null) entry.sessionState!.label,
      if (entry.manufacturerDataHex != null) entry.manufacturerDataHex,
      if (entry.rawAdvertisement != null) jsonEncode(entry.rawAdvertisement),
    ].join(' ').toLowerCase();
  }
}

class DashboardSessionDiagnostic {
  const DashboardSessionDiagnostic({
    required this.sessionState,
    required this.logCount,
    required this.scanCount,
    required this.latestEventAt,
    required this.latestScanAt,
    required this.latestScanRssi,
    required this.latestScanDeviceId,
  });

  final DashboardSessionState sessionState;
  final int logCount;
  final int scanCount;
  final DateTime latestEventAt;
  final DateTime? latestScanAt;
  final int? latestScanRssi;
  final String? latestScanDeviceId;

  static List<DashboardSessionDiagnostic> fromLogs(
    Iterable<DashboardLogEntry> logs,
  ) {
    final groups = <DashboardSessionState, _SessionDiagnosticAccumulator>{};
    for (final entry in logs) {
      final sessionState = entry.sessionState;
      if (sessionState == null) {
        continue;
      }
      groups
          .putIfAbsent(
            sessionState,
            () => _SessionDiagnosticAccumulator(sessionState),
          )
          .add(entry);
    }

    return groups.values.map((group) => group.build()).toList()
      ..sort(
        (left, right) => left.sessionState.index.compareTo(
          right.sessionState.index,
        ),
      );
  }

  String get sessionLabel => sessionState.label;

  String get logCountLabel => 'logs $logCount';

  String get scanCountLabel => 'scans $scanCount';

  String get latestEventLabel => 'latest event ${_timeLabel(latestEventAt)}';

  String get latestScanLabel {
    return latestScanAt == null
        ? 'latest scan --'
        : 'latest scan ${_timeLabel(latestScanAt)}';
  }

  String get latestScanRssiLabel {
    return latestScanRssi == null ? '-- dBm' : '$latestScanRssi dBm';
  }

  String get latestScanDeviceLabel {
    final deviceId = latestScanDeviceId;
    return deviceId == null
        ? 'device --'
        : 'device ${_shortPlatformId(deviceId)}';
  }

  String get scanEvidenceLabel {
    return scanCount == 0 ? 'No scan events' : 'BLE scan observed';
  }

  Map<String, Object?> toDiagnosticJson() {
    return {
      'sessionState': sessionState.label,
      'logCount': logCount,
      'scanCount': scanCount,
      'scanObserved': scanCount > 0,
      'latestEventAt': latestEventAt.toUtc().toIso8601String(),
      if (latestScanAt != null)
        'latestScanAt': latestScanAt!.toUtc().toIso8601String(),
      if (latestScanRssi != null) 'latestScanRssi': latestScanRssi,
      if (latestScanDeviceId != null) 'latestScanDeviceId': latestScanDeviceId,
    };
  }

  String get diagnosticJsonLine => jsonEncode(toDiagnosticJson());
}

class _SessionDiagnosticAccumulator {
  _SessionDiagnosticAccumulator(this.sessionState);

  final DashboardSessionState sessionState;
  int logCount = 0;
  int scanCount = 0;
  DateTime? latestEventAt;
  DateTime? latestScanAt;
  int? latestScanRssi;
  String? latestScanDeviceId;

  void add(DashboardLogEntry entry) {
    logCount += 1;
    if (latestEventAt == null || entry.timestamp.isAfter(latestEventAt!)) {
      latestEventAt = entry.timestamp;
    }

    if (entry.category != DashboardLogCategory.scan) {
      return;
    }

    scanCount += 1;
    if (latestScanAt == null || entry.timestamp.isAfter(latestScanAt!)) {
      latestScanAt = entry.timestamp;
      latestScanRssi = entry.rssi;
      latestScanDeviceId = entry.deviceId;
    }
  }

  DashboardSessionDiagnostic build() {
    return DashboardSessionDiagnostic(
      sessionState: sessionState,
      logCount: logCount,
      scanCount: scanCount,
      latestEventAt: latestEventAt!,
      latestScanAt: latestScanAt,
      latestScanRssi: latestScanRssi,
      latestScanDeviceId: latestScanDeviceId,
    );
  }
}

enum DeviceIdentityStatus {
  stable,
  changed,
}

extension DeviceIdentityStatusLabel on DeviceIdentityStatus {
  String get label {
    switch (this) {
      case DeviceIdentityStatus.stable:
        return 'Stable identity';
      case DeviceIdentityStatus.changed:
        return 'Identity changed';
    }
  }
}

class DashboardDeviceDiagnostic {
  const DashboardDeviceDiagnostic({
    required this.deviceId,
    required this.seenCount,
    required this.latestRssi,
    required this.averageRssi,
    required this.minRssi,
    required this.maxRssi,
    required this.averageInterval,
    required this.longestSilence,
    required this.lastSeenAt,
    required this.displayName,
    required this.addressHint,
    required this.manufacturerDataHex,
    required this.identityStatus,
  });

  final String deviceId;
  final int seenCount;
  final int? latestRssi;
  final int? averageRssi;
  final int? minRssi;
  final int? maxRssi;
  final Duration? averageInterval;
  final Duration? longestSilence;
  final DateTime lastSeenAt;
  final String? displayName;
  final String? addressHint;
  final String? manufacturerDataHex;
  final DeviceIdentityStatus identityStatus;

  static List<DashboardDeviceDiagnostic> fromLogs(
    Iterable<DashboardLogEntry> logs,
  ) {
    final groups = <String, _DeviceDiagnosticAccumulator>{};
    for (final entry in logs) {
      final deviceId = entry.deviceId;
      if (entry.category != DashboardLogCategory.scan || deviceId == null) {
        continue;
      }
      groups
          .putIfAbsent(deviceId, () => _DeviceDiagnosticAccumulator(deviceId))
          .add(entry);
    }

    return groups.values.map((group) => group.build()).toList()
      ..sort((left, right) => right.lastSeenAt.compareTo(left.lastSeenAt));
  }

  String get latestRssiLabel =>
      latestRssi == null ? '-- dBm' : '$latestRssi dBm';

  String get averageRssiLabel =>
      averageRssi == null ? '-- dBm avg' : '$averageRssi dBm avg';

  String get rssiRangeLabel {
    if (minRssi == null || maxRssi == null) {
      return '-- dBm';
    }
    if (minRssi == maxRssi) {
      return '$minRssi dBm';
    }
    return '$minRssi to $maxRssi dBm';
  }

  String get averageIntervalLabel {
    return 'avg interval ${_durationLabel(averageInterval)}';
  }

  String get longestSilenceLabel {
    return 'longest silence ${_durationLabel(longestSilence)}';
  }

  String get lastSeenLabel => 'Last seen ${_timeLabel(lastSeenAt)}';

  String get displayNameLabel => displayName ?? 'Unknown device';

  String get addressHintLabel => addressHint ?? 'No address hint';

  String get manufacturerDataHexLabel => manufacturerDataHex ?? 'No data';

  String get identityStatusLabel => identityStatus.label;

  Map<String, Object?> toDiagnosticJson() {
    return {
      'deviceId': deviceId,
      'seenCount': seenCount,
      if (latestRssi != null) 'latestRssi': latestRssi,
      if (averageRssi != null) 'averageRssi': averageRssi,
      if (minRssi != null) 'minRssi': minRssi,
      if (maxRssi != null) 'maxRssi': maxRssi,
      if (averageInterval != null)
        'averageIntervalMilliseconds': averageInterval!.inMilliseconds,
      if (longestSilence != null)
        'longestSilenceMilliseconds': longestSilence!.inMilliseconds,
      'lastSeenAt': lastSeenAt.toUtc().toIso8601String(),
      if (displayName != null) 'displayName': displayName,
      if (addressHint != null) 'addressHint': addressHint,
      if (manufacturerDataHex != null)
        'manufacturerDataHex': manufacturerDataHex,
      'identityStatus': identityStatus.label,
    };
  }
}

class _DeviceDiagnosticAccumulator {
  _DeviceDiagnosticAccumulator(this.deviceId);

  final String deviceId;
  final Set<String> _displayNames = {};
  final Set<String> _addressHints = {};
  final Set<String> _manufacturerData = {};
  int seenCount = 0;
  int? latestRssi;
  int _rssiTotal = 0;
  int _rssiCount = 0;
  int? minRssi;
  int? maxRssi;
  int _gapTotalMilliseconds = 0;
  int _gapCount = 0;
  Duration? longestSilence;
  DateTime? lastSeenAt;
  String? displayName;
  String? addressHint;
  String? manufacturerDataHex;

  void add(DashboardLogEntry entry) {
    final previousSeenAt = lastSeenAt;
    seenCount += 1;
    _addVariant(_displayNames, entry.displayName);
    _addVariant(_addressHints, entry.addressHint);
    _addVariant(_manufacturerData, entry.manufacturerDataHex);
    final rssi = entry.rssi;
    if (rssi != null) {
      _rssiTotal += rssi;
      _rssiCount += 1;
      minRssi = minRssi == null || rssi < minRssi! ? rssi : minRssi;
      maxRssi = maxRssi == null || rssi > maxRssi! ? rssi : maxRssi;
    }
    if (previousSeenAt != null) {
      final gap = entry.timestamp.difference(previousSeenAt).abs();
      _gapTotalMilliseconds += gap.inMilliseconds;
      _gapCount += 1;
      longestSilence = longestSilence == null || gap > longestSilence!
          ? gap
          : longestSilence;
    }
    if (lastSeenAt == null || entry.timestamp.isAfter(lastSeenAt!)) {
      lastSeenAt = entry.timestamp;
      latestRssi = entry.rssi;
      displayName = entry.displayName ?? displayName;
      addressHint = entry.addressHint ?? addressHint;
      manufacturerDataHex = entry.manufacturerDataHex ?? manufacturerDataHex;
    }
  }

  DashboardDeviceDiagnostic build() {
    return DashboardDeviceDiagnostic(
      deviceId: deviceId,
      seenCount: seenCount,
      latestRssi: latestRssi,
      averageRssi: _rssiCount == 0 ? null : (_rssiTotal / _rssiCount).round(),
      minRssi: minRssi,
      maxRssi: maxRssi,
      averageInterval: _gapCount == 0
          ? null
          : Duration(
              milliseconds: (_gapTotalMilliseconds / _gapCount).round(),
            ),
      longestSilence: longestSilence,
      lastSeenAt: lastSeenAt!,
      displayName: displayName,
      addressHint: addressHint,
      manufacturerDataHex: manufacturerDataHex,
      identityStatus: _hasIdentityChanges
          ? DeviceIdentityStatus.changed
          : DeviceIdentityStatus.stable,
    );
  }

  bool get _hasIdentityChanges {
    return _displayNames.length > 1 ||
        _addressHints.length > 1 ||
        _manufacturerData.length > 1;
  }

  void _addVariant(Set<String> variants, String? value) {
    final normalized = value?.trim();
    if (normalized != null && normalized.isNotEmpty) {
      variants.add(normalized);
    }
  }
}

String _bytesToHex(List<int> bytes) {
  return bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join();
}

class AcceptanceBundleEnvironment {
  const AcceptanceBundleEnvironment({
    required this.exportSource,
    required this.platform,
    required this.buildMode,
    this.operatingSystemVersion,
    this.dartVersion,
  });

  const AcceptanceBundleEnvironment.unknown()
      : exportSource = 'dashboardState',
        platform = 'unknown',
        buildMode = 'unknown',
        operatingSystemVersion = null,
        dartVersion = null;

  final String exportSource;
  final String platform;
  final String buildMode;
  final String? operatingSystemVersion;
  final String? dartVersion;

  Map<String, Object?> toDiagnosticJson() {
    return {
      'exportSource': exportSource,
      'platform': platform,
      'buildMode': buildMode,
      if (operatingSystemVersion != null)
        'operatingSystemVersion': operatingSystemVersion,
      if (dartVersion != null) 'dartVersion': dartVersion,
    };
  }
}

class AcceptanceSummary {
  const AcceptanceSummary({
    required List<DashboardLogEntry> visibleLogs,
    required this.visibleLogCount,
    required this.deviceCount,
    required this.selectedDeviceCount,
    required this.hasScanEvidence,
    required this.hasLockedSessionScanEvidence,
    required this.hasDecisionEvidence,
    required this.hasActionEvidence,
    required this.hasAutoLockEvidence,
    required this.hasWakeEvidence,
    required this.hasAutoUnlockEvidence,
    required this.hasTrayActionEvidence,
    required this.hasTrayOpenSettingsEvidence,
    required this.hasTrayStartMonitoringEvidence,
    required this.hasTrayPauseMonitoringEvidence,
    required this.hasTrayLockNowEvidence,
    required this.hasTrayQuitEvidence,
    required this.hasStartupActionEvidence,
    required this.hasStartupEnableEvidence,
    required this.hasStartupDisableEvidence,
    required this.hasErrorEvidence,
    required this.observedSessionStates,
    required this.observedDeviceIds,
    required this.platformLabel,
    required this.autoUnlockCapabilityLabel,
  }) : _visibleLogs = visibleLogs;

  factory AcceptanceSummary.fromState({
    required DashboardState state,
    required Iterable<DashboardLogEntry> visibleLogs,
  }) {
    final logs = visibleLogs.toList(growable: false);
    final observedSessionStates = logs
        .map((entry) => entry.sessionState)
        .whereType<DashboardSessionState>()
        .map((state) => state.label)
        .toSet()
        .toList()
      ..sort();
    final observedDeviceIds = logs
        .map((entry) => entry.deviceId)
        .whereType<String>()
        .where((deviceId) => deviceId.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return AcceptanceSummary(
      visibleLogs: logs,
      visibleLogCount: logs.length,
      deviceCount: state.devices.length,
      selectedDeviceCount:
          state.devices.where((device) => device.isSelected).length,
      hasScanEvidence: logs.any(
        (entry) => entry.category == DashboardLogCategory.scan,
      ),
      hasLockedSessionScanEvidence: logs.any(
        (entry) =>
            entry.category == DashboardLogCategory.scan &&
            entry.sessionState?.isLockedLike == true,
      ),
      hasDecisionEvidence: logs.any(
        (entry) => entry.category == DashboardLogCategory.decision,
      ),
      hasActionEvidence: logs.any(
        (entry) => entry.category == DashboardLogCategory.action,
      ),
      hasAutoLockEvidence: logs.any(_isAutoLockEvidence),
      hasWakeEvidence: logs.any(_isWakeEvidence),
      hasAutoUnlockEvidence: logs.any(_isAutoUnlockEvidence),
      hasTrayActionEvidence: logs.any(_isTrayActionEvidence),
      hasTrayOpenSettingsEvidence: logs.any(_isTrayOpenSettingsEvidence),
      hasTrayStartMonitoringEvidence: logs.any(_isTrayStartMonitoringEvidence),
      hasTrayPauseMonitoringEvidence: logs.any(_isTrayPauseMonitoringEvidence),
      hasTrayLockNowEvidence: logs.any(_isTrayLockNowEvidence),
      hasTrayQuitEvidence: logs.any(_isTrayQuitEvidence),
      hasStartupActionEvidence: logs.any(_isStartupActionEvidence),
      hasStartupEnableEvidence: logs.any(_isStartupEnableEvidence),
      hasStartupDisableEvidence: logs.any(_isStartupDisableEvidence),
      hasErrorEvidence: logs.any(
        (entry) => entry.category == DashboardLogCategory.error,
      ),
      observedSessionStates: observedSessionStates,
      observedDeviceIds: observedDeviceIds,
      platformLabel: state.snapshot.platformLabel,
      autoUnlockCapabilityLabel: state.snapshot.autoUnlockCapabilityLabel,
    );
  }

  final int visibleLogCount;
  final int deviceCount;
  final int selectedDeviceCount;
  final bool hasScanEvidence;
  final bool hasLockedSessionScanEvidence;
  final bool hasDecisionEvidence;
  final bool hasActionEvidence;
  final bool hasAutoLockEvidence;
  final bool hasWakeEvidence;
  final bool hasAutoUnlockEvidence;
  final bool hasTrayActionEvidence;
  final bool hasTrayOpenSettingsEvidence;
  final bool hasTrayStartMonitoringEvidence;
  final bool hasTrayPauseMonitoringEvidence;
  final bool hasTrayLockNowEvidence;
  final bool hasTrayQuitEvidence;
  final bool hasStartupActionEvidence;
  final bool hasStartupEnableEvidence;
  final bool hasStartupDisableEvidence;
  final bool hasErrorEvidence;
  final List<String> observedSessionStates;
  final List<String> observedDeviceIds;
  final String platformLabel;
  final String autoUnlockCapabilityLabel;
  final List<DashboardLogEntry> _visibleLogs;

  bool get isWindowsPlatform => _isWindowsPlatformLabel(platformLabel);

  bool get isWindowsV1AutoUnlockUnsupported {
    return isWindowsPlatform &&
        _isUnsupportedCapabilityLabel(autoUnlockCapabilityLabel);
  }

  bool get isWindowsCredentialProviderReady {
    return isWindowsPlatform &&
        _isSupportedCapabilityLabel(autoUnlockCapabilityLabel);
  }

  bool get isWindowsCredentialProviderMissing {
    return isWindowsPlatform &&
        _isWindowsCredentialProviderMissing(autoUnlockCapabilityLabel);
  }

  String? get windowsV1ReadinessLabel {
    if (!isWindowsPlatform) {
      return null;
    }
    return _windowsCredentialProviderReadinessLabel(
      autoUnlockCapabilityLabel,
    );
  }

  Map<String, Object?> toDiagnosticJson() {
    return {
      'visibleLogCount': visibleLogCount,
      'deviceCount': deviceCount,
      'selectedDeviceCount': selectedDeviceCount,
      'hasScanEvidence': hasScanEvidence,
      'hasLockedSessionScanEvidence': hasLockedSessionScanEvidence,
      'hasDecisionEvidence': hasDecisionEvidence,
      'hasActionEvidence': hasActionEvidence,
      'hasAutoLockEvidence': hasAutoLockEvidence,
      'hasWakeEvidence': hasWakeEvidence,
      'hasAutoUnlockEvidence': hasAutoUnlockEvidence,
      'hasTrayActionEvidence': hasTrayActionEvidence,
      'hasTrayOpenSettingsEvidence': hasTrayOpenSettingsEvidence,
      'hasTrayStartMonitoringEvidence': hasTrayStartMonitoringEvidence,
      'hasTrayPauseMonitoringEvidence': hasTrayPauseMonitoringEvidence,
      'hasTrayLockNowEvidence': hasTrayLockNowEvidence,
      'hasTrayQuitEvidence': hasTrayQuitEvidence,
      'hasStartupActionEvidence': hasStartupActionEvidence,
      'hasStartupEnableEvidence': hasStartupEnableEvidence,
      'hasStartupDisableEvidence': hasStartupDisableEvidence,
      'hasErrorEvidence': hasErrorEvidence,
      'observedSessionStates': observedSessionStates,
      'observedDeviceIds': observedDeviceIds,
      'platformLabel': platformLabel,
      'autoUnlockCapabilityLabel': autoUnlockCapabilityLabel,
      'isWindowsV1AutoUnlockUnsupported': isWindowsV1AutoUnlockUnsupported,
      'isWindowsCredentialProviderReady': isWindowsCredentialProviderReady,
      'isWindowsCredentialProviderMissing': isWindowsCredentialProviderMissing,
      if (windowsV1ReadinessLabel != null)
        'windowsV1ReadinessLabel': windowsV1ReadinessLabel,
      'requiredChecklistCount': requiredChecklistCount,
      'completedRequiredChecklistCount': completedRequiredChecklistCount,
      'missingRequiredEvidenceCount': missingRequiredEvidenceCount,
      'readyForAcceptance': readyForAcceptance,
      'missingRequiredChecklistLabels': missingRequiredChecklistLabels,
      'checklist': checklistMap,
      'checklistItems':
          checklistItems.map((item) => item.toDiagnosticJson()).toList(),
      'validationSteps':
          validationSteps.map((step) => step.toDiagnosticJson()).toList(),
      'runbookSteps':
          runbookSteps.map((step) => step.toDiagnosticJson()).toList(),
      'missingRunbookSteps':
          missingRunbookSteps.map((step) => step.toDiagnosticJson()).toList(),
    };
  }

  List<AcceptanceChecklistItem> get checklistItems {
    final isAutoUnlockUnsupported =
        _isUnsupportedCapabilityLabel(autoUnlockCapabilityLabel);
    final requiresMacAutoUnlockEvidence =
        !isWindowsPlatform && !isAutoUnlockUnsupported;
    final items = [
      AcceptanceChecklistItem(
        id: 'realBleScan',
        label: 'Real BLE scan',
        status: _evidenceLabel(hasScanEvidence),
        required: true,
        evidence: _evidenceFor(
          (entry) => entry.category == DashboardLogCategory.scan,
        ),
      ),
      AcceptanceChecklistItem(
        id: 'lockedSessionScan',
        label: 'Locked-session BLE scan',
        status: _evidenceLabel(hasLockedSessionScanEvidence),
        required: true,
        evidence: _evidenceFor(
          (entry) =>
              entry.category == DashboardLogCategory.scan &&
              entry.sessionState?.isLockedLike == true,
        ),
      ),
      AcceptanceChecklistItem(
        id: 'proximityDecision',
        label: 'Proximity decision',
        status: _evidenceLabel(hasDecisionEvidence),
        required: true,
        evidence: _evidenceFor(
          (entry) => entry.category == DashboardLogCategory.decision,
        ),
      ),
      AcceptanceChecklistItem(
        id: 'autoLockAction',
        label: 'Auto lock action',
        status: _evidenceLabel(hasAutoLockEvidence),
        required: true,
        evidence: _evidenceFor(_isAutoLockEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'wakeAction',
        label: 'Wake action',
        status: _evidenceLabel(hasWakeEvidence),
        required: true,
        evidence: _evidenceFor(_isWakeEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'macAutoUnlockAction',
        label: 'macOS auto unlock action',
        status: isWindowsPlatform
            ? 'not required'
            : isAutoUnlockUnsupported
                ? 'unsupported'
                : _evidenceLabel(hasAutoUnlockEvidence),
        required: requiresMacAutoUnlockEvidence,
        evidence: _evidenceFor(_isAutoUnlockEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'trayAction',
        label: 'Tray/menu action',
        status: _evidenceLabel(hasTrayActionEvidence),
        required: true,
        evidence: _evidenceFor(_isTrayActionEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'trayOpenSettingsAction',
        label: 'Tray open settings',
        status: _evidenceLabel(hasTrayOpenSettingsEvidence),
        required: true,
        evidence: _evidenceFor(_isTrayOpenSettingsEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'trayStartMonitoringAction',
        label: 'Tray start monitoring',
        status: _evidenceLabel(hasTrayStartMonitoringEvidence),
        required: true,
        evidence: _evidenceFor(_isTrayStartMonitoringEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'trayPauseMonitoringAction',
        label: 'Tray pause monitoring',
        status: _evidenceLabel(hasTrayPauseMonitoringEvidence),
        required: true,
        evidence: _evidenceFor(_isTrayPauseMonitoringEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'trayLockNowAction',
        label: 'Tray lock now',
        status: _evidenceLabel(hasTrayLockNowEvidence),
        required: true,
        evidence: _evidenceFor(_isTrayLockNowEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'trayQuitAction',
        label: 'Tray quit',
        status: _evidenceLabel(hasTrayQuitEvidence),
        required: true,
        evidence: _evidenceFor(_isTrayQuitEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'startupAction',
        label: 'Startup action',
        status: _evidenceLabel(hasStartupActionEvidence),
        required: true,
        evidence: _evidenceFor(_isStartupActionEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'startupEnableAction',
        label: 'Startup enable',
        status: _evidenceLabel(hasStartupEnableEvidence),
        required: true,
        evidence: _evidenceFor(_isStartupEnableEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'startupDisableAction',
        label: 'Startup disable',
        status: _evidenceLabel(hasStartupDisableEvidence),
        required: true,
        evidence: _evidenceFor(_isStartupDisableEvidence),
      ),
      AcceptanceChecklistItem(
        id: 'errors',
        label: 'Errors',
        status: hasErrorEvidence ? 'observed' : 'none',
        required: false,
        evidence: _evidenceFor(
          (entry) => entry.category == DashboardLogCategory.error,
        ),
      ),
    ];
    if (isWindowsPlatform) {
      items.insert(
        6,
        AcceptanceChecklistItem(
          id: 'windowsV1Scope',
          label: 'Windows Credential Provider component',
          status: _windowsCredentialProviderChecklistStatus(
            autoUnlockCapabilityLabel,
          ),
          required: true,
          evidence: const [],
        ),
      );
    }
    return items;
  }

  List<DashboardLogEntry> _evidenceFor(
    bool Function(DashboardLogEntry entry) matches,
  ) {
    return _visibleLogs.where(matches).toList(growable: false);
  }

  List<AcceptanceValidationStep> get validationSteps {
    final itemsById = {
      for (final item in checklistItems) item.id: item,
    };
    return [
      _validationStep(
        id: 'bleScan',
        label: 'BLE scan',
        checklistIds: const [
          'realBleScan',
          'lockedSessionScan',
          'proximityDecision',
        ],
        itemsById: itemsById,
      ),
      _validationStep(
        id: 'lockWake',
        label: 'Lock and wake',
        checklistIds: const [
          'autoLockAction',
          'wakeAction',
        ],
        itemsById: itemsById,
      ),
      _validationStep(
        id: 'macAutoUnlock',
        label: 'macOS auto unlock',
        checklistIds: const [
          'macAutoUnlockAction',
        ],
        itemsById: itemsById,
      ),
      if (isWindowsPlatform)
        _validationStep(
          id: 'windowsV1Scope',
          label: 'Windows Credential Provider component',
          checklistIds: const [
            'windowsV1Scope',
          ],
          itemsById: itemsById,
        ),
      _validationStep(
        id: 'trayMenu',
        label: 'Tray menu',
        checklistIds: const [
          'trayOpenSettingsAction',
          'trayStartMonitoringAction',
          'trayPauseMonitoringAction',
          'trayLockNowAction',
          'trayQuitAction',
        ],
        itemsById: itemsById,
      ),
      _validationStep(
        id: 'startupAtLogin',
        label: 'Startup at login',
        checklistIds: const [
          'startupEnableAction',
          'startupDisableAction',
        ],
        itemsById: itemsById,
      ),
    ];
  }

  AcceptanceValidationStep _validationStep({
    required String id,
    required String label,
    required List<String> checklistIds,
    required Map<String, AcceptanceChecklistItem> itemsById,
  }) {
    final items = checklistIds
        .map((id) => itemsById[id])
        .whereType<AcceptanceChecklistItem>()
        .toList(growable: false);
    return AcceptanceValidationStep(
      id: id,
      label: label,
      checklistIds: checklistIds,
      items: items,
    );
  }

  Map<String, String> get checklistMap {
    return {
      for (final item in checklistItems) item.id: item.status,
    };
  }

  int get requiredChecklistCount {
    return checklistItems.where((item) => item.required).length;
  }

  int get completedRequiredChecklistCount {
    return checklistItems
        .where((item) => item.required && item.status == 'observed')
        .length;
  }

  int get missingRequiredEvidenceCount {
    return requiredChecklistCount - completedRequiredChecklistCount;
  }

  bool get readyForAcceptance {
    return missingRequiredEvidenceCount == 0;
  }

  List<String> get missingRequiredChecklistLabels {
    return checklistItems
        .where((item) => item.required && item.status != 'observed')
        .map((item) => item.label)
        .toList(growable: false);
  }

  String checklistStatus(String id) {
    return checklistMap[id] ?? 'missing';
  }

  String get checklistJsonLines {
    return checklistItems
        .map((item) => jsonEncode(item.toDiagnosticJson()))
        .join('\n');
  }

  String sessionChecklistJsonLines(String validationSessionId) {
    return _sessionJsonLines(
      checklistItems.map((item) => item.toDiagnosticJson()),
      validationSessionId,
    );
  }

  List<AcceptanceRunbookStep> get runbookSteps {
    return [
      for (final step in validationSteps)
        AcceptanceRunbookStep(
          validationStep: step,
          action: _runbookAction(step.id),
          expectedEvidence: _runbookExpectedEvidence(step.id),
        ),
    ];
  }

  String get runbookJsonLines {
    return runbookSteps
        .map((step) => jsonEncode(step.toDiagnosticJson()))
        .join('\n');
  }

  String sessionRunbookJsonLines(String validationSessionId) {
    return _sessionJsonLines(
      runbookSteps.map((step) => step.toDiagnosticJson()),
      validationSessionId,
    );
  }

  List<AcceptanceRunbookStep> get missingRunbookSteps {
    return runbookSteps
        .where((step) => step.missingRequiredLabels.isNotEmpty)
        .toList(growable: false);
  }

  String get missingRunbookJsonLines {
    return missingRunbookSteps
        .map((step) => jsonEncode(step.toDiagnosticJson()))
        .join('\n');
  }

  String sessionMissingRunbookJsonLines(String validationSessionId) {
    return _sessionJsonLines(
      missingRunbookSteps.map((step) => step.toDiagnosticJson()),
      validationSessionId,
    );
  }

  String get missingActionList {
    return missingRunbookSteps
        .map((step) => '${step.label}: ${step.nextActionHint}')
        .join('\n');
  }
}

String _sessionJsonLines(
  Iterable<Map<String, Object?>> rows,
  String validationSessionId,
) {
  return rows
      .map(
        (row) => jsonEncode({
          'validationSessionId': validationSessionId,
          ...row,
        }),
      )
      .join('\n');
}

class AcceptanceChecklistItem {
  const AcceptanceChecklistItem({
    required this.id,
    required this.label,
    required this.status,
    required this.required,
    required this.evidence,
  });

  final String id;
  final String label;
  final String status;
  final bool required;
  final List<DashboardLogEntry> evidence;

  int get evidenceCount => evidence.length;

  DateTime? get firstEvidenceAt {
    if (evidence.isEmpty) {
      return null;
    }
    return evidence
        .map((entry) => entry.timestamp)
        .reduce((a, b) => a.isBefore(b) ? a : b);
  }

  DateTime? get latestEvidenceAt {
    if (evidence.isEmpty) {
      return null;
    }
    return evidence
        .map((entry) => entry.timestamp)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Map<String, Object?> toDiagnosticJson() {
    return {
      'id': id,
      'label': label,
      'status': status,
      'required': required,
      'evidenceCount': evidenceCount,
      'firstEvidenceAt': firstEvidenceAt?.toUtc().toIso8601String(),
      'latestEvidenceAt': latestEvidenceAt?.toUtc().toIso8601String(),
    };
  }
}

class AcceptanceValidationStep {
  const AcceptanceValidationStep({
    required this.id,
    required this.label,
    required this.checklistIds,
    required this.items,
  });

  final String id;
  final String label;
  final List<String> checklistIds;
  final List<AcceptanceChecklistItem> items;

  int get requiredCount => items.where((item) => item.required).length;

  int get completedRequiredCount {
    return items
        .where((item) => item.required && item.status == 'observed')
        .length;
  }

  int get missingRequiredCount => requiredCount - completedRequiredCount;

  int get evidenceCount {
    return items.fold<int>(0, (sum, item) => sum + item.evidenceCount);
  }

  DateTime? get latestEvidenceAt {
    final timestamps = items
        .map((item) => item.latestEvidenceAt)
        .whereType<DateTime>()
        .toList(growable: false);
    if (timestamps.isEmpty) {
      return null;
    }
    return timestamps.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  String get status {
    if (requiredCount == 0 &&
        items.isNotEmpty &&
        items.every((item) => item.status == 'unsupported')) {
      return 'unsupported';
    }
    return missingRequiredCount == 0 ? 'ready' : 'incomplete';
  }

  Map<String, Object?> toDiagnosticJson() {
    return {
      'id': id,
      'label': label,
      'status': status,
      'checklistIds': checklistIds,
      'requiredCount': requiredCount,
      'completedRequiredCount': completedRequiredCount,
      'missingRequiredCount': missingRequiredCount,
      'evidenceCount': evidenceCount,
      'latestEvidenceAt': latestEvidenceAt?.toUtc().toIso8601String(),
    };
  }
}

class AcceptanceRunbookStep {
  const AcceptanceRunbookStep({
    required this.validationStep,
    required this.action,
    required this.expectedEvidence,
  });

  final AcceptanceValidationStep validationStep;
  final String action;
  final String expectedEvidence;

  String get id => validationStep.id;

  String get label => validationStep.label;

  String get status => validationStep.status;

  int get requiredCount => validationStep.requiredCount;

  int get completedRequiredCount => validationStep.completedRequiredCount;

  DateTime? get latestEvidenceAt => validationStep.latestEvidenceAt;

  String get progressLabel => '$completedRequiredCount/$requiredCount captured';

  List<String> get missingRequiredLabels {
    return validationStep.items
        .where((item) => item.required && item.status != 'observed')
        .map((item) => item.label)
        .toList(growable: false);
  }

  String? get nextActionHint {
    final missingLabels = missingRequiredLabels;
    if (missingLabels.isEmpty) {
      return null;
    }
    return _runbookNextActionHint(id, missingLabels);
  }

  Map<String, Object?> toDiagnosticJson() {
    return {
      'id': id,
      'label': label,
      'status': status,
      'action': action,
      'expectedEvidence': expectedEvidence,
      'progressLabel': progressLabel,
      'requiredCount': requiredCount,
      'completedRequiredCount': completedRequiredCount,
      'missingRequiredLabels': missingRequiredLabels,
      if (nextActionHint != null) 'nextActionHint': nextActionHint,
      'latestEvidenceAt': latestEvidenceAt?.toUtc().toIso8601String(),
    };
  }
}

String _runbookAction(String stepId) {
  switch (stepId) {
    case 'bleScan':
      return 'Scan nearby selected BLE devices';
    case 'lockWake':
      return 'Trigger automatic lock and wake';
    case 'macAutoUnlock':
      return 'Validate macOS automatic unlock';
    case 'windowsV1Scope':
      return 'Check Windows Credential Provider component';
    case 'trayMenu':
      return 'Use every tray menu action';
    case 'startupAtLogin':
      return 'Toggle startup at login';
    default:
      return 'Capture runtime evidence';
  }
}

String _runbookExpectedEvidence(String stepId) {
  switch (stepId) {
    case 'bleScan':
      return 'Real BLE scan, locked scan, decision';
    case 'lockWake':
      return 'Auto lock action, wake action';
    case 'macAutoUnlock':
      return 'macOS auto unlock action';
    case 'windowsV1Scope':
      return 'Windows Credential Provider component state';
    case 'trayMenu':
      return 'Tray open settings, start monitoring, pause monitoring, lock now, quit';
    case 'startupAtLogin':
      return 'Startup enable and disable actions';
    default:
      return 'Required runtime evidence';
  }
}

String _runbookNextActionHint(String stepId, List<String> missingLabels) {
  switch (stepId) {
    case 'bleScan':
      return 'Start monitoring with a selected BLE device, then lock the session and wait for scan plus decision logs.';
    case 'lockWake':
      return 'Move the selected device away until automatic lock is logged, then bring it close again to trigger wake.';
    case 'macAutoUnlock':
      return 'Enable macOS automatic unlock, grant Accessibility permission, save the password, lock the session, then bring the selected device close.';
    case 'windowsV1Scope':
      return 'Install and register the Windows Credential Provider component before requiring Windows automatic unlock evidence.';
    case 'trayMenu':
      return _trayRunbookHint(missingLabels);
    case 'startupAtLogin':
      return _startupRunbookHint(missingLabels);
    default:
      return 'Capture the missing required evidence for this validation step.';
  }
}

String _trayRunbookHint(List<String> missingLabels) {
  final actions = <String>[];
  if (missingLabels.contains('Tray open settings')) {
    actions.add('open settings');
  }
  if (missingLabels.contains('Tray start monitoring')) {
    actions.add('start monitoring');
  }
  if (missingLabels.contains('Tray pause monitoring')) {
    actions.add('pause monitoring');
  }
  if (missingLabels.contains('Tray lock now')) {
    actions.add('lock now');
  }
  if (missingLabels.contains('Tray quit')) {
    actions.add('quit');
  }
  if (actions.isEmpty) {
    return 'Use each missing tray menu item and confirm the action log appears.';
  }
  return 'Use the tray menu to ${actions.join(', ')} and confirm each action log appears.';
}

String _startupRunbookHint(List<String> missingLabels) {
  final needsEnable = missingLabels.contains('Startup enable');
  final needsDisable = missingLabels.contains('Startup disable');
  if (needsEnable && needsDisable) {
    return 'Toggle startup at login on and off, then confirm both startup change logs appear.';
  }
  if (needsEnable) {
    return 'Enable startup at login and confirm the startup enable log appears.';
  }
  if (needsDisable) {
    return 'Disable startup at login and confirm the startup disable log appears.';
  }
  return 'Toggle startup at login and confirm the missing startup log appears.';
}

bool _isAutoLockEvidence(DashboardLogEntry entry) {
  return entry.category == DashboardLogCategory.action &&
      entry.reason == 'proximityDecision' &&
      entry.message == 'Locked screen';
}

bool _isWakeEvidence(DashboardLogEntry entry) {
  return entry.category == DashboardLogCategory.action &&
      entry.reason == 'proximityDecision' &&
      entry.message == 'Wake requested';
}

bool _isAutoUnlockEvidence(DashboardLogEntry entry) {
  return entry.category == DashboardLogCategory.action &&
      entry.message == 'Unlocked session';
}

bool _isTrayActionEvidence(DashboardLogEntry entry) {
  return entry.category == DashboardLogCategory.action &&
      entry.reason == 'trayAction';
}

bool _isTrayOpenSettingsEvidence(DashboardLogEntry entry) {
  return _isTrayActionEvidence(entry) &&
      entry.message == 'Open settings requested';
}

bool _isTrayStartMonitoringEvidence(DashboardLogEntry entry) {
  return _isTrayActionEvidence(entry) && entry.message == 'Monitoring started';
}

bool _isTrayPauseMonitoringEvidence(DashboardLogEntry entry) {
  return _isTrayActionEvidence(entry) && entry.message == 'Monitoring paused';
}

bool _isTrayLockNowEvidence(DashboardLogEntry entry) {
  return _isTrayActionEvidence(entry) && entry.message == 'Locked screen';
}

bool _isTrayQuitEvidence(DashboardLogEntry entry) {
  return _isTrayActionEvidence(entry) && entry.message == 'Quit requested';
}

bool _isStartupActionEvidence(DashboardLogEntry entry) {
  return entry.category == DashboardLogCategory.action &&
      entry.reason == 'startupChanged';
}

bool _isStartupEnableEvidence(DashboardLogEntry entry) {
  return _isStartupActionEvidence(entry) && entry.message == 'Startup enabled';
}

bool _isStartupDisableEvidence(DashboardLogEntry entry) {
  return _isStartupActionEvidence(entry) && entry.message == 'Startup disabled';
}

String _evidenceLabel(bool hasEvidence) {
  return hasEvidence ? 'observed' : 'missing';
}

class DashboardState {
  const DashboardState({
    required this.snapshot,
    required this.devices,
    required this.logs,
    required this.config,
    this.lockSync = const LockSyncSnapshot.initial(),
  });

  const DashboardState.initial({this.config = const ProximityConfig()})
      : snapshot = const DashboardSnapshot.initial(),
        devices = const [],
        logs = const [],
        lockSync = const LockSyncSnapshot.initial();

  final DashboardSnapshot snapshot;
  final List<DashboardDeviceView> devices;
  final List<DashboardLogEntry> logs;
  final ProximityConfig config;
  final LockSyncSnapshot lockSync;

  String get diagnosticLogJsonLines {
    return logs.map((entry) => entry.diagnosticJsonLine).join('\n');
  }

  Map<String, Object?> toAcceptanceBundleJson({
    Iterable<DashboardLogEntry>? visibleLogs,
    Iterable<Map<String, Object?>>? externalValidationGates,
    DateTime? exportedAt,
    AcceptanceBundleEnvironment environment =
        const AcceptanceBundleEnvironment.unknown(),
    String? validationSessionId,
  }) {
    final logsForBundle = visibleLogs?.toList(growable: false) ?? logs;
    final summary = AcceptanceSummary.fromState(
      state: this,
      visibleLogs: logsForBundle,
    );
    final externalGateSummary =
        _externalValidationGateSummary(externalValidationGates);
    final overallBlockerLabels = _overallAcceptanceBlockerLabels(
      missingRequiredChecklistLabels: summary.missingRequiredChecklistLabels,
      externalGateSummary: externalGateSummary,
    );
    return {
      'schemaVersion': 1,
      if (validationSessionId != null)
        'validationSessionId': validationSessionId,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'environment': environment.toDiagnosticJson(),
      'acceptanceSummary': summary.toDiagnosticJson(),
      if (externalGateSummary != null)
        'externalValidationGateSummary': externalGateSummary,
      if (externalGateSummary != null)
        'overallReadyForAcceptance': summary.readyForAcceptance &&
            _externalGatesResolved(externalGateSummary),
      if (externalGateSummary != null)
        'overallAcceptanceBlockers': overallBlockerLabels.length,
      if (externalGateSummary != null)
        'overallAcceptanceBlockerLabels': overallBlockerLabels,
      'snapshot': snapshot.toDiagnosticJson(),
      'config': _configToDiagnosticJson(config),
      'lockSync': lockSync.toDiagnosticJson(),
      'devices': devices.map((device) => device.toDiagnosticJson()).toList(),
      'sessionDiagnostics': DashboardSessionDiagnostic.fromLogs(logsForBundle)
          .map((diagnostic) => diagnostic.toDiagnosticJson())
          .toList(),
      'deviceDiagnostics': DashboardDeviceDiagnostic.fromLogs(logsForBundle)
          .map((diagnostic) => diagnostic.toDiagnosticJson())
          .toList(),
      if (externalValidationGates != null)
        'externalValidationGates': externalValidationGates
            .map((gate) => Map<String, Object?>.from(gate))
            .toList(growable: false),
      'logs': logsForBundle.map((entry) => entry.toDiagnosticJson()).toList(),
    };
  }

  Map<String, Object?> toRunbookBundleJson({
    Iterable<DashboardLogEntry>? visibleLogs,
    Iterable<Map<String, Object?>>? externalValidationGates,
    DateTime? exportedAt,
    AcceptanceBundleEnvironment environment =
        const AcceptanceBundleEnvironment.unknown(),
    String? validationSessionId,
  }) {
    final logsForBundle = visibleLogs?.toList(growable: false) ?? logs;
    final summary = AcceptanceSummary.fromState(
      state: this,
      visibleLogs: logsForBundle,
    );
    final externalGateSummary =
        _externalValidationGateSummary(externalValidationGates);
    final overallBlockerLabels = _overallAcceptanceBlockerLabels(
      missingRequiredChecklistLabels: summary.missingRequiredChecklistLabels,
      externalGateSummary: externalGateSummary,
    );
    return {
      'schemaVersion': 1,
      'bundleType': 'validationRunbook',
      if (validationSessionId != null)
        'validationSessionId': validationSessionId,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'environment': environment.toDiagnosticJson(),
      'acceptanceSummary': summary.toDiagnosticJson(),
      if (externalGateSummary != null)
        'externalValidationGateSummary': externalGateSummary,
      if (externalGateSummary != null)
        'overallReadyForAcceptance': summary.readyForAcceptance &&
            _externalGatesResolved(externalGateSummary),
      if (externalGateSummary != null)
        'overallAcceptanceBlockers': overallBlockerLabels.length,
      if (externalGateSummary != null)
        'overallAcceptanceBlockerLabels': overallBlockerLabels,
      'snapshot': snapshot.toDiagnosticJson(),
      'config': _configToDiagnosticJson(config),
      'lockSync': lockSync.toDiagnosticJson(),
      if (externalValidationGates != null)
        'externalValidationGates': externalValidationGates
            .map((gate) => Map<String, Object?>.from(gate))
            .toList(growable: false),
      'runbookSteps':
          summary.runbookSteps.map((step) => step.toDiagnosticJson()).toList(),
      'runbookJsonLines': summary.runbookJsonLines,
      'missingRunbookSteps': summary.missingRunbookSteps
          .map((step) => step.toDiagnosticJson())
          .toList(),
      'missingRunbookJsonLines': summary.missingRunbookJsonLines,
      'missingActionList': summary.missingActionList,
    };
  }
}

Map<String, Object?> _configToDiagnosticJson(ProximityConfig config) {
  return {
    'minimumVisibleRssi': config.minimumVisibleRssi,
    'unlockRssi': config.unlockRssi,
    'lockRssi': config.lockRssi,
    'noSignalTimeoutSeconds': config.noSignalTimeout.inSeconds,
    'lockDelaySeconds': config.lockDelay.inSeconds,
    'unlockDeviceLogic': config.unlockDeviceLogic.name,
    'lockDeviceLogic': config.lockDeviceLogic.name,
    'wakeOnProximity': config.wakeOnProximity,
    'enableMacAutoUnlock': config.enableMacAutoUnlock,
    'rssiWindowSize': config.rssiWindowSize,
  };
}

Map<String, Object?>? _externalValidationGateSummary(
  Iterable<Map<String, Object?>>? gates,
) {
  if (gates == null) {
    return null;
  }
  var totalCount = 0;
  var passedCount = 0;
  var failedCount = 0;
  var manualRequiredCount = 0;
  final pendingLabels = <String>[];
  final failedLabels = <String>[];

  for (final gate in gates) {
    totalCount += 1;
    final label = _externalGateLabel(gate);
    switch (gate['status']) {
      case 'passed':
        passedCount += 1;
      case 'failed':
        failedCount += 1;
        failedLabels.add(label);
      default:
        manualRequiredCount += 1;
        pendingLabels.add(label);
    }
  }

  return {
    'totalCount': totalCount,
    'passedCount': passedCount,
    'failedCount': failedCount,
    'manualRequiredCount': manualRequiredCount,
    'completedCount': passedCount + failedCount,
    'incompleteCount': manualRequiredCount,
    'hasFailures': failedCount > 0,
    'allResolved': manualRequiredCount == 0,
    'pendingGateLabels': pendingLabels,
    'failedGateLabels': failedLabels,
  };
}

List<String> _overallAcceptanceBlockerLabels({
  required List<String> missingRequiredChecklistLabels,
  required Map<String, Object?>? externalGateSummary,
}) {
  return [
    for (final label in missingRequiredChecklistLabels)
      'Runtime evidence missing: $label',
    if (externalGateSummary != null)
      for (final label
          in externalGateSummary['pendingGateLabels'] as List<Object?>)
        'External gate pending: $label',
    if (externalGateSummary != null)
      for (final label
          in externalGateSummary['failedGateLabels'] as List<Object?>)
        'External gate failed: $label',
  ];
}

bool _externalGatesResolved(Map<String, Object?> externalGateSummary) {
  return externalGateSummary['allResolved'] == true &&
      externalGateSummary['hasFailures'] == false;
}

String _externalGateLabel(Map<String, Object?> gate) {
  final label = gate['label']?.toString().trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }
  final id = gate['id']?.toString().trim();
  if (id != null && id.isNotEmpty) {
    return id;
  }
  return 'Unknown external gate';
}

DashboardSnapshot snapshotFromDecision({
  required String platformLabel,
  required PresenceDecision decision,
  required ProximityConfig config,
  required bool isMonitoring,
  required bool isScanning,
  required bool isSessionLocked,
  required String lastActionLabel,
  required CapabilityStatus bluetoothCapability,
  required CapabilityStatus autoLockCapability,
  required CapabilityStatus wakeCapability,
  required CapabilityStatus autoUnlockCapability,
  required CapabilityStatus trayCapability,
  required CapabilityStatus startupCapability,
  required bool startupEnabled,
  required bool autoUnlockSecretConfigured,
  required bool autoUnlockSecretEditable,
  required bool autoUnlockPermissionSettingsAvailable,
  int? selectedDeviceCount,
}) {
  final effectiveSelectedDeviceCount = selectedDeviceCount ??
      decision.devices.values.where((device) => device.isSelected).length;
  return DashboardSnapshot(
    platformLabel: platformLabel,
    monitoringStatus: isMonitoring
        ? 'Monitoring'
        : isScanning
            ? 'Scanning'
            : 'Monitoring paused',
    stateLabel: _aggregateStateLabel(
      decision.deviceStates.values,
      isSessionLocked: isSessionLocked,
      isMonitoring: isMonitoring,
      selectedDeviceCount: effectiveSelectedDeviceCount,
    ),
    bestRssi: _bestRssi(decision.deviceStates.values),
    selectedDeviceCount: effectiveSelectedDeviceCount,
    lastActionLabel: lastActionLabel,
    bluetoothCapabilityLabel: _capabilityLabel(bluetoothCapability),
    autoLockCapabilityLabel: _capabilityLabel(autoLockCapability),
    wakeCapabilityLabel: _capabilityLabel(wakeCapability),
    autoUnlockCapabilityLabel: _capabilityLabel(autoUnlockCapability),
    trayCapabilityLabel: _capabilityLabel(trayCapability),
    startupCapabilityLabel: _capabilityLabel(startupCapability),
    startupEnabled: startupEnabled,
    autoUnlockSecretConfigured: autoUnlockSecretConfigured,
    autoUnlockSecretEditable: autoUnlockSecretEditable,
    autoUnlockPermissionSettingsAvailable:
        autoUnlockPermissionSettingsAvailable,
  );
}

List<DashboardDeviceView> devicesFromDecision(PresenceDecision decision) {
  final devices = decision.devices.values.toList()
    ..sort((left, right) {
      final namedCompare = _compareNamedDevices(left, right);
      if (namedCompare != 0) {
        return namedCompare;
      }
      final rssiCompare = _compareRssi(left.lastRssi, right.lastRssi);
      if (rssiCompare != 0) {
        return rssiCompare;
      }
      return _deviceSortName(left).compareTo(_deviceSortName(right));
    });
  return [
    for (final device in devices)
      DashboardDeviceView.fromDevice(
        device: device,
        presence: decision.deviceStates[device.platformId],
      ),
  ];
}

int _compareNamedDevices(BleDevice left, BleDevice right) {
  final leftHasName = _hasReadableDisplayName(left);
  final rightHasName = _hasReadableDisplayName(right);
  if (leftHasName == rightHasName) {
    return 0;
  }
  return leftHasName ? -1 : 1;
}

bool _hasReadableDisplayName(BleDevice device) {
  return _normalizedText(device.displayName) != null;
}

int _compareRssi(int? left, int? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return right.compareTo(left);
}

String _rssiLabel(BleDevice device) {
  final rssi = device.lastRssi;
  if (rssi != null) {
    return '$rssi dBm';
  }
  return '-- dBm';
}

String _deviceSortName(BleDevice device) {
  return _normalizedText(device.displayName) ??
      _normalizedText(device.addressHint) ??
      device.platformId;
}

String? _normalizedText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

String _aggregateStateLabel(
  Iterable<DevicePresence> presences, {
  required bool isSessionLocked,
  required bool isMonitoring,
  required int selectedDeviceCount,
}) {
  if (isSessionLocked) {
    return 'Locked';
  }
  if (presences.any(
    (presence) => presence.state == DevicePresenceState.close,
  )) {
    return 'Close';
  }
  if (presences.any(
    (presence) => presence.state == DevicePresenceState.away,
  )) {
    return 'Away';
  }
  if (presences.any(
    (presence) => presence.state == DevicePresenceState.lost,
  )) {
    return 'Lost';
  }
  if (isMonitoring && selectedDeviceCount > 0) {
    return 'Waiting for signal';
  }
  return 'Idle';
}

int? _bestRssi(Iterable<DevicePresence> presences) {
  int? best;
  for (final presence in presences) {
    if (best == null || presence.smoothedRssi > best) {
      best = presence.smoothedRssi;
    }
  }
  return best;
}

String _presenceLabel(DevicePresenceState? state) {
  switch (state) {
    case DevicePresenceState.close:
      return 'Close';
    case DevicePresenceState.away:
      return 'Away';
    case DevicePresenceState.lost:
      return 'Lost';
    case null:
      return 'Visible';
  }
}

String _timeLabel(DateTime? timestamp) {
  if (timestamp == null) {
    return '--';
  }
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  final second = timestamp.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _durationLabel(Duration? duration) {
  if (duration == null) {
    return '--';
  }
  if (duration.inMinutes >= 1) {
    final seconds = duration.inSeconds % 60;
    return seconds == 0
        ? '${duration.inMinutes}m'
        : '${duration.inMinutes}m ${seconds}s';
  }
  if (duration.inSeconds >= 1) {
    return '${duration.inSeconds}s';
  }
  return '${duration.inMilliseconds}ms';
}

String _shortPlatformId(String platformId) {
  if (platformId.length <= 12) {
    return platformId;
  }
  return '${platformId.substring(0, 8)}...'
      '${platformId.substring(platformId.length - 4)}';
}

String? _windowsBroadcastAddressLabel(Map<String, Object?>? rawAdvertisement) {
  final addressHint =
      _normalizedText(rawAdvertisement?['bluetoothAddressHint']?.toString());
  if (addressHint != null) {
    return '广播地址 $addressHint';
  }

  final compactAddress =
      _normalizedBluetoothAddress(rawAdvertisement?['bluetoothAddress']);
  if (compactAddress == null) {
    return null;
  }
  return '广播地址 ${_colonSeparatedBluetoothAddress(compactAddress)}';
}

String? _normalizedBluetoothAddress(Object? value) {
  if (value == null) {
    return null;
  }
  final normalized =
      value.toString().replaceAll(RegExp(r'[^0-9a-fA-F]'), '').toUpperCase();
  if (normalized.length != 12) {
    return null;
  }
  return normalized;
}

String _colonSeparatedBluetoothAddress(String compactAddress) {
  return [
    for (var index = 0; index < compactAddress.length; index += 2)
      compactAddress.substring(index, index + 2),
  ].join(':');
}

bool _isWindowsPlatformLabel(String label) {
  return label.trim().toLowerCase() == 'windows';
}

bool _isSupportedCapabilityLabel(String label) {
  return label.trim().toLowerCase() == 'supported';
}

bool _isUnsupportedCapabilityLabel(String label) {
  return label.trim().toLowerCase() == 'unsupported';
}

bool _isWindowsCredentialProviderMissing(String label) {
  return label.trim().toLowerCase() ==
      _windowsCredentialProviderMissingCapability;
}

String _windowsCredentialProviderReadinessLabel(String label) {
  if (_isSupportedCapabilityLabel(label)) {
    return 'Windows Credential Provider component ready';
  }
  if (_isWindowsCredentialProviderMissing(label) ||
      _isUnsupportedCapabilityLabel(label)) {
    return 'Windows Credential Provider component missing';
  }
  return 'Windows Credential Provider component pending';
}

String _windowsCredentialProviderChecklistStatus(String label) {
  if (_isSupportedCapabilityLabel(label)) {
    return 'ready';
  }
  return 'missing';
}

String _capabilityLabel(CapabilityStatus capability) {
  switch (capability.kind) {
    case CapabilityStatusKind.supported:
      return 'supported';
    case CapabilityStatusKind.unsupported:
      return 'unsupported';
    case CapabilityStatusKind.permissionDenied:
      return capability.description ?? 'permission denied';
    case CapabilityStatusKind.temporarilyUnavailable:
      return capability.description ?? 'temporarily unavailable';
    case CapabilityStatusKind.poweredOff:
      return capability.description ?? 'powered off';
    case CapabilityStatusKind.missingSecret:
      return capability.description ?? 'missing secret';
    case CapabilityStatusKind.failedWithReason:
      return capability.description ?? 'failed';
    case CapabilityStatusKind.unknown:
      return capability.description ?? 'unknown';
  }
}
