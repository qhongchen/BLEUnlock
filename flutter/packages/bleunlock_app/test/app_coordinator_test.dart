import 'dart:async';
import 'dart:convert';

import 'package:bleunlock_app/src/controllers/app_coordinator.dart';
import 'package:bleunlock_app/src/platforms/mock_bleunlock_platform.dart';
import 'package:bleunlock_app/src/settings/app_settings_repository.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_core/bleunlock_core.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

Future<void> main() async {
  await testCoordinatorStartsScannerAndReflectsCloseDevice();
  await testCoordinatorExportsDiagnosticLogs();
  await testCoordinatorSamplesScanLogsByDevice();
  await testCoordinatorLogsDecisionReasonTransitionsOnly();
  await testCoordinatorMarksScanLogsWithSessionState();
  await testCoordinatorLogsDeviceStateReasons();
  await testCoordinatorLocksWhenSelectedDeviceStaysAway();
  await testCoordinatorLocksWhenVisibleSelectedDeviceIsAwayWithStaleSelection();
  await testCoordinatorHandlesUnsupportedUnlockWithoutCallingPlatform();
  await testCoordinatorSkipsAutomaticUnlockWhenSessionIsNotLocked();
  await testCoordinatorKeepsLastActionStableWhenUnlockedDeviceStaysClose();
  await testCoordinatorDoesNotShowWakeThrottleWhenUnlockedDeviceStaysClose();
  await testCoordinatorScansBeforeSelectionButRequiresDeviceForMonitoring();
  await testCoordinatorThrottlesDeviceListRefreshes();
  await testCoordinatorRefreshesDeviceListOnDemand();
  await testCoordinatorKeepsStableDeviceNameAcrossNamelessPackets();
  await testCoordinatorRemovesExpiredUnselectedDiscoveryDevices();
  await testCoordinatorPausesMonitoringWhenLastDeviceIsUnselected();
  await testCoordinatorAutomaticallyTicksWhileMonitoring();
  await testCoordinatorAutomaticallyLocksWhenSignalIsLost();
  await testCoordinatorBlocksMonitoringWhenScannerIsUnavailable();
  await testCoordinatorLogsScannerStartFailures();
  await testCoordinatorLogsScannerEventStreamFailures();
  await testCoordinatorLoadsPersistedSettings();
  await testCoordinatorSavesRuleAndSelectionChanges();
  await testCoordinatorRequiresAcknowledgementBeforeEnablingMacAutoUnlock();
  await testCoordinatorRejectsMacAutoUnlockWhenUnsupported();
  await testCoordinatorUpdatesRulesAndRebuildsEngine();
  await testCoordinatorRefreshesStartupStatus();
  await testCoordinatorThrottlesRepeatedCapabilityRefreshes();
  await testCoordinatorLogsSessionEventStreamFailures();
  await testCoordinatorRetriesCapabilityCheckFromSystemAction();
  await testCoordinatorOpensMacAutoUnlockPermissionSettings();
  await testCoordinatorAllowsPasswordEntryWhenUnlockSecretIsMissing();
  await testCoordinatorRefreshesScannerCapabilityBeforeMonitoring();
  await testCoordinatorTogglesStartupStatus();
  await testCoordinatorLogsStartupUpdateFailures();
  await testCoordinatorStoresAndClearsMacAutoUnlockPassword();
  await testCoordinatorRefreshesUnlockCapabilityAfterPasswordChanges();
  await testCoordinatorPublishesTrayStatus();
  await testCoordinatorLogsTrayStatusFailures();
  await testCoordinatorLogsTrayActionStreamFailures();
  await testCoordinatorEmitsAppCommandsForTrayRequests();
  await testCoordinatorHandlesTrayMonitoringActions();
  await testCoordinatorHandlesTrayLockAction();
  await testCoordinatorReportsUnavailableManualLock();
  await testCoordinatorReportsUnavailableTrayLockAction();
  await testCoordinatorLogsManualLockFailures();
  await testCoordinatorSubscribesSessionEventsForManualLock();
  await testCoordinatorPollsSessionStateWhenUnlockEventIsMissed();
  await testCoordinatorRefreshesSettingsAfterSystemWake();
  await testCoordinatorReflectsLockSessionEvents();
  await testCoordinatorAnnotatesSessionEventLogsWithSessionState();
  await testCoordinatorThrottlesRepeatedLockActions();
  await testCoordinatorAutoLocksAfterStaleLockedUiStateClears();
  await testCoordinatorSkipsRepeatedProximityLockWhenAlreadyLocked();
  await testCoordinatorThrottlesRepeatedUnlockActions();
  await testCoordinatorThrottlesRepeatedUnlockFailures();
  await testCoordinatorLogsAutomaticUnlockFailures();
  await testCoordinatorRetriesUnlockWhenSessionRemainsLocked();
  await testCoordinatorRetriesStillLockedUnlockFailures();
  await testCoordinatorDelaysUnlockBrieflyAfterWakeRequest();
  await testCoordinatorSuppressesAutoUnlockAfterManualLockUntilDeviceLeaves();
  await testCoordinatorSuppressesRepeatedWakeUnlockAfterUnlockFailure();
  await testCoordinatorLogsUnlockRetrySkipWhenSessionUnlocksBeforeRetry();
  await testCoordinatorLogsUnlockRetrySkipWhenLockStateTurnsUnlockedSilently();
  await testCoordinatorLogsUnlockRetrySkipWhenUnlockBecomesUnavailable();
  await testCoordinatorLogsUnlockRetrySkipWhenSessionBecomesUnavailable();
}

Future<void>
    testCoordinatorSuppressesAutoUnlockAfterManualLockUntilDeviceLeaves() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      wakeOnProximity: true,
      rssiWindowSize: 1,
      lockDelay: Duration(seconds: 1),
    ),
    selectedDeviceIds: {'band-1'},
    actionThrottleWindow: Duration.zero,
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();
  assert(platform.mockUnlock.unlockCount == 0);

  await coordinator.lockNow();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -44,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockSession.wakeCount == 0);
  assert(platform.mockUnlock.unlockCount == 0);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.message == 'Auto unlock suspended' &&
          entry.reason == 'manualLock',
    ),
  );

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -90,
      seenAt: DateTime(2026, 5, 28, 10, 0, 2),
    ),
  );
  await pumpEventQueue();
  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 3));
  await pumpEventQueue();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10, 0, 4),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockSession.wakeCount == 1);
  assert(platform.mockUnlock.unlockCount == 1);

  await coordinator.dispose();
}

