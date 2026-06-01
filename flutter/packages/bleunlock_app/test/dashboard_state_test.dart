import 'dart:convert';

import 'package:bleunlock_core/bleunlock_core.dart';

import '../lib/src/view_models/dashboard_state.dart';

void main() {
  testInitialSnapshotUsesDesignDefaults();
  testSnapshotFormatsRssiAndSelectedCount();
  testWindowsSnapshotWarnsWhenAutoUnlockCapabilityChanges();
  testDeviceViewFormatsLastSeenTime();
  testDevicesFromDecisionSortsByStrongestRssiFirst();
  testLogEntryFormatsStructuredDetails();
  testLogEntryIncludesSessionStateInDiagnostics();
  testLogEntryExportsStableDiagnosticJson();
  testStateExportsDiagnosticJsonLines();
  testLogFilterMatchesCategoryLevelAndIdentityFields();
  testLogFilterMatchesSessionState();
  testSessionDiagnosticsSummarizeScanEvidenceBySession();
  testSessionDiagnosticsExportStableJson();
  testDeviceDiagnosticsSummarizeScanIdentityStability();
  testAcceptanceChecklistTracksRuntimeEvidence();
  testAcceptanceChecklistExportsReadinessStatus();
  testAcceptanceSummaryExportsValidationSteps();
  testAcceptanceSummaryExportsRunbookSteps();
  testAcceptanceSummaryExportsSessionScopedJsonLines();
  testAcceptanceChecklistExportsJsonLines();
  testAcceptanceChecklistExportsEvidenceDetails();
  testAcceptanceChecklistTreatsWindowsAutoUnlockAsUnsupported();
  testAcceptanceChecklistTracksTrayMenuActionsSeparately();
  testAcceptanceChecklistTracksStartupEnableDisableSeparately();
  testAcceptanceChecklistTracksWindowsV1ScopeSeparately();
  testStateExportsAcceptanceBundleJson();
  testStateExportsRunbookBundleJson();
  testDeviceViewFormatsPlatformIdShortCode();
}

void testInitialSnapshotUsesDesignDefaults() {
  const snapshot = DashboardSnapshot.initial();

  assert(snapshot.platformLabel == 'unknown');
  assert(snapshot.monitoringStatus == 'Monitoring paused');
  assert(snapshot.stateLabel == 'Idle');
  assert(snapshot.bestRssiLabel == '-- dBm');
  assert(snapshot.selectedDevicesLabel == '0');
  assert(snapshot.lastActionLabel == 'None');
  assert(snapshot.bluetoothCapabilityLabel == 'Pending plugin');
  assert(snapshot.autoLockCapabilityLabel == 'Pending plugin');
  assert(snapshot.wakeCapabilityLabel == 'Pending plugin');
  assert(snapshot.autoUnlockCapabilityLabel == 'unsupported');
  assert(snapshot.trayCapabilityLabel == 'Pending plugin');
  assert(snapshot.startupCapabilityLabel == 'Pending plugin');
  assert(snapshot.startupEnabled == false);
  assert(snapshot.startupEnabledLabel == 'disabled');
  assert(snapshot.autoUnlockSecretConfigured == false);
  assert(snapshot.autoUnlockSecretEditable == false);
  assert(snapshot.autoUnlockPermissionSettingsAvailable == false);
  assert(snapshot.autoUnlockSecretLabel == 'missing');
  assert(snapshot.windowsV1ReadinessLabel == null);
}

void testSnapshotFormatsRssiAndSelectedCount() {
  const snapshot = DashboardSnapshot(
    monitoringStatus: 'Monitoring',
    stateLabel: 'Close',
    bestRssi: -57,
    selectedDeviceCount: 2,
    lastActionLabel: 'Wake requested',
    bluetoothCapabilityLabel: 'supported',
    autoLockCapabilityLabel: 'supported',
    wakeCapabilityLabel: 'supported',
    autoUnlockCapabilityLabel: 'unsupported',
    trayCapabilityLabel: 'supported',
    startupCapabilityLabel: 'supported',
    startupEnabled: true,
    autoUnlockSecretConfigured: true,
    autoUnlockSecretEditable: true,
    autoUnlockPermissionSettingsAvailable: true,
  );

  assert(snapshot.bestRssiLabel == '-57 dBm');
  assert(snapshot.selectedDevicesLabel == '2');
  assert(snapshot.startupEnabledLabel == 'enabled');
  assert(snapshot.autoUnlockSecretLabel == 'configured');
  assert(snapshot.autoUnlockSecretEditable == true);
  assert(snapshot.autoUnlockPermissionSettingsAvailable == true);
}

void testWindowsSnapshotWarnsWhenAutoUnlockCapabilityChanges() {
  const snapshot = DashboardSnapshot(
    platformLabel: 'Windows',
    monitoringStatus: 'Monitoring paused',
    stateLabel: 'Idle',
    bestRssi: null,
    selectedDeviceCount: 0,
    lastActionLabel: 'None',
    bluetoothCapabilityLabel: 'supported',
    autoLockCapabilityLabel: 'supported',
    wakeCapabilityLabel: 'supported',
    autoUnlockCapabilityLabel: 'supported',
    trayCapabilityLabel: 'supported',
    startupCapabilityLabel: 'supported',
    startupEnabled: false,
    autoUnlockSecretConfigured: false,
    autoUnlockSecretEditable: false,
    autoUnlockPermissionSettingsAvailable: false,
  );

  assert(snapshot.isWindowsPlatform == true);
  assert(snapshot.isWindowsV1AutoUnlockUnsupported == false);
  assert(snapshot.windowsV1ReadinessLabel ==
      'Windows automatic unlock capability changed; review v1 scope');
  assert(snapshot.toDiagnosticJson()['windowsV1ReadinessLabel'] ==
      'Windows automatic unlock capability changed; review v1 scope');
}

void testDeviceViewFormatsLastSeenTime() {
  final view = DashboardDeviceView.fromDevice(
    device: BleDevice(
      platformId: 'band-1',
      displayName: 'Xiaomi Smart Band',
      lastRssi: -52,
      lastSeenAt: DateTime(2026, 5, 28, 10, 11, 12),
      isSelected: true,
    ),
    presence: DevicePresence(
      deviceId: 'band-1',
      smoothedRssi: -52,
      state: DevicePresenceState.close,
      lastStateChangedAt: DateTime(2026, 5, 28, 10, 11, 12),
      reason: 'rssiAboveUnlockThreshold',
    ),
  );

  assert(view.name == 'Xiaomi Smart Band');
  assert(view.rssiLabel == '-52 dBm');
  assert(view.lastSeenLabel == 'Last seen 10:11:12');
  assert(view.presenceLabel == 'Close');
  assert(view.isSelected == true);

  final unseen = DashboardDeviceView.fromDevice(
    device: const BleDevice(platformId: 'band-2'),
    presence: null,
  );

  assert(unseen.lastSeenLabel == 'Last seen --');
}

