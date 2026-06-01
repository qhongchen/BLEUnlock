import '../lib/bleunlock_core.dart';

void main() {
  testRssiSmootherUsesLatestSamples();
  testCloseDeviceRequestsWakeAndUnlock();
  testLowRssiWaitsForLockDelayBeforeLocking();
  testNoSignalTimeoutMarksDeviceLostAndLocks();
  testAllCloseRequiresEverySelectedDeviceClose();
  testAllAwayIgnoresUnseenSelectedDevices();
  testAnyAwayLocksWhenOneDeviceLeaves();
  testVisibleUnmonitoredDeviceIsCachedWithoutActions();
  testWeakUnmonitoredDeviceIsIgnored();
  testSelectedDeviceBelowVisibleThresholdStillParticipatesInLocking();

  print('All proximity engine tests passed.');
}

void testRssiSmootherUsesLatestSamples() {
  final smoother = RssiSmoother(windowSize: 3);

  assert(smoother.add(-60) == -60);
  assert(smoother.add(-66) == -63);
  assert(smoother.add(-72) == -66);
  assert(smoother.add(-90) == -76);
}

void testCloseDeviceRequestsWakeAndUnlock() {
  final now = DateTime.utc(2026, 5, 28, 10);
  final engine = ProximityEngine(
    config: const ProximityConfig(
      wakeOnProximity: true,
      enableMacAutoUnlock: true,
    ),
    selectedDeviceIds: {'band'},
  );

  final decision = engine.ingestScan(
    BleScanSample(deviceId: 'band', rssi: -55, seenAt: now),
  );

  assert(decision.shouldLock == false);
  assert(decision.shouldWake == true);
  assert(decision.shouldUnlock == true);
  assert(decision.deviceStates['band']!.state == DevicePresenceState.close);
}