Future<void>
    testCoordinatorSuppressesRepeatedWakeUnlockAfterUnlockFailure() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  platform.mockUnlock.unlockResult =
      const UnlockResult(success: false, reason: 'stillLocked');
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      wakeOnProximity: true,
      rssiWindowSize: 1,
      lockDelay: Duration(seconds: 1),
    ),
    selectedDeviceIds: {'band-1'},
    actionThrottleWindow: Duration.zero,
    unlockRetryLimit: 0,
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockSession.wakeCount == 1);
  assert(platform.mockUnlock.unlockCount == 1);

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -44,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockSession.wakeCount == 1);
  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.message == 'Auto unlock suspended' &&
          entry.reason == 'unlockFailed',
    ),
  );

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -90,
      seenAt: DateTime(2026, 5, 28, 10, 0, 2),
    ),
  );
  await pumpEventQueue();
  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 3));
  await pumpEventQueue();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10, 0, 4),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockSession.wakeCount == 2);
  assert(platform.mockUnlock.unlockCount == 2);

  await coordinator.dispose();
}

Future<void> testCoordinatorSamplesScanLogsByDevice() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.startScanning();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -50,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -51,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -52,
      seenAt: DateTime(2026, 5, 28, 10, 0, 4),
    ),
  );
  await pumpEventQueue();

  var scanLogs = coordinator.value.logs
      .where((entry) => entry.category == DashboardLogCategory.scan)
      .toList();
  assert(scanLogs.length == 1);
  assert(scanLogs.single.rssi == -50);

  coordinator.refreshDeviceList();
  assert(coordinator.value.devices.single.rssiLabel == '-52 dBm');

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -53,
      seenAt: DateTime(2026, 5, 28, 10, 0, 6),
    ),
  );
  await pumpEventQueue();

  scanLogs = coordinator.value.logs
      .where((entry) => entry.category == DashboardLogCategory.scan)
      .toList();
  assert(scanLogs.length == 2);
  assert(scanLogs.first.rssi == -53);

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -59,
      seenAt: DateTime(2026, 5, 28, 10, 0, 7),
    ),
  );
  await pumpEventQueue();

  scanLogs = coordinator.value.logs
      .where((entry) => entry.category == DashboardLogCategory.scan)
      .toList();
  assert(scanLogs.length == 3);
  assert(scanLogs.first.rssi == -59);

  await coordinator.dispose();
}

Future<void> testCoordinatorLogsDecisionReasonTransitionsOnly() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'weak-1',
      rssi: -95,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'weak-2',
      rssi: -96,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'visible-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10, 0, 2),
    ),
  );
  await pumpEventQueue();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'visible-2',
      rssi: -44,
      seenAt: DateTime(2026, 5, 28, 10, 0, 3),
    ),
  );
  await pumpEventQueue();

  final decisionReasons = coordinator.value.logs
      .where(
        (entry) =>
            entry.category == DashboardLogCategory.decision &&
            entry.deviceId == null &&
            entry.message.startsWith('Decision '),
      )
      .map((entry) => entry.reason)
      .toList()
      .reversed
      .toList();

  assert(decisionReasons.length == 2);
  assert(decisionReasons[0] == 'belowVisibleThreshold');
  assert(decisionReasons[1] == 'unmonitored');

  await coordinator.dispose();
}

Future<void> testCoordinatorLogsDeviceStateReasons() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      lockDelay: Duration(seconds: 5),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -55,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.decision &&
          entry.platform == 'mock' &&
          entry.deviceId == 'band-1' &&
          entry.rssi == -55 &&
          entry.reason == 'rssiAboveUnlockThreshold',
    ),
  );

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -90,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();
  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 6));
  await pumpEventQueue();

  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.decision &&
          entry.deviceId == 'band-1' &&
          entry.reason == 'rssiBelowLockThresholdForDelay',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorExportsDiagnosticLogs() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(rssiWindowSize: 1),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Xiaomi Smart Band',
      addressHint: 'AA:BB:CC:DD:EE:FF',
      rssi: -55,
      seenAt: DateTime.utc(2026, 5, 28, 10),
      manufacturerData: const [76, 0, 16, 5],
      rawAdvertisement: const {
        'localName': 'Xiaomi Smart Band',
        'manufacturerDataSections': [
          {
            'companyId': 76,
            'companyIdHex': '0x004C',
            'dataHex': '1005',
            'payloadHex': '4C001005',
          },
        ],
      },
    ),
  );
  await pumpEventQueue();

  final decoded = coordinator.diagnosticLogJsonLines
      .split('\n')
      .map((line) => jsonDecode(line) as Map<String, Object?>)
      .toList();

  assert(decoded.any(
    (entry) =>
        entry['category'] == 'scan' &&
        entry['deviceId'] == 'band-1' &&
        entry['displayName'] == 'Xiaomi Smart Band' &&
        entry['addressHint'] == 'AA:BB:CC:DD:EE:FF' &&
        entry['rssi'] == -55 &&
        entry['reason'] == 'bleAdvertisement' &&
        entry['manufacturerDataHex'] == '4C001005' &&
        (entry['rawAdvertisement'] as Map<String, Object?>)['localName'] ==
            'Xiaomi Smart Band',
  ));
  assert(decoded.any(
    (entry) =>
        entry['category'] == 'decision' &&
        entry['deviceId'] == 'band-1' &&
        entry['reason'] == 'rssiAboveUnlockThreshold',
  ));

  await coordinator.dispose();
}

Future<void> testCoordinatorMarksScanLogsWithSessionState() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(rssiWindowSize: 1),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.refreshSystemSettings();
  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -55,
      seenAt: DateTime.utc(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  platform.mockSession.emitEvent(
    SessionEvent(
      kind: SessionEventKind.locked,
      timestamp: DateTime.utc(2026, 5, 28, 10, 0, 1),
      reason: 'screenLocked',
    ),
  );
  await pumpEventQueue();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -56,
      seenAt: DateTime.utc(2026, 5, 28, 10, 0, 6),
    ),
  );
  await pumpEventQueue();

  final scanLogs = coordinator.value.logs
      .where((entry) => entry.category == DashboardLogCategory.scan)
      .toList();

  assert(scanLogs.length == 2);
  assert(scanLogs.any(
    (entry) => entry.sessionState == DashboardSessionState.locked,
  ));
  assert(scanLogs.any(
    (entry) => entry.sessionState == DashboardSessionState.unlocked,
  ));

  final decoded = coordinator.diagnosticLogJsonLines
      .split('\n')
      .map((line) => jsonDecode(line) as Map<String, Object?>)
      .where((entry) => entry['category'] == 'scan')
      .toList();

  assert(decoded.any((entry) => entry['sessionState'] == 'locked'));
  assert(decoded.any((entry) => entry['sessionState'] == 'unlocked'));

  await coordinator.dispose();
}

Future<void> testCoordinatorStartsScannerAndReflectsCloseDevice() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(enableMacAutoUnlock: true),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Xiaomi Smart Band',
      rssi: -48,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  final state = coordinator.value;
  assert(platform.mockScanner.isScanning);
  assert(state.snapshot.monitoringStatus == 'Monitoring');
  assert(state.snapshot.stateLabel == 'Close');
  assert(state.snapshot.bestRssi == -48);
  assert(state.snapshot.selectedDeviceCount == 1);
  assert(state.devices.length == 1);
  assert(state.devices.single.name == 'Xiaomi Smart Band');
  assert(state.devices.single.presenceLabel == 'Close');
  assert(state.logs.any((entry) => entry.message.contains('band-1')));
  assert(
      state.logs.any((entry) => entry.category == DashboardLogCategory.scan));
  assert(
    state.logs.any((entry) => entry.category == DashboardLogCategory.decision),
  );
  assert(state.logs.any((entry) => entry.deviceId == 'band-1'));

  await coordinator.dispose();
}