void testDevicesFromDecisionSortsByStrongestRssiFirst() {
  final decision = PresenceDecision(
    shouldLock: false,
    shouldWake: false,
    shouldUnlock: false,
    reason: 'discovery',
    devices: {
      'weak': BleDevice(
        platformId: 'weak',
        displayName: 'Weak band',
        lastRssi: -82,
        lastSeenAt: DateTime(2026, 5, 28, 10),
        isSelected: true,
      ),
      'unknown': BleDevice(
        platformId: 'unknown',
        displayName: 'Unknown RSSI band',
        lastSeenAt: DateTime(2026, 5, 28, 10),
      ),
      'strong': BleDevice(
        platformId: 'strong',
        displayName: 'Strong band',
        lastRssi: -42,
        lastSeenAt: DateTime(2026, 5, 28, 10),
      ),
      'middle': BleDevice(
        platformId: 'middle',
        displayName: 'Middle band',
        lastRssi: -61,
        lastSeenAt: DateTime(2026, 5, 28, 10),
      ),
    },
    deviceStates: const {},
    timestamp: DateTime(2026, 5, 28, 10),
  );

  final devices = devicesFromDecision(decision);

  assert(devices.map((device) => device.id).join(',') ==
      'strong,middle,weak,unknown');
}

void testLogEntryFormatsStructuredDetails() {
  final entry = DashboardLogEntry(
    timestamp: DateTime(2026, 5, 28, 10, 11, 12),
    category: DashboardLogCategory.scan,
    message: 'Scan band-1 -52 dBm',
    platform: 'macOS',
    displayName: 'Xiaomi Smart Band',
    addressHint: 'AA:BB:CC:DD:EE:FF',
    deviceId: 'band-1',
    rssi: -52,
    reason: 'bleAdvertisement',
    manufacturerData: const [76, 0, 16, 5],
  );

  assert(entry.timeLabel == '10:11:12');
  assert(entry.level == DashboardLogLevel.info);
  assert(
    entry.detailLabel ==
        'level=info platform=macOS name=Xiaomi Smart Band '
            'address=AA:BB:CC:DD:EE:FF device=band-1 rssi=-52 '
            'reason=bleAdvertisement',
  );

  final error = DashboardLogEntry(
    timestamp: DateTime(2026, 5, 28, 10, 11, 13),
    category: DashboardLogCategory.error,
    message: 'Bluetooth scanning unavailable',
  );

  assert(error.level == DashboardLogLevel.error);
  assert(error.detailLabel == 'level=error platform=app');
}

void testLogEntryIncludesSessionStateInDiagnostics() {
  final entry = DashboardLogEntry(
    timestamp: DateTime.utc(2026, 5, 28, 10, 11, 12),
    category: DashboardLogCategory.scan,
    message: 'Scan band-1 -52 dBm',
    deviceId: 'band-1',
    rssi: -52,
    reason: 'bleAdvertisement',
    sessionState: DashboardSessionState.locked,
  );

  final json = entry.toDiagnosticJson();
  final filtered = const DashboardLogFilter(query: 'locked').apply([entry]);

  assert(entry.detailLabel.contains('session=locked'));
  assert(json['sessionState'] == 'locked');
  assert(filtered.single == entry);
}

void testLogEntryExportsStableDiagnosticJson() {
  final entry = DashboardLogEntry(
    timestamp: DateTime.utc(2026, 5, 28, 10, 11, 12),
    category: DashboardLogCategory.scan,
    message: 'Scan band-1 -52 dBm',
    platform: 'macOS',
    displayName: 'Xiaomi Smart Band',
    addressHint: 'AA:BB:CC:DD:EE:FF',
    deviceId: 'band-1',
    rssi: -52,
    reason: 'bleAdvertisement',
    manufacturerData: const [76, 0, 16, 5],
  );

  final json = jsonDecode(entry.diagnosticJsonLine) as Map<String, Object?>;

  assert(json['timestamp'] == '2026-05-28T10:11:12.000Z');
  assert(json['level'] == 'info');
  assert(json['category'] == 'scan');
  assert(json['platform'] == 'macOS');
  assert(json['message'] == 'Scan band-1 -52 dBm');
  assert(json['displayName'] == 'Xiaomi Smart Band');
  assert(json['addressHint'] == 'AA:BB:CC:DD:EE:FF');
  assert(json['deviceId'] == 'band-1');
  assert(json['rssi'] == -52);
  assert(json['reason'] == 'bleAdvertisement');
  assert(json['manufacturerDataHex'] == '4C001005');
}

void testStateExportsDiagnosticJsonLines() {
  final state = DashboardState(
    snapshot: const DashboardSnapshot(
      monitoringStatus: 'Monitoring',
      stateLabel: 'Locked',
      bestRssi: -52,
      selectedDeviceCount: 1,
      lastActionLabel: 'Unlocked session',
      bluetoothCapabilityLabel: 'supported',
      autoLockCapabilityLabel: 'supported',
      wakeCapabilityLabel: 'supported',
      autoUnlockCapabilityLabel: 'supported',
      trayCapabilityLabel: 'supported',
      startupCapabilityLabel: 'supported',
      startupEnabled: true,
      autoUnlockSecretConfigured: true,
      autoUnlockSecretEditable: true,
      autoUnlockPermissionSettingsAvailable: false,
    ),
    devices: const [],
    logs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 12),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
        reason: 'bleAdvertisement',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 13),
        category: DashboardLogCategory.action,
        message: 'Locked screen',
        reason: 'manualLock',
      ),
    ],
    config: const ProximityConfig(),
  );

  final lines = state.diagnosticLogJsonLines.split('\n');

  assert(lines.length == 2);
  assert((jsonDecode(lines.first) as Map<String, Object?>)['deviceId'] ==
      'band-1');
  assert((jsonDecode(lines.last) as Map<String, Object?>)['message'] ==
      'Locked screen');
}

void testLogFilterMatchesCategoryLevelAndIdentityFields() {
  final logs = [
    DashboardLogEntry(
      timestamp: DateTime.utc(2026, 5, 28, 10),
      category: DashboardLogCategory.scan,
      message: 'Scan band-1 -52 dBm',
      displayName: 'Xiaomi Smart Band',
      addressHint: 'AA:BB:CC:DD:EE:FF',
      deviceId: 'band-1',
      rssi: -52,
      reason: 'bleAdvertisement',
      manufacturerData: const [76, 0, 16, 5],
    ),
    DashboardLogEntry(
      timestamp: DateTime.utc(2026, 5, 28, 10, 0, 1),
      category: DashboardLogCategory.decision,
      message: 'Decision allAway',
      deviceId: 'watch-2',
      rssi: -90,
      reason: 'rssiBelowLockThresholdForDelay',
    ),
    DashboardLogEntry(
      timestamp: DateTime.utc(2026, 5, 28, 10, 0, 2),
      category: DashboardLogCategory.error,
      message: 'Bluetooth scanning unavailable',
      reason: 'scannerUnavailable',
    ),
  ];

  final scanOnly = const DashboardLogFilter(
    category: DashboardLogCategory.scan,
  ).apply(logs);
  final errorsOnly = const DashboardLogFilter(
    level: DashboardLogLevel.error,
  ).apply(logs);
  final deviceQuery = const DashboardLogFilter(query: 'xiaomi').apply(logs);
  final manufacturerQuery =
      const DashboardLogFilter(query: '4c001005').apply(logs);
  final reasonQuery = const DashboardLogFilter(query: 'threshold').apply(logs);

  assert(scanOnly.length == 1);
  assert(scanOnly.single.category == DashboardLogCategory.scan);
  assert(errorsOnly.length == 1);
  assert(errorsOnly.single.level == DashboardLogLevel.error);
  assert(deviceQuery.single.deviceId == 'band-1');
  assert(manufacturerQuery.single.deviceId == 'band-1');
  assert(reasonQuery.single.deviceId == 'watch-2');
}