void testLowRssiWaitsForLockDelayBeforeLocking() {
  final start = DateTime.utc(2026, 5, 28, 10);
  final engine = ProximityEngine(
    config: const ProximityConfig(
      lockDelay: Duration(seconds: 5),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band'},
  );

  engine.ingestScan(BleScanSample(deviceId: 'band', rssi: -55, seenAt: start));
  final firstLow = engine.ingestScan(
    BleScanSample(
      deviceId: 'band',
      rssi: -90,
      seenAt: start.add(const Duration(seconds: 1)),
    ),
  );
  final afterDelay = engine.tick(start.add(const Duration(seconds: 6)));

  assert(firstLow.shouldLock == false);
  assert(firstLow.deviceStates['band']!.state == DevicePresenceState.close);
  assert(afterDelay.shouldLock == true);
  assert(afterDelay.deviceStates['band']!.state == DevicePresenceState.away);
}

void testNoSignalTimeoutMarksDeviceLostAndLocks() {
  final start = DateTime.utc(2026, 5, 28, 10);
  final engine = ProximityEngine(
    config: const ProximityConfig(
      noSignalTimeout: Duration(seconds: 60),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band'},
  );

  engine.ingestScan(BleScanSample(deviceId: 'band', rssi: -55, seenAt: start));
  final decision = engine.tick(start.add(const Duration(seconds: 61)));

  assert(decision.shouldLock == true);
  assert(decision.deviceStates['band']!.state == DevicePresenceState.lost);
}

void testAllCloseRequiresEverySelectedDeviceClose() {
  final now = DateTime.utc(2026, 5, 28, 10);
  final engine = ProximityEngine(
    config: const ProximityConfig(
      unlockDeviceLogic: UnlockDeviceLogic.allClose,
      enableMacAutoUnlock: true,
    ),
    selectedDeviceIds: {'band', 'phone'},
  );

  final first = engine.ingestScan(
    BleScanSample(deviceId: 'band', rssi: -55, seenAt: now),
  );
  final second = engine.ingestScan(
    BleScanSample(
      deviceId: 'phone',
      rssi: -54,
      seenAt: now.add(const Duration(seconds: 1)),
    ),
  );

  assert(first.shouldUnlock == false);
  assert(second.shouldUnlock == true);
}

void testAllAwayIgnoresUnseenSelectedDevices() {
  final start = DateTime.utc(2026, 5, 28, 10);
  final engine = ProximityEngine(
    config: const ProximityConfig(
      lockDelay: Duration(seconds: 5),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band', 'stale-history-device'},
  );

  engine.ingestScan(BleScanSample(deviceId: 'band', rssi: -55, seenAt: start));
  engine.ingestScan(
    BleScanSample(
      deviceId: 'band',
      rssi: -90,
      seenAt: start.add(const Duration(seconds: 1)),
    ),
  );

  final decision = engine.tick(start.add(const Duration(seconds: 6)));

  assert(decision.shouldLock == true);
  assert(decision.deviceStates['band']!.state == DevicePresenceState.away);
  assert(!decision.deviceStates.containsKey('stale-history-device'));
}

void testAnyAwayLocksWhenOneDeviceLeaves() {
  final start = DateTime.utc(2026, 5, 28, 10);
  final engine = ProximityEngine(
    config: const ProximityConfig(
      lockDeviceLogic: LockDeviceLogic.anyAway,
      lockDelay: Duration(seconds: 5),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band', 'phone'},
  );

  engine.ingestScan(BleScanSample(deviceId: 'band', rssi: -55, seenAt: start));
  engine.ingestScan(BleScanSample(deviceId: 'phone', rssi: -54, seenAt: start));
  engine.ingestScan(
    BleScanSample(
      deviceId: 'band',
      rssi: -90,
      seenAt: start.add(const Duration(seconds: 1)),
    ),
  );

  final decision = engine.tick(start.add(const Duration(seconds: 6)));

  assert(decision.shouldLock == true);
  assert(decision.deviceStates['band']!.state == DevicePresenceState.away);
  assert(decision.deviceStates['phone']!.state == DevicePresenceState.close);
}

void testVisibleUnmonitoredDeviceIsCachedWithoutActions() {
  final now = DateTime.utc(2026, 5, 28, 10);
  final engine = ProximityEngine(
    config: const ProximityConfig(minimumVisibleRssi: -90),
    selectedDeviceIds: {'band'},
  );

  final decision = engine.ingestScan(
    BleScanSample(
      deviceId: 'phone',
      displayName: 'Phone',
      addressHint: 'AA:BB',
      rssi: -70,
      seenAt: now,
      manufacturerData: const [1, 2, 3],
    ),
  );

  final phone = decision.devices['phone'];

  assert(decision.shouldLock == false);
  assert(decision.shouldWake == false);
  assert(decision.shouldUnlock == false);
  assert(decision.deviceStates.isEmpty);
  if (phone == null) {
    throw StateError('expected visible phone to be cached');
  }
  assert(phone.platformId == 'phone');
  assert(phone.displayName == 'Phone');
  assert(phone.addressHint == 'AA:BB');
  assert(phone.lastRssi == -70);
  assert(phone.lastSeenAt == now);
  assert(phone.manufacturerData!.length == 3);
  assert(phone.isSelected == false);
}

void testWeakUnmonitoredDeviceIsIgnored() {
  final now = DateTime.utc(2026, 5, 28, 10);
  final engine = ProximityEngine(
    config: const ProximityConfig(minimumVisibleRssi: -70),
    selectedDeviceIds: {'band'},
  );

  final decision = engine.ingestScan(
    BleScanSample(deviceId: 'phone', rssi: -90, seenAt: now),
  );

  assert(decision.devices.isEmpty);
  assert(decision.deviceStates.isEmpty);
  assert(decision.reason == 'belowVisibleThreshold');
}

void testSelectedDeviceBelowVisibleThresholdStillParticipatesInLocking() {
  final start = DateTime.utc(2026, 5, 28, 10);
  final engine = ProximityEngine(
    config: const ProximityConfig(
      minimumVisibleRssi: -70,
      lockDelay: Duration(seconds: 5),
      rssiWindowSize: 1,
    ),
    selectedDeviceIds: {'band'},
  );

  engine.ingestScan(BleScanSample(deviceId: 'band', rssi: -55, seenAt: start));
  engine.ingestScan(
    BleScanSample(
      deviceId: 'band',
      rssi: -95,
      seenAt: start.add(const Duration(seconds: 1)),
    ),
  );
  final decision = engine.tick(start.add(const Duration(seconds: 6)));

  assert(decision.devices['band']!.isSelected == true);
  assert(decision.devices['band']!.lastRssi == -95);
  assert(decision.shouldLock == true);
  assert(decision.deviceStates['band']!.state == DevicePresenceState.away);
}