Future<void> testCoordinatorLocksWhenSelectedDeviceStaysAway() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      lockDelay: Duration(seconds: 5),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -86,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 5));
  await pumpEventQueue();

  final state = coordinator.value;
  assert(platform.mockSession.lockCount == 1);
  assert(state.snapshot.stateLabel == 'Locked');
  assert(state.snapshot.lastActionLabel == 'Locked screen');
  assert(state.logs.any((entry) => entry.message == 'Locked screen'));
  assert(
      state.logs.any((entry) => entry.category == DashboardLogCategory.action));

  await coordinator.dispose();
}

Future<void>
    testCoordinatorLocksWhenVisibleSelectedDeviceIsAwayWithStaleSelection() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      lockDelay: Duration(seconds: 5),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1', 'stale-history-device'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -55,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -86,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();

  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 6));
  await pumpEventQueue();

  assert(platform.mockSession.lockCount == 1);
  assert(coordinator.value.snapshot.lastActionLabel == 'Locked screen');
  assert(coordinator.value.snapshot.stateLabel == 'Locked');

  await coordinator.dispose();
}

Future<void>
    testCoordinatorHandlesUnsupportedUnlockWithoutCallingPlatform() async {
  final platform = MockBleunlockPlatform(
    unlockCapability: const CapabilityStatus.unsupported(),
  );
  platform.mockSession.locked = true;
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(enableMacAutoUnlock: true),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  final state = coordinator.value;
  assert(platform.mockUnlock.unlockCount == 0);
  assert(state.snapshot.lastActionLabel == 'Unlock unsupported');
  assert(
    state.logs.any(
      (entry) =>
          entry.reason == 'unsupported' &&
          entry.message.contains('unsupported'),
    ),
  );
  assert(
    state.logs.any(
      (entry) =>
          entry.reason == 'unsupported' &&
          entry.category == DashboardLogCategory.action,
    ),
  );
  assert(
    state.logs.every(
      (entry) =>
          entry.reason != 'unsupported' ||
          entry.category != DashboardLogCategory.error,
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorSkipsAutomaticUnlockWhenSessionIsNotLocked() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 0);
  assert(coordinator.value.snapshot.lastActionLabel == 'Monitoring started');
  assert(
    coordinator.value.logs.every(
      (entry) => entry.reason != 'sessionNotLocked',
    ),
  );

  await coordinator.dispose();
}

Future<void>
    testCoordinatorKeepsLastActionStableWhenUnlockedDeviceStaysClose() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 0);
  assert(coordinator.value.snapshot.lastActionLabel == 'Monitoring started');
  assert(
    coordinator.value.logs.every(
      (entry) => entry.reason != 'sessionNotLocked',
    ),
  );

  await coordinator.dispose();
}

Future<void>
    testCoordinatorDoesNotShowWakeThrottleWhenUnlockedDeviceStaysClose() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      wakeOnProximity: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -44,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockSession.wakeCount == 0);
  assert(platform.mockUnlock.unlockCount == 0);
  assert(coordinator.value.snapshot.lastActionLabel == 'Monitoring started');
  assert(
    coordinator.value.logs.every(
      (entry) => entry.reason != 'actionThrottled',
    ),
  );
  assert(
    coordinator.value.logs.every(
      (entry) => entry.reason != 'sessionNotLocked',
    ),
  );

  await coordinator.dispose();
}

Future<void>
    testCoordinatorScansBeforeSelectionButRequiresDeviceForMonitoring() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.startMonitoring();
  assert(!platform.mockScanner.isScanning);
  assert(coordinator.value.snapshot.monitoringStatus == 'Monitoring paused');
  assert(coordinator.value.snapshot.lastActionLabel == 'Select a device first');

  await coordinator.startScanning();
  assert(platform.mockScanner.isScanning);
  assert(coordinator.value.snapshot.monitoringStatus == 'Scanning');

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Xiaomi Smart Band',
      rssi: -52,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();
  assert(!coordinator.value.devices.single.isSelected);

  coordinator.setDeviceSelected('band-1', true);
  await coordinator.startMonitoring();
  await pumpEventQueue();

  final state = coordinator.value;
  assert(platform.mockScanner.isScanning);
  assert(state.snapshot.monitoringStatus == 'Monitoring');
  assert(state.snapshot.selectedDeviceCount == 1);
  assert(state.devices.single.isSelected);

  await coordinator.dispose();
}

Future<void> testCoordinatorThrottlesDeviceListRefreshes() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    deviceListRefreshInterval: const Duration(milliseconds: 50),
  );

  await coordinator.startScanning();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Band',
      rssi: -80,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();
  assert(coordinator.value.devices.single.rssiLabel == '-80 dBm');

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Band',
      rssi: -40,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();
  assert(coordinator.value.devices.single.rssiLabel == '-80 dBm');

  await Future<void>.delayed(const Duration(milliseconds: 80));
  await pumpEventQueue();
  assert(coordinator.value.devices.single.rssiLabel == '-40 dBm');

  await coordinator.dispose();
}

Future<void> testCoordinatorRefreshesDeviceListOnDemand() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    deviceListRefreshInterval: const Duration(seconds: 5),
  );

  await coordinator.startScanning();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Band',
      rssi: -80,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Band',
      rssi: -40,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();
  assert(coordinator.value.devices.single.rssiLabel == '-80 dBm');

  coordinator.refreshDeviceList();
  await pumpEventQueue();
  assert(coordinator.value.devices.single.rssiLabel == '-40 dBm');

  await coordinator.dispose();
}

Future<void> testCoordinatorKeepsStableDeviceNameAcrossNamelessPackets() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    deviceListRefreshInterval: const Duration(milliseconds: 10),
  );

  await coordinator.startScanning();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Xiaomi Smart Band',
      addressHint: 'AA:BB:CC:DD:EE:FF',
      rssi: -46,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();
  assert(coordinator.value.devices.single.name == 'Xiaomi Smart Band');

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: '',
      addressHint: 'band-1',
      rssi: -44,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await pumpEventQueue();

  final device = coordinator.value.devices.single;
  assert(device.name == 'Xiaomi Smart Band');
  assert(device.idLabel == 'ID band-1');
  assert(device.rssiLabel == '-44 dBm');

  await coordinator.dispose();
}