void testLogFilterMatchesSessionState() {
  final logs = [
    DashboardLogEntry(
      timestamp: DateTime.utc(2026, 5, 28, 10),
      category: DashboardLogCategory.scan,
      message: 'Scan band-1 -52 dBm',
      deviceId: 'band-1',
      sessionState: DashboardSessionState.unlocked,
    ),
    DashboardLogEntry(
      timestamp: DateTime.utc(2026, 5, 28, 10, 0, 1),
      category: DashboardLogCategory.scan,
      message: 'Scan band-1 -60 dBm',
      deviceId: 'band-1',
      sessionState: DashboardSessionState.locked,
    ),
    DashboardLogEntry(
      timestamp: DateTime.utc(2026, 5, 28, 10, 0, 2),
      category: DashboardLogCategory.action,
      message: 'System wake',
      sessionState: DashboardSessionState.systemWake,
    ),
  ];

  final lockedLogs = const DashboardLogFilter(
    sessionState: DashboardSessionState.locked,
  ).apply(logs);
  final wakeLogs = const DashboardLogFilter(
    sessionState: DashboardSessionState.systemWake,
  ).apply(logs);
  final scanWhileLocked = const DashboardLogFilter(
    category: DashboardLogCategory.scan,
    sessionState: DashboardSessionState.locked,
  ).apply(logs);

  assert(lockedLogs.single.message == 'Scan band-1 -60 dBm');
  assert(wakeLogs.single.message == 'System wake');
  assert(scanWhileLocked.single.deviceId == 'band-1');
}

void testSessionDiagnosticsSummarizeScanEvidenceBySession() {
  final diagnostics = DashboardSessionDiagnostic.fromLogs([
    DashboardLogEntry(
      timestamp: DateTime(2026, 5, 28, 10),
      category: DashboardLogCategory.scan,
      message: 'Scan band-1 -52 dBm',
      deviceId: 'band-1',
      rssi: -52,
      sessionState: DashboardSessionState.unlocked,
    ),
    DashboardLogEntry(
      timestamp: DateTime(2026, 5, 28, 10, 0, 1),
      category: DashboardLogCategory.scan,
      message: 'Scan band-1 -60 dBm',
      deviceId: 'band-1',
      rssi: -60,
      sessionState: DashboardSessionState.locked,
    ),
    DashboardLogEntry(
      timestamp: DateTime(2026, 5, 28, 10, 0, 5),
      category: DashboardLogCategory.action,
      message: 'Session locked',
      sessionState: DashboardSessionState.locked,
    ),
    DashboardLogEntry(
      timestamp: DateTime(2026, 5, 28, 10, 1),
      category: DashboardLogCategory.action,
      message: 'System wake',
      sessionState: DashboardSessionState.systemWake,
    ),
    DashboardLogEntry(
      timestamp: DateTime(2026, 5, 28, 10, 2),
      category: DashboardLogCategory.scan,
      message: 'Scan ignored without session',
      deviceId: 'watch-2',
      rssi: -70,
    ),
  ]);

  final unlocked = diagnostics.firstWhere(
    (entry) => entry.sessionState == DashboardSessionState.unlocked,
  );
  final locked = diagnostics.firstWhere(
    (entry) => entry.sessionState == DashboardSessionState.locked,
  );
  final systemWake = diagnostics.firstWhere(
    (entry) => entry.sessionState == DashboardSessionState.systemWake,
  );

  assert(diagnostics.length == 3);
  assert(unlocked.logCount == 1);
  assert(unlocked.scanCount == 1);
  assert(unlocked.latestScanRssiLabel == '-52 dBm');
  assert(unlocked.latestScanDeviceLabel == 'device band-1');
  assert(unlocked.scanEvidenceLabel == 'BLE scan observed');

  assert(locked.logCount == 2);
  assert(locked.scanCount == 1);
  assert(locked.latestEventLabel == 'latest event 10:00:05');
  assert(locked.latestScanLabel == 'latest scan 10:00:01');
  assert(locked.latestScanRssiLabel == '-60 dBm');
  assert(locked.scanEvidenceLabel == 'BLE scan observed');

  assert(systemWake.logCount == 1);
  assert(systemWake.scanCount == 0);
  assert(systemWake.latestScanLabel == 'latest scan --');
  assert(systemWake.latestScanRssiLabel == '-- dBm');
  assert(systemWake.latestScanDeviceLabel == 'device --');
  assert(systemWake.scanEvidenceLabel == 'No scan events');
}

void testSessionDiagnosticsExportStableJson() {
  final diagnostic = DashboardSessionDiagnostic(
    sessionState: DashboardSessionState.locked,
    logCount: 3,
    scanCount: 2,
    latestEventAt: DateTime.utc(2026, 5, 28, 10, 0, 5),
    latestScanAt: DateTime.utc(2026, 5, 28, 10, 0, 1),
    latestScanRssi: -60,
    latestScanDeviceId: 'band-1',
  );
  final noScanDiagnostic = DashboardSessionDiagnostic(
    sessionState: DashboardSessionState.systemWake,
    logCount: 1,
    scanCount: 0,
    latestEventAt: DateTime.utc(2026, 5, 28, 10, 1),
    latestScanAt: null,
    latestScanRssi: null,
    latestScanDeviceId: null,
  );

  final json = diagnostic.toDiagnosticJson();
  final noScanJson = noScanDiagnostic.toDiagnosticJson();
  final decodedLine =
      jsonDecode(diagnostic.diagnosticJsonLine) as Map<String, Object?>;

  assert(json['sessionState'] == 'locked');
  assert(json['logCount'] == 3);
  assert(json['scanCount'] == 2);
  assert(json['scanObserved'] == true);
  assert(json['latestEventAt'] == '2026-05-28T10:00:05.000Z');
  assert(json['latestScanAt'] == '2026-05-28T10:00:01.000Z');
  assert(json['latestScanRssi'] == -60);
  assert(json['latestScanDeviceId'] == 'band-1');
  assert(decodedLine['sessionState'] == 'locked');

  assert(noScanJson['sessionState'] == 'systemWake');
  assert(noScanJson['scanObserved'] == false);
  assert(noScanJson.containsKey('latestScanAt') == false);
  assert(noScanJson.containsKey('latestScanRssi') == false);
  assert(noScanJson.containsKey('latestScanDeviceId') == false);
}

