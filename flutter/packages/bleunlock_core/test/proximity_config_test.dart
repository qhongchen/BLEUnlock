import '../lib/bleunlock_core.dart';

void main() {
  testProximityConfigCopyWithKeepsUnchangedValues();

  print('All proximity config tests passed.');
}

void testProximityConfigCopyWithKeepsUnchangedValues() {
  const original = ProximityConfig(
    unlockRssi: -58,
    lockRssi: -84,
    noSignalTimeout: Duration(seconds: 75),
    lockDelay: Duration(seconds: 9),
    minimumVisibleRssi: -92,
    unlockDeviceLogic: UnlockDeviceLogic.allClose,
    lockDeviceLogic: LockDeviceLogic.anyAway,
    wakeOnProximity: true,
    enableMacAutoUnlock: true,
    rssiWindowSize: 7,
  );

  final updated = original.copyWith(
    unlockRssi: -50,
    noSignalTimeout: const Duration(seconds: 30),
    wakeOnProximity: false,
  );

  assert(updated.unlockRssi == -50);
  assert(updated.lockRssi == original.lockRssi);
  assert(updated.noSignalTimeout == const Duration(seconds: 30));
  assert(updated.lockDelay == original.lockDelay);
  assert(updated.minimumVisibleRssi == original.minimumVisibleRssi);
  assert(updated.unlockDeviceLogic == original.unlockDeviceLogic);
  assert(updated.lockDeviceLogic == original.lockDeviceLogic);
  assert(updated.wakeOnProximity == false);
  assert(updated.enableMacAutoUnlock == original.enableMacAutoUnlock);
  assert(updated.rssiWindowSize == original.rssiWindowSize);
  assert(original.unlockRssi == -58);
  assert(original.wakeOnProximity == true);
}