Future<void> testCoordinatorRemovesExpiredUnselectedDiscoveryDevices() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(noSignalTimeout: Duration(seconds: 60)),
    deviceListRefreshInterval: const Duration(seconds: 5),
  );

  await coordinator.startScanning();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'anonymous-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();
  assert(coordinator.value.devices.length == 1);

  platform.emitScan(
    BleScanEvent(
      deviceId: 'named-1',
      displayName: 'Xiaomi Smart Band',
      rssi: -48,
      seenAt: DateTime(2026, 5, 28, 10, 1),
    ),
  );
  await pumpEventQueue();

  final devices = coordinator.value.devices;
  assert(devices.length == 1);
  assert(devices.single.id == 'named-1');
  assert(devices.single.name == 'Xiaomi Smart Band');

  await coordinator.dispose();
}

Future<void> testCoordinatorPausesMonitoringWhenLastDeviceIsUnselected() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Xiaomi Smart Band',
      rssi: -52,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockScanner.isScanning);
  assert(coordinator.value.snapshot.monitoringStatus == 'Monitoring');
  assert(coordinator.value.devices.single.isSelected);

  coordinator.setDeviceSelected('band-1', false);
  await pumpEventQueue();

  assert(!platform.mockScanner.isScanning);
  assert(coordinator.value.snapshot.monitoringStatus == 'Monitoring paused');
  assert(coordinator.value.snapshot.selectedDeviceCount == 0);
  assert(!coordinator.value.devices.single.isSelected);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.message == 'Monitoring paused' &&
          entry.reason == 'deviceSelectionChanged',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorAutomaticallyTicksWhileMonitoring() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      lockDelay: Duration(milliseconds: 1),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
    tickInterval: const Duration(milliseconds: 1),
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -86,
      seenAt: DateTime.now().subtract(const Duration(milliseconds: 5)),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 20));

  assert(platform.mockSession.lockCount == 1);
  assert(coordinator.value.snapshot.lastActionLabel == 'Locked screen');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.decision &&
          entry.reason == 'rssiBelowLockThresholdForDelay',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorAutomaticallyLocksWhenSignalIsLost() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      noSignalTimeout: Duration(milliseconds: 1),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
    tickInterval: const Duration(milliseconds: 1),
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -55,
      seenAt: DateTime.now().subtract(const Duration(milliseconds: 5)),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 20));

  assert(platform.mockSession.lockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.decision &&
          entry.reason == 'noSignalTimeout',
    ),
  );
  assert(coordinator.value.devices.single.presenceLabel == 'Lost');

  await coordinator.dispose();
}