void testDeviceDiagnosticsSummarizeScanIdentityStability() {
  final diagnostics = DashboardDeviceDiagnostic.fromLogs([
    DashboardLogEntry(
      timestamp: DateTime(2026, 5, 28, 10),
      category: DashboardLogCategory.scan,
      message: 'Scan band-1 -52 dBm',
      displayName: 'Xiaomi Smart Band',
      addressHint: 'AA:BB:CC:DD:EE:FF',
      deviceId: 'band-1',
      rssi: -52,
      reason: 'bleAdvertisement',
      manufacturerData: const [76, 0, 16, 5],
    ),
    DashboardLogEntry(
      timestamp: DateTime(2026, 5, 28, 10, 0, 3),
      category: DashboardLogCategory.scan,
      message: 'Scan band-1 -60 dBm',
      displayName: 'Xiaomi Smart Band 10',
      addressHint: 'AA:BB:CC:DD:EE:FF',
      deviceId: 'band-1',
      rssi: -60,
      reason: 'bleAdvertisement',
      manufacturerData: const [76, 0, 16, 5],
    ),
    DashboardLogEntry(
      timestamp: DateTime(2026, 5, 28, 10, 0, 10),
      category: DashboardLogCategory.scan,
      message: 'Scan band-1 -58 dBm',
      displayName: 'Xiaomi Smart Band 10',
      addressHint: 'AA:BB:CC:DD:EE:FF',
      deviceId: 'band-1',
      rssi: -58,
      reason: 'bleAdvertisement',
      manufacturerData: const [76, 0, 16, 5],
    ),
    DashboardLogEntry(
      timestamp: DateTime(2026, 5, 28, 10, 0, 1),
      category: DashboardLogCategory.scan,
      message: 'Scan watch-2 -70 dBm',
      displayName: 'Stable Watch',
      deviceId: 'watch-2',
      rssi: -70,
      reason: 'bleAdvertisement',
    ),
    DashboardLogEntry(
      timestamp: DateTime(2026, 5, 28, 10, 0, 2),
      category: DashboardLogCategory.error,
      message: 'Bluetooth scanning unavailable',
      deviceId: 'band-1',
    ),
  ]);

  assert(diagnostics.length == 2);
  assert(diagnostics.first.deviceId == 'band-1');
  assert(diagnostics.first.seenCount == 3);
  assert(diagnostics.first.latestRssiLabel == '-58 dBm');
  assert(diagnostics.first.averageRssiLabel == '-57 dBm avg');
  assert(diagnostics.first.rssiRangeLabel == '-60 to -52 dBm');
  assert(diagnostics.first.averageIntervalLabel == 'avg interval 5s');
  assert(diagnostics.first.longestSilenceLabel == 'longest silence 7s');
  assert(diagnostics.first.lastSeenLabel == 'Last seen 10:00:10');
  assert(diagnostics.first.displayNameLabel == 'Xiaomi Smart Band 10');
  assert(diagnostics.first.addressHintLabel == 'AA:BB:CC:DD:EE:FF');
  assert(diagnostics.first.manufacturerDataHexLabel == '4C001005');
  assert(diagnostics.first.identityStatus == DeviceIdentityStatus.changed);
  assert(diagnostics.first.identityStatusLabel == 'Identity changed');

  assert(diagnostics.last.deviceId == 'watch-2');
  assert(diagnostics.last.averageIntervalLabel == 'avg interval --');
  assert(diagnostics.last.longestSilenceLabel == 'longest silence --');
  assert(diagnostics.last.identityStatus == DeviceIdentityStatus.stable);
  assert(diagnostics.last.identityStatusLabel == 'Stable identity');
}

void testAcceptanceChecklistTracksRuntimeEvidence() {
  final state = DashboardState(
    snapshot: const DashboardSnapshot(
      monitoringStatus: 'Monitoring',
      stateLabel: 'Locked',
      bestRssi: -52,
      selectedDeviceCount: 1,
      lastActionLabel: 'Unlocked session',
      bluetoothCapabilityLabel: 'supported',
      autoLockCapabilityLabel: 'supported',
      wakeCapabilityLabel: 'supported',
      autoUnlockCapabilityLabel: 'supported',
      trayCapabilityLabel: 'supported',
      startupCapabilityLabel: 'supported',
      startupEnabled: true,
      autoUnlockSecretConfigured: true,
      autoUnlockSecretEditable: true,
      autoUnlockPermissionSettingsAvailable: false,
    ),
    devices: const [
      DashboardDeviceView(
        id: 'band-1',
        idLabel: 'ID band-1',
        name: 'Xiaomi Smart Band',
        rssiLabel: '-52 dBm',
        lastSeenLabel: 'Last seen 10:11:12',
        presenceLabel: 'Close',
        isSelected: true,
      ),
    ],
    logs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 12),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
        sessionState: DashboardSessionState.locked,
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 15),
        category: DashboardLogCategory.decision,
        message: 'Decision close',
        reason: 'close',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 18),
        category: DashboardLogCategory.action,
        message: 'Locked screen',
        reason: 'proximityDecision',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 20),
        category: DashboardLogCategory.action,
        message: 'Wake requested',
        reason: 'proximityDecision',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 22),
        category: DashboardLogCategory.action,
        message: 'Unlocked session',
        reason: 'autoUnlockSucceeded',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 24),
        category: DashboardLogCategory.action,
        message: 'Open settings requested',
        reason: 'trayAction',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 26),
        category: DashboardLogCategory.action,
        message: 'Startup enabled',
        reason: 'startupChanged',
      ),
    ],
    config: const ProximityConfig(enableMacAutoUnlock: true),
  );

  final summary = AcceptanceSummary.fromState(
    state: state,
    visibleLogs: state.logs,
  );
  final json = summary.toDiagnosticJson();
  final checklist = json['checklist'] as Map<String, Object?>;

  assert(summary.hasAutoLockEvidence == true);
  assert(summary.hasWakeEvidence == true);
  assert(summary.hasAutoUnlockEvidence == true);
  assert(summary.hasTrayActionEvidence == true);
  assert(summary.hasStartupActionEvidence == true);
  assert(checklist['realBleScan'] == 'observed');
  assert(checklist['lockedSessionScan'] == 'observed');
  assert(checklist['proximityDecision'] == 'observed');
  assert(checklist['autoLockAction'] == 'observed');
  assert(checklist['wakeAction'] == 'observed');
  assert(checklist['macAutoUnlockAction'] == 'observed');
  assert(checklist['trayAction'] == 'observed');
  assert(checklist['startupAction'] == 'observed');
  assert(checklist['errors'] == 'none');
  assert(summary.requiredChecklistCount == 15);
  assert(summary.completedRequiredChecklistCount == 10);
  assert(summary.missingRequiredEvidenceCount == 5);
  assert(summary.readyForAcceptance == false);
  assert(summary.missingRequiredChecklistLabels.length == 5);
  assert(
      summary.missingRequiredChecklistLabels.contains('Tray start monitoring'));
  assert(summary.missingRequiredChecklistLabels.contains('Startup disable'));
}

void testAcceptanceChecklistExportsReadinessStatus() {
  final summary = AcceptanceSummary.fromState(
    state: const DashboardState(
      snapshot: DashboardSnapshot(
        platformLabel: 'Windows',
        monitoringStatus: 'Monitoring paused',
        stateLabel: 'Idle',
        bestRssi: null,
        selectedDeviceCount: 0,
        lastActionLabel: 'None',
        bluetoothCapabilityLabel: 'supported',
        autoLockCapabilityLabel: 'supported',
        wakeCapabilityLabel: 'supported',
        autoUnlockCapabilityLabel: 'unsupported',
        trayCapabilityLabel: 'supported',
        startupCapabilityLabel: 'supported',
        startupEnabled: false,
        autoUnlockSecretConfigured: false,
        autoUnlockSecretEditable: false,
        autoUnlockPermissionSettingsAvailable: false,
      ),
      devices: [],
      logs: [],
      config: ProximityConfig(enableMacAutoUnlock: false),
    ),
    visibleLogs: const [],
  );
  final json = summary.toDiagnosticJson();

  assert(summary.requiredChecklistCount == 15);
  assert(summary.completedRequiredChecklistCount == 1);
  assert(summary.missingRequiredEvidenceCount == 14);
  assert(summary.readyForAcceptance == false);
  assert(json['missingRequiredEvidenceCount'] == 14);
  assert(json['readyForAcceptance'] == false);
}