Future<void> testCoordinatorBlocksMonitoringWhenScannerIsUnavailable() async {
  final platform = MockBleunlockPlatform(
    scannerCapability: const CapabilityStatus.poweredOff('Bluetooth off'),
  );
  final coordinator = AppCoordinator(
    platform: platform,
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.startMonitoring();

  final state = coordinator.value;
  assert(!platform.mockScanner.isScanning);
  assert(state.snapshot.monitoringStatus == 'Monitoring paused');
  assert(state.snapshot.bluetoothCapabilityLabel == 'Bluetooth off');
  assert(state.snapshot.lastActionLabel == 'Bluetooth scanning unavailable');
  assert(
      state.logs.any((entry) => entry.category == DashboardLogCategory.error));
  assert(state.logs.any((entry) => entry.reason == 'scannerUnavailable'));
  assert(
    state.logs.any(
      (entry) =>
          entry.reason == 'scannerUnavailable' &&
          entry.message.contains('Bluetooth off'),
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorLogsScannerStartFailures() async {
  final platform = MockBleunlockPlatform();
  platform.mockScanner.startScanError = Exception('Native BLE start failed');
  final coordinator = AppCoordinator(
    platform: platform,
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.startMonitoring();

  assert(!platform.mockScanner.isScanning);
  assert(coordinator.value.snapshot.monitoringStatus == 'Monitoring paused');
  assert(
    coordinator.value.snapshot.lastActionLabel == 'Bluetooth scan start failed',
  );
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.error &&
          entry.reason == 'scannerStartFailed' &&
          entry.message.contains('Native BLE start failed'),
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorLogsScannerEventStreamFailures() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.mockScanner.emitError(Exception('Native BLE event failed'));
  await pumpEventQueue();

  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.error &&
          entry.reason == 'scannerEventFailed' &&
          entry.message.contains('Native BLE event failed'),
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorLoadsPersistedSettings() async {
  final platform = MockBleunlockPlatform();
  final repository = InMemoryAppSettingsRepository(
    initialSettings: const AppSettings(
      config: ProximityConfig(
        unlockRssi: -48,
        lockRssi: -82,
        rssiWindowSize: 1,
      ),
      selectedDeviceIds: {'band-1'},
    ),
  );
  final coordinator = AppCoordinator(
    platform: platform,
    settingsRepository: repository,
  );

  await coordinator.loadSettings();

  assert(coordinator.value.config.unlockRssi == -48);
  assert(coordinator.value.config.lockRssi == -82);
  assert(coordinator.value.snapshot.selectedDeviceCount == 1);

  await coordinator.startScanning();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Xiaomi Smart Band',
      rssi: -50,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(coordinator.value.devices.single.isSelected);

  await coordinator.dispose();
}

Future<void> testCoordinatorSavesRuleAndSelectionChanges() async {
  final platform = MockBleunlockPlatform();
  final repository = InMemoryAppSettingsRepository();
  final coordinator = AppCoordinator(
    platform: platform,
    settingsRepository: repository,
  );

  coordinator.updateConfig(
    coordinator.config.copyWith(
      unlockRssi: -49,
      wakeOnProximity: true,
    ),
  );
  await pumpEventQueue();

  assert(repository.savedSettings!.config.unlockRssi == -49);
  assert(repository.savedSettings!.config.wakeOnProximity == true);

  coordinator.setDeviceSelected('band-1', true);
  await pumpEventQueue();

  assert(repository.savedSettings!.selectedDeviceIds.contains('band-1'));

  await coordinator.dispose();
}

Future<void>
    testCoordinatorRequiresAcknowledgementBeforeEnablingMacAutoUnlock() async {
  final platform = MockBleunlockPlatform(platformLabel: 'macOS');
  final coordinator = AppCoordinator(platform: platform);

  coordinator.updateConfig(
    coordinator.config.copyWith(enableMacAutoUnlock: true),
  );

  assert(coordinator.value.config.enableMacAutoUnlock == false);
  assert(coordinator.value.snapshot.lastActionLabel ==
      'Auto unlock confirmation required');
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'macAutoUnlockConfirmationRequired',
    ),
  );

  coordinator.updateConfig(
    coordinator.config.copyWith(enableMacAutoUnlock: true),
    acknowledgeMacAutoUnlockRisk: true,
  );

  assert(coordinator.value.config.enableMacAutoUnlock == true);

  await coordinator.dispose();
}

Future<void> testCoordinatorRejectsMacAutoUnlockWhenUnsupported() async {
  final platform = MockBleunlockPlatform(
    unlockCapability: const CapabilityStatus.unsupported(),
  );
  final coordinator = AppCoordinator(platform: platform);

  coordinator.updateConfig(
    coordinator.config.copyWith(enableMacAutoUnlock: true),
    acknowledgeMacAutoUnlockRisk: true,
  );

  assert(coordinator.value.config.enableMacAutoUnlock == false);
  assert(
      coordinator.value.snapshot.lastActionLabel == 'Auto unlock unavailable');
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'macAutoUnlockUnavailable',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorUpdatesRulesAndRebuildsEngine() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(rssiWindowSize: 1),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -58,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();
  assert(coordinator.value.snapshot.stateLabel == 'Close');

  final updatedConfig = coordinator.config.copyWith(
    unlockRssi: -40,
    lockRssi: -85,
    unlockDeviceLogic: UnlockDeviceLogic.allClose,
    lockDeviceLogic: LockDeviceLogic.anyAway,
    wakeOnProximity: true,
  );

  coordinator.updateConfig(updatedConfig);

  assert(coordinator.value.config.unlockRssi == -40);
  assert(coordinator.value.config.lockRssi == -85);
  assert(
      coordinator.value.config.unlockDeviceLogic == UnlockDeviceLogic.allClose);
  assert(coordinator.value.config.lockDeviceLogic == LockDeviceLogic.anyAway);
  assert(coordinator.value.config.wakeOnProximity == true);
  assert(coordinator.value.snapshot.lastActionLabel == 'Rules updated');
  assert(
      coordinator.value.logs.any((entry) => entry.reason == 'configChanged'));

  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -58,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();

  assert(coordinator.value.snapshot.stateLabel == 'Idle');

  await coordinator.dispose();
}

Future<void> testCoordinatorRefreshesStartupStatus() async {
  final platform = MockBleunlockPlatform();
  platform.mockStartup.enabled = true;
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();

  assert(coordinator.value.snapshot.startupEnabled == true);
  assert(coordinator.value.snapshot.startupCapabilityLabel == 'supported');
  assert(coordinator.value.snapshot.trayCapabilityLabel == 'supported');
  assert(platform.mockScanner.refreshCapabilityCount == 1);
  assert(platform.mockUnlock.refreshCapabilityCount == 1);

  await coordinator.dispose();
}

Future<void> testCoordinatorLogsSessionEventStreamFailures() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();
  platform.mockSession.emitError(Exception('Native session event failed'));
  await pumpEventQueue();

  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.error &&
          entry.reason == 'sessionEventStreamFailed' &&
          entry.message.contains('Native session event failed'),
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorThrottlesRepeatedCapabilityRefreshes() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    capabilityRefreshThrottle: const Duration(hours: 1),
  );

  await coordinator.refreshSystemSettings();
  await coordinator.refreshSystemSettings();

  assert(platform.mockScanner.refreshCapabilityCount == 1);
  assert(platform.mockUnlock.refreshCapabilityCount == 1);

  await coordinator.retryCapabilityCheck();

  assert(platform.mockScanner.refreshCapabilityCount == 2);
  assert(platform.mockUnlock.refreshCapabilityCount == 2);
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'capabilityRetry',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorRetriesCapabilityCheckFromSystemAction() async {
  final platform = MockBleunlockPlatform(
    scannerCapability: const CapabilityStatus.poweredOff('Bluetooth off'),
    unlockCapability: const CapabilityStatus.permissionDenied(
      'Accessibility permission denied',
    ),
  );
  platform.mockStartup.enabled = true;
  platform.mockScanner.refreshedCapability = const CapabilityStatus.supported();
  platform.mockUnlock.refreshedCapability =
      const CapabilityStatus.missingSecret(
    'Automatic unlock password is not configured',
  );
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.retryCapabilityCheck();

  assert(platform.mockScanner.refreshCapabilityCount == 1);
  assert(platform.mockUnlock.refreshCapabilityCount == 1);
  assert(coordinator.value.snapshot.startupEnabled == true);
  assert(coordinator.value.snapshot.bluetoothCapabilityLabel == 'supported');
  assert(coordinator.value.snapshot.autoUnlockCapabilityLabel ==
      'Automatic unlock password is not configured');
  assert(
      coordinator.value.snapshot.lastActionLabel == 'Capabilities refreshed');
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'capabilityRetry',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorOpensMacAutoUnlockPermissionSettings() async {
  final platform = MockBleunlockPlatform(
    platformLabel: 'macOS',
    unlockCapability: const CapabilityStatus.permissionDenied(
      'Accessibility permission is required',
    ),
  );
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();

  assert(
      coordinator.value.snapshot.autoUnlockPermissionSettingsAvailable == true);

  await coordinator.openMacAutoUnlockPermissionSettings();

  assert(platform.mockUnlock.openPermissionSettingsCount == 1);
  assert(coordinator.value.snapshot.lastActionLabel ==
      'Accessibility settings opened');
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'autoUnlockPermissionSettingsOpened',
    ),
  );

  await coordinator.dispose();
}

Future<void>
    testCoordinatorAllowsPasswordEntryWhenUnlockSecretIsMissing() async {
  final platform = MockBleunlockPlatform(
    platformLabel: 'macOS',
    unlockCapability: const CapabilityStatus.missingSecret(
      'Automatic unlock password is not configured',
    ),
  );
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();

  assert(coordinator.value.snapshot.autoUnlockCapabilityLabel ==
      'Automatic unlock password is not configured');
  assert(coordinator.value.snapshot.autoUnlockSecretEditable == true);

  final unsupportedPlatform = MockBleunlockPlatform(
    unlockCapability: const CapabilityStatus.unsupported(),
  );
  final unsupportedCoordinator = AppCoordinator(platform: unsupportedPlatform);

  await unsupportedCoordinator.refreshSystemSettings();

  assert(
      unsupportedCoordinator.value.snapshot.autoUnlockSecretEditable == false);

  await coordinator.dispose();
  await unsupportedCoordinator.dispose();
}

Future<void> testCoordinatorRefreshesScannerCapabilityBeforeMonitoring() async {
  final platform = MockBleunlockPlatform();
  platform.mockScanner.refreshedCapability =
      const CapabilityStatus.poweredOff('Bluetooth off');
  final coordinator = AppCoordinator(
    platform: platform,
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.startMonitoring();

  assert(platform.mockScanner.refreshCapabilityCount == 1);
  assert(!platform.mockScanner.isScanning);
  assert(
      coordinator.value.snapshot.bluetoothCapabilityLabel == 'Bluetooth off');
  assert(coordinator.value.snapshot.lastActionLabel ==
      'Bluetooth scanning unavailable');

  await coordinator.dispose();
}

Future<void> testCoordinatorTogglesStartupStatus() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.setStartupEnabled(true);

  assert(platform.mockStartup.enabled == true);
  assert(coordinator.value.snapshot.startupEnabled == true);
  assert(coordinator.value.snapshot.lastActionLabel == 'Startup enabled');
  assert(
      coordinator.value.logs.any((entry) => entry.reason == 'startupChanged'));

  await coordinator.setStartupEnabled(false);

  assert(platform.mockStartup.enabled == false);
  assert(coordinator.value.snapshot.startupEnabled == false);
  assert(coordinator.value.snapshot.lastActionLabel == 'Startup disabled');

  await coordinator.dispose();
}

Future<void> testCoordinatorLogsStartupUpdateFailures() async {
  final platform = MockBleunlockPlatform();
  platform.mockStartup.setEnabledError = Exception('LaunchAgent update failed');
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.setStartupEnabled(true);

  assert(platform.mockStartup.enabled == false);
  assert(coordinator.value.snapshot.startupEnabled == false);
  assert(coordinator.value.snapshot.lastActionLabel == 'Startup update failed');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.error &&
          entry.reason == 'startupUpdateFailed' &&
          entry.message.contains('LaunchAgent update failed'),
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorStoresAndClearsMacAutoUnlockPassword() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();

  assert(coordinator.value.snapshot.autoUnlockSecretConfigured == false);

  await coordinator.setMacAutoUnlockPassword('safe-password');

  assert(
    await platform.mockSecureStore.readSecret(
          AppCoordinator.macosAutomaticUnlockPasswordKey,
        ) ==
        'safe-password',
  );
  assert(coordinator.value.snapshot.autoUnlockSecretConfigured == true);
  assert(coordinator.value.snapshot.lastActionLabel ==
      'Auto unlock password saved');
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'autoUnlockPasswordSaved',
    ),
  );

  await coordinator.clearMacAutoUnlockPassword();

  assert(
    await platform.mockSecureStore.readSecret(
          AppCoordinator.macosAutomaticUnlockPasswordKey,
        ) ==
        null,
  );
  assert(coordinator.value.snapshot.autoUnlockSecretConfigured == false);
  assert(coordinator.value.snapshot.lastActionLabel ==
      'Auto unlock password cleared');

  await coordinator.dispose();
}