void testAcceptanceSummaryExportsValidationSteps() {
  final summary = AcceptanceSummary.fromState(
    state: const DashboardState(
      snapshot: DashboardSnapshot.initial(),
      devices: [],
      logs: [],
      config: ProximityConfig(),
    ),
    visibleLogs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
        sessionState: DashboardSessionState.locked,
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 1),
        category: DashboardLogCategory.decision,
        message: 'Decision close',
        reason: 'close',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 2),
        category: DashboardLogCategory.action,
        message: 'Open settings requested',
        reason: 'trayAction',
      ),
    ],
  );
  final json = summary.toDiagnosticJson();
  final steps = json['validationSteps'] as List<Object?>;
  final byId = {
    for (final step in steps)
      (step as Map<String, Object?>)['id'] as String: step,
  };
  final scan = byId['bleScan']!;
  final tray = byId['trayMenu']!;
  final startup = byId['startupAtLogin']!;

  assert(steps.length == 5);
  assert(scan['label'] == 'BLE scan');
  assert(scan['status'] == 'ready');
  assert(scan['completedRequiredCount'] == 3);
  assert(scan['requiredCount'] == 3);
  assert(scan['missingRequiredCount'] == 0);
  assert(scan['latestEvidenceAt'] == '2026-05-28T10:00:01.000Z');
  assert(tray['status'] == 'incomplete');
  assert(tray['completedRequiredCount'] == 1);
  assert(tray['requiredCount'] == 5);
  assert((tray['checklistIds'] as List<Object?>).contains('trayLockNowAction'));
  assert(startup['status'] == 'incomplete');
  assert(startup['latestEvidenceAt'] == null);
}

void testAcceptanceSummaryExportsRunbookSteps() {
  final summary = AcceptanceSummary.fromState(
    state: const DashboardState(
      snapshot: DashboardSnapshot(
        monitoringStatus: 'Monitoring',
        stateLabel: 'Locked',
        bestRssi: -52,
        selectedDeviceCount: 1,
        lastActionLabel: 'Open settings requested',
        bluetoothCapabilityLabel: 'supported',
        autoLockCapabilityLabel: 'supported',
        wakeCapabilityLabel: 'supported',
        autoUnlockCapabilityLabel: 'supported',
        trayCapabilityLabel: 'supported',
        startupCapabilityLabel: 'supported',
        startupEnabled: true,
        autoUnlockSecretConfigured: true,
        autoUnlockSecretEditable: true,
        autoUnlockPermissionSettingsAvailable: false,
      ),
      devices: [],
      logs: [],
      config: ProximityConfig(enableMacAutoUnlock: true),
    ),
    visibleLogs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
        sessionState: DashboardSessionState.locked,
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 1),
        category: DashboardLogCategory.decision,
        message: 'Decision close',
        reason: 'close',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 2),
        category: DashboardLogCategory.action,
        message: 'Open settings requested',
        reason: 'trayAction',
      ),
    ],
  );

  final json = summary.toDiagnosticJson();
  final runbookSteps = json['runbookSteps'] as List<Object?>;
  final missingRunbookSteps = json['missingRunbookSteps'] as List<Object?>;
  final byId = {
    for (final step in runbookSteps)
      (step as Map<String, Object?>)['id'] as String: step,
  };
  final missingById = {
    for (final step in missingRunbookSteps)
      (step as Map<String, Object?>)['id'] as String: step,
  };
  final scan = byId['bleScan']!;
  final tray = byId['trayMenu']!;
  final missingTray = missingById['trayMenu']!;
  final line = jsonDecode(summary.runbookJsonLines.split('\n').first)
      as Map<String, Object?>;
  final missingLine =
      jsonDecode(summary.missingRunbookJsonLines.split('\n').first)
          as Map<String, Object?>;
  final missingActionLines = summary.missingActionList.split('\n');

  assert(runbookSteps.length == 5);
  assert(missingRunbookSteps.length == 4);
  assert(missingActionLines.length == 4);
  assert(scan['status'] == 'ready');
  assert(scan['progressLabel'] == '3/3 captured');
  assert(scan['latestEvidenceAt'] == '2026-05-28T10:00:01.000Z');
  assert(scan['action'] == 'Scan nearby selected BLE devices');
  assert(tray['status'] == 'incomplete');
  assert(!missingById.containsKey('bleScan'));
  assert(missingById.containsKey('trayMenu'));
  assert((missingTray['nextActionHint'] as String)
      .contains('Use the tray menu to start monitoring'));
  assert((tray['missingRequiredLabels'] as List<Object?>)
      .contains('Tray start monitoring'));
  assert(line['id'] == 'bleScan');
  assert(line['expectedEvidence'] == 'Real BLE scan, locked scan, decision');
  assert(missingLine['id'] == 'lockWake');
  assert((missingLine['nextActionHint'] as String)
      .contains('Move the selected device away'));
  assert(missingActionLines.first.startsWith('Lock and wake: Move'));
  assert(missingActionLines
      .any((line) => line.contains('Tray menu: Use the tray')));
}

void testAcceptanceSummaryExportsSessionScopedJsonLines() {
  final summary = AcceptanceSummary.fromState(
    state: const DashboardState(
      snapshot: DashboardSnapshot.initial(),
      devices: [],
      logs: [],
      config: ProximityConfig(),
    ),
    visibleLogs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
      ),
    ],
  );

  final checklistLine = jsonDecode(
    summary
        .sessionChecklistJsonLines('validation-manual-001')
        .split('\n')
        .first,
  ) as Map<String, Object?>;
  final runbookLine = jsonDecode(
    summary.sessionRunbookJsonLines('validation-manual-001').split('\n').first,
  ) as Map<String, Object?>;
  final missingRunbookLine = jsonDecode(
    summary
        .sessionMissingRunbookJsonLines('validation-manual-001')
        .split('\n')
        .first,
  ) as Map<String, Object?>;

  assert(checklistLine['validationSessionId'] == 'validation-manual-001');
  assert(checklistLine['id'] == 'realBleScan');
  assert(runbookLine['validationSessionId'] == 'validation-manual-001');
  assert(runbookLine['id'] == 'bleScan');
  assert(missingRunbookLine['validationSessionId'] == 'validation-manual-001');
  assert(missingRunbookLine['id'] == 'bleScan');
}

void testAcceptanceChecklistExportsJsonLines() {
  final summary = AcceptanceSummary.fromState(
    state: const DashboardState(
      snapshot: DashboardSnapshot.initial(),
      devices: [],
      logs: [],
      config: ProximityConfig(),
    ),
    visibleLogs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 1),
        category: DashboardLogCategory.action,
        message: 'Open settings requested',
        reason: 'trayAction',
      ),
    ],
  );

  final lines = summary.checklistJsonLines.split('\n');
  final items = {
    for (final line in lines)
      (jsonDecode(line) as Map<String, Object?>)['id'] as String:
          jsonDecode(line) as Map<String, Object?>,
  };
  final scan = items['realBleScan']!;
  final lockedScan = items['lockedSessionScan']!;
  final tray = items['trayAction']!;
  final trayOpen = items['trayOpenSettingsAction']!;
  final startupEnable = items['startupEnableAction']!;
  final errors = items['errors']!;

  assert(lines.length == 16);
  assert(scan['id'] == 'realBleScan');
  assert(scan['label'] == 'Real BLE scan');
  assert(scan['status'] == 'observed');
  assert(scan['required'] == true);
  assert(lockedScan['status'] == 'missing');
  assert(tray['id'] == 'trayAction');
  assert(tray['status'] == 'observed');
  assert(trayOpen['status'] == 'observed');
  assert(startupEnable['status'] == 'missing');
  assert(errors['id'] == 'errors');
  assert(errors['status'] == 'none');
  assert(errors['required'] == false);
}

void testAcceptanceChecklistExportsEvidenceDetails() {
  final summary = AcceptanceSummary.fromState(
    state: const DashboardState(
      snapshot: DashboardSnapshot.initial(),
      devices: [],
      logs: [],
      config: ProximityConfig(),
    ),
    visibleLogs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 5),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -55 dBm',
        deviceId: 'band-1',
        rssi: -55,
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 7),
        category: DashboardLogCategory.action,
        message: 'Open settings requested',
        reason: 'trayAction',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 9),
        category: DashboardLogCategory.error,
        message: 'Bluetooth scan failed',
        reason: 'scannerStartFailed',
      ),
    ],
  );

  final items = {
    for (final item in summary.checklistItems) item.id: item.toDiagnosticJson(),
  };
  final scan = items['realBleScan']!;
  final trayOpen = items['trayOpenSettingsAction']!;
  final trayStart = items['trayStartMonitoringAction']!;
  final errors = items['errors']!;

  assert(scan['evidenceCount'] == 2);
  assert(scan['firstEvidenceAt'] == '2026-05-28T10:00:00.000Z');
  assert(scan['latestEvidenceAt'] == '2026-05-28T10:00:05.000Z');
  assert(trayOpen['evidenceCount'] == 1);
  assert(trayOpen['firstEvidenceAt'] == '2026-05-28T10:00:07.000Z');
  assert(trayOpen['latestEvidenceAt'] == '2026-05-28T10:00:07.000Z');
  assert(trayStart['evidenceCount'] == 0);
  assert(trayStart['firstEvidenceAt'] == null);
  assert(trayStart['latestEvidenceAt'] == null);
  assert(errors['status'] == 'observed');
  assert(errors['evidenceCount'] == 1);
  assert(errors['firstEvidenceAt'] == '2026-05-28T10:00:09.000Z');
  assert(errors['latestEvidenceAt'] == '2026-05-28T10:00:09.000Z');
}

void testAcceptanceChecklistTreatsWindowsAutoUnlockAsUnsupported() {
  final summary = AcceptanceSummary.fromState(
    state: const DashboardState(
      snapshot: DashboardSnapshot(
        platformLabel: 'Windows',
        monitoringStatus: 'Monitoring paused',
        stateLabel: 'Idle',
        bestRssi: null,
        selectedDeviceCount: 0,
        lastActionLabel: 'None',
        bluetoothCapabilityLabel: 'supported',
        autoLockCapabilityLabel: 'supported',
        wakeCapabilityLabel: 'supported',
        autoUnlockCapabilityLabel: 'unsupported',
        trayCapabilityLabel: 'supported',
        startupCapabilityLabel: 'supported',
        startupEnabled: false,
        autoUnlockSecretConfigured: false,
        autoUnlockSecretEditable: false,
        autoUnlockPermissionSettingsAvailable: false,
      ),
      devices: [],
      logs: [],
      config: ProximityConfig(enableMacAutoUnlock: false),
    ),
    visibleLogs: const [],
  );

  final macAutoUnlock = summary.checklistItems.firstWhere(
    (item) => item.id == 'macAutoUnlockAction',
  );

  assert(macAutoUnlock.status == 'unsupported');
  assert(macAutoUnlock.required == false);
  assert(summary.requiredChecklistCount == 15);
  assert(summary.completedRequiredChecklistCount == 1);
  assert(summary.checklistStatus('windowsV1Scope') == 'observed');
  assert(!summary.missingRequiredChecklistLabels
      .contains('macOS auto unlock action'));
}

void testAcceptanceChecklistTracksTrayMenuActionsSeparately() {
  final summary = AcceptanceSummary.fromState(
    state: const DashboardState(
      snapshot: DashboardSnapshot.initial(),
      devices: [],
      logs: [],
      config: ProximityConfig(),
    ),
    visibleLogs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10),
        category: DashboardLogCategory.action,
        message: 'Open settings requested',
        reason: 'trayAction',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 1),
        category: DashboardLogCategory.action,
        message: 'Monitoring started',
        reason: 'trayAction',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 2),
        category: DashboardLogCategory.action,
        message: 'Monitoring paused',
        reason: 'trayAction',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 3),
        category: DashboardLogCategory.action,
        message: 'Locked screen',
        reason: 'trayAction',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 4),
        category: DashboardLogCategory.action,
        message: 'Quit requested',
        reason: 'trayAction',
      ),
    ],
  );

  final checklist = summary.checklistMap;

  assert(checklist['trayOpenSettingsAction'] == 'observed');
  assert(checklist['trayStartMonitoringAction'] == 'observed');
  assert(checklist['trayPauseMonitoringAction'] == 'observed');
  assert(checklist['trayLockNowAction'] == 'observed');
  assert(checklist['trayQuitAction'] == 'observed');
}

void testAcceptanceChecklistTracksStartupEnableDisableSeparately() {
  final summary = AcceptanceSummary.fromState(
    state: const DashboardState(
      snapshot: DashboardSnapshot.initial(),
      devices: [],
      logs: [],
      config: ProximityConfig(),
    ),
    visibleLogs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10),
        category: DashboardLogCategory.action,
        message: 'Startup enabled',
        reason: 'startupChanged',
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 1),
        category: DashboardLogCategory.action,
        message: 'Startup disabled',
        reason: 'startupChanged',
      ),
    ],
  );

  final checklist = summary.checklistMap;

  assert(checklist['startupEnableAction'] == 'observed');
  assert(checklist['startupDisableAction'] == 'observed');
}

void testAcceptanceChecklistTracksWindowsV1ScopeSeparately() {
  final summary = AcceptanceSummary.fromState(
    state: const DashboardState(
      snapshot: DashboardSnapshot(
        platformLabel: 'Windows',
        monitoringStatus: 'Monitoring paused',
        stateLabel: 'Idle',
        bestRssi: null,
        selectedDeviceCount: 0,
        lastActionLabel: 'None',
        bluetoothCapabilityLabel: 'supported',
        autoLockCapabilityLabel: 'supported',
        wakeCapabilityLabel: 'supported',
        autoUnlockCapabilityLabel: 'unsupported',
        trayCapabilityLabel: 'supported',
        startupCapabilityLabel: 'supported',
        startupEnabled: false,
        autoUnlockSecretConfigured: false,
        autoUnlockSecretEditable: false,
        autoUnlockPermissionSettingsAvailable: false,
      ),
      devices: [],
      logs: [],
      config: ProximityConfig(enableMacAutoUnlock: false),
    ),
    visibleLogs: const [],
  );

  final checklist = summary.checklistMap;
  final windowsScope = summary.checklistItems.firstWhere(
    (item) => item.id == 'windowsV1Scope',
  );
  final windowsStep = summary.validationSteps.firstWhere(
    (step) => step.id == 'windowsV1Scope',
  );

  assert(summary.windowsV1ReadinessLabel ==
      'Windows v1 automatic unlock intentionally unsupported');
  assert(checklist['windowsV1Scope'] == 'observed');
  assert(windowsScope.required == true);
  assert(windowsStep.status == 'ready');
  assert(summary.requiredChecklistCount == 15);
  assert(summary.completedRequiredChecklistCount == 1);
  assert(!summary.missingRequiredChecklistLabels.contains('Windows v1 scope'));
}