Future<void>
    testCoordinatorRefreshesUnlockCapabilityAfterPasswordChanges() async {
  final platform = MockBleunlockPlatform(
    unlockCapability: const CapabilityStatus.missingSecret(
      'Automatic unlock password is not configured',
    ),
  );
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();

  assert(platform.mockUnlock.refreshCapabilityCount == 1);
  assert(coordinator.value.snapshot.autoUnlockCapabilityLabel ==
      'Automatic unlock password is not configured');

  platform.mockUnlock.refreshedCapability = const CapabilityStatus.supported();
  await coordinator.setMacAutoUnlockPassword('safe-password');

  assert(platform.mockUnlock.refreshCapabilityCount == 2);
  assert(coordinator.value.snapshot.autoUnlockCapabilityLabel == 'supported');

  platform.mockUnlock.refreshedCapability =
      const CapabilityStatus.missingSecret(
    'Automatic unlock password is not configured',
  );
  await coordinator.clearMacAutoUnlockPassword();

  assert(platform.mockUnlock.refreshCapabilityCount == 3);
  assert(coordinator.value.snapshot.autoUnlockCapabilityLabel ==
      'Automatic unlock password is not configured');

  await coordinator.dispose();
}

Future<void> testCoordinatorPublishesTrayStatus() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.refreshSystemSettings();
  await pumpEventQueue();
  assert(platform.mockTray.status == TrayStatus.normal);
  assert(platform.mockTray.recentDeviceSummary == 'No recent devices');

  await coordinator.startScanning();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      displayName: 'Xiaomi Smart Band',
      rssi: -55,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();
  assert(platform.mockTray.recentDeviceSummary == 'Xiaomi Smart Band -55 dBm');

  await coordinator.startMonitoring();
  await pumpEventQueue();
  assert(platform.mockTray.status == TrayStatus.monitoring);
  assert(platform.mockTray.isMonitoring == true);

  await coordinator.lockNow();
  await pumpEventQueue();
  assert(platform.mockTray.status == TrayStatus.locked);
  assert(platform.mockTray.isMonitoring == true);

  await coordinator.pause();
  await pumpEventQueue();
  assert(platform.mockTray.isMonitoring == false);

  await coordinator.dispose();
}