void testStateExportsAcceptanceBundleJson() {
  final state = DashboardState(
    snapshot: const DashboardSnapshot(
      monitoringStatus: 'Monitoring',
      stateLabel: 'Locked',
      bestRssi: -52,
      selectedDeviceCount: 1,
      lastActionLabel: 'Locked screen',
      bluetoothCapabilityLabel: 'supported',
      autoLockCapabilityLabel: 'supported',
      wakeCapabilityLabel: 'supported',
      autoUnlockCapabilityLabel: 'missing secret',
      trayCapabilityLabel: 'supported',
      startupCapabilityLabel: 'supported',
      startupEnabled: true,
      autoUnlockSecretConfigured: false,
      autoUnlockSecretEditable: true,
      autoUnlockPermissionSettingsAvailable: true,
    ),
    devices: const [
      DashboardDeviceView(
        id: 'band-1',
        idLabel: 'ID band-1',
        name: 'Xiaomi Smart Band',
        rssiLabel: '-52 dBm',
        lastSeenLabel: 'Last seen 10:11:12',
        presenceLabel: 'Close',
        isSelected: true,
      ),
    ],
    logs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 12),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        platform: 'macOS',
        displayName: 'Xiaomi Smart Band',
        addressHint: 'AA:BB:CC:DD:EE:FF',
        deviceId: 'band-1',
        rssi: -52,
        reason: 'bleAdvertisement',
        manufacturerData: const [76, 0, 16, 5],
        sessionState: DashboardSessionState.locked,
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 11, 20),
        category: DashboardLogCategory.action,
        message: 'Locked screen',
        reason: 'proximityLock',
        sessionState: DashboardSessionState.locked,
      ),
    ],
    config: const ProximityConfig(
      minimumVisibleRssi: -92,
      unlockRssi: -55,
      lockRssi: -82,
      noSignalTimeout: Duration(seconds: 45),
      lockDelay: Duration(seconds: 7),
      unlockDeviceLogic: UnlockDeviceLogic.allClose,
      lockDeviceLogic: LockDeviceLogic.anyAway,
      wakeOnProximity: true,
      enableMacAutoUnlock: true,
      rssiWindowSize: 7,
    ),
  );

  final bundle = state.toAcceptanceBundleJson(
    visibleLogs: state.logs,
    externalValidationGates: const [
      {
        'id': 'windowsBuild',
        'label': 'Windows build verification',
        'status': 'passed',
        'action': 'Run flutter build windows on a Windows host.',
      },
      {
        'id': 'realBleScan',
        'label': 'Real BLE scan',
        'status': 'manualRequired',
        'action': 'Run the desktop app with a real BLE device.',
      },
      {
        'id': 'trayActions',
        'label': 'Tray actions',
        'status': 'failed',
        'action': 'Use every tray/menu action.',
      },
    ],
    exportedAt: DateTime.utc(2026, 5, 28, 10, 12),
    validationSessionId: 'manual-20260528-101200',
  );
  final snapshot = bundle['snapshot'] as Map<String, Object?>;
  final environment = bundle['environment'] as Map<String, Object?>;
  final acceptanceSummary = bundle['acceptanceSummary'] as Map<String, Object?>;
  final checklistItems = acceptanceSummary['checklistItems'] as List<Object?>;
  final config = bundle['config'] as Map<String, Object?>;
  final devices = bundle['devices'] as List<Object?>;
  final sessionDiagnostics = bundle['sessionDiagnostics'] as List<Object?>;
  final deviceDiagnostics = bundle['deviceDiagnostics'] as List<Object?>;
  final logs = bundle['logs'] as List<Object?>;
  final externalSummary =
      bundle['externalValidationGateSummary'] as Map<String, Object?>;
  final device = devices.single as Map<String, Object?>;
  final session = sessionDiagnostics.single as Map<String, Object?>;
  final diagnosticDevice = deviceDiagnostics.single as Map<String, Object?>;
  final scanLog = logs.first as Map<String, Object?>;

  assert(bundle['schemaVersion'] == 1);
  assert(bundle['validationSessionId'] == 'manual-20260528-101200');
  assert(bundle['exportedAt'] == '2026-05-28T10:12:00.000Z');
  assert(bundle['overallReadyForAcceptance'] == false);
  assert(bundle['overallAcceptanceBlockers'] == 15);
  assert(
    (bundle['overallAcceptanceBlockerLabels'] as List<Object?>)
        .contains('External gate failed: Tray actions'),
  );
  assert(environment['exportSource'] == 'dashboardState');
  assert(environment['platform'] == 'unknown');
  assert(environment['buildMode'] == 'unknown');
  assert(acceptanceSummary['visibleLogCount'] == 2);
  assert(acceptanceSummary['deviceCount'] == 1);
  assert(acceptanceSummary['selectedDeviceCount'] == 1);
  assert(acceptanceSummary['hasScanEvidence'] == true);
  assert(acceptanceSummary['hasLockedSessionScanEvidence'] == true);
  assert(acceptanceSummary['hasDecisionEvidence'] == false);
  assert(acceptanceSummary['hasActionEvidence'] == true);
  assert(acceptanceSummary['hasErrorEvidence'] == false);
  assert(acceptanceSummary['requiredChecklistCount'] == 15);
  assert(acceptanceSummary['completedRequiredChecklistCount'] == 2);
  assert(
    (acceptanceSummary['missingRequiredChecklistLabels'] as List<Object?>)
        .contains('Proximity decision'),
  );
  assert(
    (acceptanceSummary['missingRequiredChecklistLabels'] as List<Object?>)
        .contains('Tray open settings'),
  );
  assert(
    (acceptanceSummary['observedSessionStates'] as List<Object?>).single ==
        'locked',
  );
  assert(
    (acceptanceSummary['observedDeviceIds'] as List<Object?>).single ==
        'band-1',
  );
  assert(checklistItems.length == 16);
  assert(externalSummary['totalCount'] == 3);
  assert(externalSummary['passedCount'] == 1);
  assert(externalSummary['failedCount'] == 1);
  assert(externalSummary['manualRequiredCount'] == 1);
  assert(externalSummary['hasFailures'] == true);
  assert(externalSummary['allResolved'] == false);
  assert((checklistItems.first as Map<String, Object?>)['id'] == 'realBleScan');
  assert(
      (checklistItems.first as Map<String, Object?>)['status'] == 'observed');
  assert(
    checklistItems.any(
      (item) =>
          item is Map<String, Object?> &&
          item['id'] == 'trayLockNowAction' &&
          item['status'] == 'missing',
    ),
  );

  assert(snapshot['monitoringStatus'] == 'Monitoring');
  assert(snapshot['stateLabel'] == 'Locked');
  assert(snapshot['bestRssi'] == -52);
  assert(snapshot['startupEnabled'] == true);
  assert(snapshot['bluetoothCapabilityLabel'] == 'supported');
  assert(snapshot['autoUnlockCapabilityLabel'] == 'missing secret');
  assert(snapshot['autoUnlockPermissionSettingsAvailable'] == true);

  assert(config['minimumVisibleRssi'] == -92);
  assert(config['unlockRssi'] == -55);
  assert(config['lockRssi'] == -82);
  assert(config['noSignalTimeoutSeconds'] == 45);
  assert(config['lockDelaySeconds'] == 7);
  assert(config['unlockDeviceLogic'] == 'allClose');
  assert(config['lockDeviceLogic'] == 'anyAway');
  assert(config['wakeOnProximity'] == true);
  assert(config['enableMacAutoUnlock'] == true);
  assert(config['rssiWindowSize'] == 7);

  assert(device['id'] == 'band-1');
  assert(device['name'] == 'Xiaomi Smart Band');
  assert(device['isSelected'] == true);

  assert(session['sessionState'] == 'locked');
  assert(session['logCount'] == 2);
  assert(session['scanCount'] == 1);
  assert(session['scanObserved'] == true);
  assert(session['latestScanRssi'] == -52);
  assert(session['latestScanDeviceId'] == 'band-1');

  assert(diagnosticDevice['deviceId'] == 'band-1');
  assert(diagnosticDevice['seenCount'] == 1);
  assert(diagnosticDevice['latestRssi'] == -52);
  assert(diagnosticDevice['manufacturerDataHex'] == '4C001005');
  assert(diagnosticDevice['identityStatus'] == 'Stable identity');

  assert(logs.length == 2);
  assert(scanLog['timestamp'] == '2026-05-28T10:11:12.000Z');
  assert(scanLog['category'] == 'scan');
  assert(scanLog['sessionState'] == 'locked');
  assert(scanLog['manufacturerDataHex'] == '4C001005');
}

void testStateExportsRunbookBundleJson() {
  final state = DashboardState(
    snapshot: const DashboardSnapshot(
      monitoringStatus: 'Monitoring',
      stateLabel: 'Locked',
      bestRssi: -52,
      selectedDeviceCount: 1,
      lastActionLabel: 'Open settings requested',
      bluetoothCapabilityLabel: 'supported',
      autoLockCapabilityLabel: 'supported',
      wakeCapabilityLabel: 'supported',
      autoUnlockCapabilityLabel: 'supported',
      trayCapabilityLabel: 'supported',
      startupCapabilityLabel: 'supported',
      startupEnabled: true,
      autoUnlockSecretConfigured: true,
      autoUnlockSecretEditable: true,
      autoUnlockPermissionSettingsAvailable: false,
    ),
    devices: const [
      DashboardDeviceView(
        id: 'band-1',
        idLabel: 'ID band-1',
        name: 'Xiaomi Smart Band',
        rssiLabel: '-52 dBm',
        lastSeenLabel: 'Last seen 10:11:12',
        presenceLabel: 'Close',
        isSelected: true,
      ),
    ],
    logs: [
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10),
        category: DashboardLogCategory.scan,
        message: 'Scan band-1 -52 dBm',
        deviceId: 'band-1',
        rssi: -52,
        sessionState: DashboardSessionState.locked,
      ),
      DashboardLogEntry(
        timestamp: DateTime.utc(2026, 5, 28, 10, 0, 1),
        category: DashboardLogCategory.decision,
        message: 'Decision close',
        reason: 'close',
      ),
    ],
    config: const ProximityConfig(enableMacAutoUnlock: true),
  );

  final bundle = state.toRunbookBundleJson(
    visibleLogs: state.logs,
    externalValidationGates: const [
      {
        'id': 'windowsBuild',
        'label': 'Windows build verification',
        'status': 'passed',
        'action': 'Run flutter build windows on a Windows host.',
      },
      {
        'id': 'realBleScan',
        'label': 'Real BLE scan',
        'status': 'manualRequired',
        'action': 'Run the desktop app with a real BLE device.',
      },
    ],
    exportedAt: DateTime.utc(2026, 5, 28, 10, 12),
    validationSessionId: 'manual-20260528-101200',
  );
  final environment = bundle['environment'] as Map<String, Object?>;
  final summary = bundle['acceptanceSummary'] as Map<String, Object?>;
  final runbookSteps = bundle['runbookSteps'] as List<Object?>;
  final missingRunbookSteps = bundle['missingRunbookSteps'] as List<Object?>;
  final runbookJsonLines = bundle['runbookJsonLines'] as String;
  final missingRunbookJsonLines = bundle['missingRunbookJsonLines'] as String;
  final missingActionList = bundle['missingActionList'] as String;
  final externalSummary =
      bundle['externalValidationGateSummary'] as Map<String, Object?>;
  final firstStep = runbookSteps.first as Map<String, Object?>;
  final firstLine =
      jsonDecode(runbookJsonLines.split('\n').first) as Map<String, Object?>;
  final firstMissingLine = jsonDecode(missingRunbookJsonLines.split('\n').first)
      as Map<String, Object?>;

  assert(bundle['schemaVersion'] == 1);
  assert(bundle['bundleType'] == 'validationRunbook');
  assert(bundle['validationSessionId'] == 'manual-20260528-101200');
  assert(bundle['exportedAt'] == '2026-05-28T10:12:00.000Z');
  assert(bundle['overallReadyForAcceptance'] == false);
  assert(bundle['overallAcceptanceBlockers'] == 13);
  assert(
    (bundle['overallAcceptanceBlockerLabels'] as List<Object?>)
        .contains('Runtime evidence missing: Auto lock action'),
  );
  assert(
    (bundle['overallAcceptanceBlockerLabels'] as List<Object?>)
        .contains('External gate pending: Real BLE scan'),
  );
  assert(environment['exportSource'] == 'dashboardState');
  assert(summary['readyForAcceptance'] == false);
  assert(externalSummary['totalCount'] == 2);
  assert(externalSummary['passedCount'] == 1);
  assert(externalSummary['manualRequiredCount'] == 1);
  assert(runbookSteps.length == 5);
  assert(missingRunbookSteps.length == 4);
  assert(missingActionList.split('\n').length == 4);
  assert(firstStep['id'] == 'bleScan');
  assert(firstStep['status'] == 'ready');
  assert(firstStep['action'] == 'Scan nearby selected BLE devices');
  assert(
      firstLine['expectedEvidence'] == 'Real BLE scan, locked scan, decision');
  assert(firstMissingLine['id'] == 'lockWake');
  assert((firstMissingLine['nextActionHint'] as String)
      .contains('Move the selected device away'));
  assert(missingActionList.contains('Lock and wake: Move'));
}

void testDeviceViewFormatsPlatformIdShortCode() {
  final view = DashboardDeviceView.fromDevice(
    device: const BleDevice(
      platformId: '12345678-1234-5678-90AB-1234567890AB',
    ),
    presence: null,
  );

  assert(view.id == '12345678-1234-5678-90AB-1234567890AB');
  assert(view.idLabel == 'ID 12345678...90AB');

  final short = DashboardDeviceView.fromDevice(
    device: const BleDevice(platformId: 'band-1'),
    presence: null,
  );

  assert(short.idLabel == 'ID band-1');
}