Future<void> testCoordinatorLogsTrayStatusFailures() async {
  final platform = MockBleunlockPlatform();
  platform.mockTray.setStatusError = Exception('Status item failed');
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();
  await Future<void>.delayed(const Duration(milliseconds: 20));
  await pumpEventQueue();

  assert(coordinator.value.snapshot.lastActionLabel == 'Tray update failed');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.error &&
          entry.reason == 'trayStatusUpdateFailed' &&
          entry.message.contains('Status item failed'),
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorLogsTrayActionStreamFailures() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();
  platform.mockTray.emitError(Exception('Native tray action failed'));
  await pumpEventQueue();

  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.error &&
          entry.reason == 'trayActionStreamFailed' &&
          entry.message.contains('Native tray action failed'),
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorEmitsAppCommandsForTrayRequests() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();

  final openSettings = coordinator.commands.first;
  platform.mockTray.emitAction(
    TrayAction(
      kind: TrayActionKind.openSettings,
      timestamp: DateTime(2026, 5, 28, 10),
    ),
  );
  final openCommand = await openSettings;

  assert(openCommand.kind == AppCommandKind.openSettings);
  assert(openCommand.timestamp == DateTime(2026, 5, 28, 10));
  assert(
      coordinator.value.snapshot.lastActionLabel == 'Open settings requested');

  final quit = coordinator.commands.first;
  platform.mockTray.emitAction(
    TrayAction(
      kind: TrayActionKind.quit,
      timestamp: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  final quitCommand = await quit;

  assert(quitCommand.kind == AppCommandKind.quit);
  assert(quitCommand.timestamp == DateTime(2026, 5, 28, 10, 0, 1));
  assert(coordinator.value.snapshot.lastActionLabel == 'Quit requested');

  await coordinator.dispose();
}

Future<void> testCoordinatorHandlesTrayMonitoringActions() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.refreshSystemSettings();
  platform.mockTray.emitAction(
    TrayAction(
      kind: TrayActionKind.startMonitoring,
      timestamp: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockScanner.isScanning);
  assert(coordinator.value.snapshot.monitoringStatus == 'Monitoring');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.message == 'Monitoring started' && entry.reason == 'trayAction',
    ),
  );

  platform.mockTray.emitAction(
    TrayAction(
      kind: TrayActionKind.pauseMonitoring,
      timestamp: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();

  assert(!platform.mockScanner.isScanning);
  assert(coordinator.value.snapshot.monitoringStatus == 'Monitoring paused');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.message == 'Monitoring paused' && entry.reason == 'trayAction',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorHandlesTrayLockAction() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();
  platform.mockTray.emitAction(
    TrayAction(
      kind: TrayActionKind.lockNow,
      timestamp: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockSession.lockCount == 1);
  assert(coordinator.value.snapshot.lastActionLabel == 'Locked screen');
  assert(coordinator.value.snapshot.stateLabel == 'Locked');
  assert(coordinator.value.logs.any((entry) => entry.reason == 'trayAction'));

  await coordinator.dispose();
}

Future<void> testCoordinatorReportsUnavailableManualLock() async {
  final platform = MockBleunlockPlatform(
    sessionCapability: const CapabilityStatus.permissionDenied(
      'Screen lock permission denied',
    ),
  );
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.lockNow();

  assert(platform.mockSession.lockCount == 0);
  assert(coordinator.value.snapshot.lastActionLabel == 'Lock unavailable');
  assert(coordinator.value.snapshot.stateLabel == 'Idle');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.error &&
          entry.reason == 'lockUnavailable' &&
          entry.message.contains('Screen lock permission denied'),
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorReportsUnavailableTrayLockAction() async {
  final platform = MockBleunlockPlatform(
    sessionCapability: const CapabilityStatus.permissionDenied(
      'Screen lock permission denied',
    ),
  );
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();
  platform.mockTray.emitAction(
    TrayAction(
      kind: TrayActionKind.lockNow,
      timestamp: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockSession.lockCount == 0);
  assert(coordinator.value.snapshot.lastActionLabel == 'Lock unavailable');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.error &&
          entry.reason == 'lockUnavailable',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorLogsManualLockFailures() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.lockError = Exception('CGSession failed');
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.lockNow();

  assert(platform.mockSession.lockCount == 0);
  assert(coordinator.value.snapshot.lastActionLabel == 'Lock failed');
  assert(coordinator.value.snapshot.stateLabel == 'Idle');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.error &&
          entry.reason == 'lockFailed' &&
          entry.message.contains('CGSession failed'),
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorSubscribesSessionEventsForManualLock() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.lockNow();
  await pumpEventQueue();
  assert(coordinator.value.snapshot.stateLabel == 'Locked');

  platform.mockSession.emitEvent(
    SessionEvent(
      kind: SessionEventKind.unlocked,
      timestamp: DateTime(2026, 5, 28, 10, 0, 1),
      reason: 'userUnlocked',
    ),
  );
  await pumpEventQueue();

  assert(coordinator.value.snapshot.stateLabel == 'Idle');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.message == 'Session unlocked' && entry.reason == 'unlocked',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorPollsSessionStateWhenUnlockEventIsMissed() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(rssiWindowSize: 1),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -43,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  await coordinator.lockNow();
  await pumpEventQueue();
  assert(coordinator.value.snapshot.stateLabel == 'Locked');

  platform.mockSession.locked = false;
  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 1));
  await pumpEventQueue();

  assert(coordinator.value.snapshot.stateLabel == 'Close');
  assert(coordinator.value.snapshot.lastActionLabel == 'Session unlocked');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.message == 'Session unlocked' &&
          entry.reason == 'sessionStatePoll',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorRefreshesSettingsAfterSystemWake() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();
  assert(coordinator.value.snapshot.startupEnabled == false);
  assert(platform.mockScanner.refreshCapabilityCount == 1);
  assert(platform.mockUnlock.refreshCapabilityCount == 1);

  platform.mockStartup.enabled = true;
  platform.mockScanner.refreshedCapability =
      const CapabilityStatus.poweredOff('Bluetooth off');
  platform.mockUnlock.refreshedCapability =
      const CapabilityStatus.permissionDenied(
          'Accessibility permission denied');
  platform.mockSession.emitEvent(
    SessionEvent(
      kind: SessionEventKind.systemWake,
      timestamp: DateTime(2026, 5, 28, 10),
      reason: 'wake',
    ),
  );
  await pumpEventQueue();

  assert(coordinator.value.snapshot.startupEnabled == true);
  assert(platform.mockScanner.refreshCapabilityCount == 2);
  assert(platform.mockUnlock.refreshCapabilityCount == 2);
  assert(
      coordinator.value.snapshot.bluetoothCapabilityLabel == 'Bluetooth off');
  assert(coordinator.value.snapshot.autoUnlockCapabilityLabel ==
      'Accessibility permission denied');
  assert(coordinator.value.logs.any((entry) => entry.reason == 'systemWake'));

  await coordinator.dispose();
}

Future<void> testCoordinatorReflectsLockSessionEvents() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();
  platform.mockSession.emitEvent(
    SessionEvent(
      kind: SessionEventKind.locked,
      timestamp: DateTime(2026, 5, 28, 10),
      reason: 'screenLocked',
    ),
  );
  await pumpEventQueue();

  assert(coordinator.value.snapshot.lastActionLabel == 'Session locked');
  assert(coordinator.value.snapshot.stateLabel == 'Locked');
  assert(platform.mockTray.status == TrayStatus.locked);

  platform.mockSession.emitEvent(
    SessionEvent(
      kind: SessionEventKind.unlocked,
      timestamp: DateTime(2026, 5, 28, 10, 1),
      reason: 'screenUnlocked',
    ),
  );
  await pumpEventQueue();

  assert(coordinator.value.snapshot.lastActionLabel == 'Session unlocked');
  assert(coordinator.value.snapshot.stateLabel == 'Idle');
  assert(coordinator.value.logs.any((entry) => entry.reason == 'unlocked'));

  await coordinator.dispose();
}

Future<void> testCoordinatorAnnotatesSessionEventLogsWithSessionState() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(platform: platform);

  await coordinator.refreshSystemSettings();
  platform.mockSession.emitEvent(
    SessionEvent(
      kind: SessionEventKind.locked,
      timestamp: DateTime(2026, 5, 28, 10),
      reason: 'screenLocked',
    ),
  );
  await pumpEventQueue();

  final lockedLog = coordinator.value.logs.firstWhere(
    (entry) => entry.reason == 'locked',
  );
  assert(lockedLog.sessionState == DashboardSessionState.locked);

  platform.mockSession.emitEvent(
    SessionEvent(
      kind: SessionEventKind.systemWake,
      timestamp: DateTime(2026, 5, 28, 10, 1),
      reason: 'wake',
    ),
  );
  await pumpEventQueue();

  final wakeLog = coordinator.value.logs.firstWhere(
    (entry) => entry.reason == 'systemWake',
  );
  assert(wakeLog.sessionState == DashboardSessionState.systemWake);

  await coordinator.dispose();
}

Future<void> testCoordinatorThrottlesRepeatedLockActions() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      lockDelay: Duration(seconds: 5),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -86,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 5));
  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 6));
  await pumpEventQueue();

  assert(platform.mockSession.lockCount == 1);
  assert(
    coordinator.value.logs.any((entry) => entry.reason == 'actionThrottled'),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorAutoLocksAfterStaleLockedUiStateClears() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      lockDelay: Duration(seconds: 5),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.lockNow();
  await pumpEventQueue();
  platform.mockSession.emitEvent(
    SessionEvent(
      kind: SessionEventKind.unlocked,
      timestamp: DateTime(2026, 5, 28, 10, 0, 1),
      reason: 'userUnlocked',
    ),
  );
  await pumpEventQueue();

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -86,
      seenAt: DateTime(2026, 5, 28, 10, 1),
    ),
  );
  await pumpEventQueue();
  coordinator.tick(DateTime(2026, 5, 28, 10, 1, 5));
  await pumpEventQueue();

  assert(platform.mockSession.lockCount == 2);
  assert(coordinator.value.snapshot.lastActionLabel == 'Locked screen');
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'rssiBelowLockThresholdForDelay',
    ),
  );

  await coordinator.dispose();
}

Future<void>
    testCoordinatorSkipsRepeatedProximityLockWhenAlreadyLocked() async {
  final platform = MockBleunlockPlatform();
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      lockDelay: Duration(seconds: 5),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -86,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 5));
  await pumpEventQueue();
  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 6));
  coordinator.tick(DateTime(2026, 5, 28, 10, 0, 36));
  await pumpEventQueue();

  assert(platform.mockSession.lockCount == 1);
  assert(
    coordinator.value.logs.every(
      (entry) => entry.reason != 'actionThrottled',
    ),
  );
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.action &&
          entry.message == 'Lock skipped' &&
          entry.reason == 'sessionAlreadyLocked' &&
          entry.sessionState == DashboardSessionState.locked,
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorThrottlesRepeatedUnlockActions() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -44,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any((entry) => entry.reason == 'actionThrottled'),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorThrottlesRepeatedUnlockFailures() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  platform.mockUnlock.unlockError = Exception('Accessibility input failed');
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -44,
      seenAt: DateTime(2026, 5, 28, 10, 0, 1),
    ),
  );
  await pumpEventQueue();

  final unlockFailureLogs = coordinator.value.logs.where(
    (entry) => entry.reason == 'unlockFailed',
  );
  assert(unlockFailureLogs.length == 1);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.reason == 'actionThrottled' &&
          entry.message == 'Unlock throttled',
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorLogsAutomaticUnlockFailures() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  platform.mockUnlock.unlockError = Exception('Accessibility input failed');
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 0);
  assert(coordinator.value.snapshot.lastActionLabel == 'Unlock failed');
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.error &&
          entry.reason == 'unlockFailed' &&
          entry.message.contains('Accessibility input failed'),
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorRetriesUnlockWhenSessionRemainsLocked() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
    unlockRetryDelay: const Duration(milliseconds: 1),
    unlockRetryLimit: 1,
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);

  await Future<void>.delayed(const Duration(milliseconds: 5));
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 2);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.reason == 'unlockRetryScheduled' &&
          entry.sessionState == DashboardSessionState.locked,
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorRetriesStillLockedUnlockFailures() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  platform.mockUnlock.unlockResult =
      const UnlockResult(success: false, reason: 'stillLocked');
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
    unlockRetryDelay: const Duration(milliseconds: 1),
    unlockRetryLimit: 1,
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);

  await Future<void>.delayed(const Duration(milliseconds: 5));
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 2);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.reason == 'unlockRetryScheduled' &&
          entry.sessionState == DashboardSessionState.locked,
    ),
  );

  await coordinator.dispose();
}

Future<void> testCoordinatorDelaysUnlockBrieflyAfterWakeRequest() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      wakeOnProximity: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
    wakeUnlockDelay: const Duration(milliseconds: 5),
  );

  await coordinator.start();
  platform.mockSession.emitEvent(
    SessionEvent(
      kind: SessionEventKind.displaySleep,
      timestamp: DateTime(2026, 5, 28, 9, 59, 59),
      reason: 'displaySleep',
    ),
  );
  await pumpEventQueue();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockSession.wakeCount == 1);
  assert(platform.mockUnlock.unlockCount == 0);

  await Future<void>.delayed(const Duration(milliseconds: 10));
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'wakeUnlockDelay',
    ),
  );

  await coordinator.dispose();
}

Future<void>
    testCoordinatorLogsUnlockRetrySkipWhenSessionUnlocksBeforeRetry() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
    unlockRetryDelay: const Duration(milliseconds: 5),
    unlockRetryLimit: 1,
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'unlockRetryScheduled',
    ),
  );

  platform.mockSession.emitEvent(
    SessionEvent(
      kind: SessionEventKind.unlocked,
      timestamp: DateTime(2026, 5, 28, 10, 0, 1),
      reason: 'userUnlocked',
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 10));
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.action &&
          entry.message == 'Unlock retry skipped' &&
          entry.reason == 'sessionNotLockedForRetry',
    ),
  );

  await coordinator.dispose();
}

Future<void>
    testCoordinatorLogsUnlockRetrySkipWhenLockStateTurnsUnlockedSilently() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
    unlockRetryDelay: const Duration(milliseconds: 1),
    unlockRetryLimit: 1,
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'unlockRetryScheduled',
    ),
  );

  platform.mockSession.locked = false;
  await Future<void>.delayed(const Duration(milliseconds: 5));
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.action &&
          entry.message == 'Unlock retry skipped' &&
          entry.reason == 'sessionNotLockedForRetry',
    ),
  );

  await coordinator.dispose();
}

Future<void>
    testCoordinatorLogsUnlockRetrySkipWhenUnlockBecomesUnavailable() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
    unlockRetryDelay: const Duration(milliseconds: 1),
    unlockRetryLimit: 1,
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'unlockRetryScheduled',
    ),
  );

  platform.mockUnlock.capability =
      const CapabilityStatus.permissionDenied('Accessibility denied');
  await Future<void>.delayed(const Duration(milliseconds: 5));
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.action &&
          entry.message == 'Unlock retry skipped' &&
          entry.reason == 'unlockUnavailableForRetry',
    ),
  );

  await coordinator.dispose();
}

Future<void>
    testCoordinatorLogsUnlockRetrySkipWhenSessionBecomesUnavailable() async {
  final platform = MockBleunlockPlatform();
  platform.mockSession.locked = true;
  final coordinator = AppCoordinator(
    platform: platform,
    config: const ProximityConfig(
      enableMacAutoUnlock: true,
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band-1'},
    unlockRetryDelay: const Duration(milliseconds: 1),
    unlockRetryLimit: 1,
  );

  await coordinator.start();
  platform.emitScan(
    BleScanEvent(
      deviceId: 'band-1',
      rssi: -45,
      seenAt: DateTime(2026, 5, 28, 10),
    ),
  );
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) => entry.reason == 'unlockRetryScheduled',
    ),
  );

  platform.mockSession.capability =
      const CapabilityStatus.permissionDenied('Session access denied');
  await Future<void>.delayed(const Duration(milliseconds: 5));
  await pumpEventQueue();

  assert(platform.mockUnlock.unlockCount == 1);
  assert(
    coordinator.value.logs.any(
      (entry) =>
          entry.category == DashboardLogCategory.action &&
          entry.message == 'Unlock retry skipped' &&
          entry.reason == 'sessionUnavailableForRetry',
    ),
  );

  await coordinator.dispose();
}

Future<void> pumpEventQueue() {
  return Future<void>.delayed(Duration.zero);
}
