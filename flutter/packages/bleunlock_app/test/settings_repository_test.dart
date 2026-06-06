import 'package:bleunlock_app/src/platforms/mock_bleunlock_platform.dart';
import 'package:bleunlock_app/src/settings/app_settings_repository.dart';
import 'package:bleunlock_core/bleunlock_core.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

Future<void> main() async {
  await testSecureStoreRepositoryRoundTripsSettings();
  await testSecureStoreRepositoryReturnsNullForMissingSettings();
  await testSecureStoreRepositoryIgnoresCorruptSettings();
}

Future<void> testSecureStoreRepositoryRoundTripsSettings() async {
  final store = MockSecureStore(const CapabilityStatus.supported());
  final repository = SecureStoreAppSettingsRepository(store);

  await repository.save(
    const AppSettings(
      config: ProximityConfig(
        unlockRssi: -52,
        lockRssi: -83,
        noSignalTimeout: Duration(seconds: 45),
        lockDelay: Duration(seconds: 7),
        minimumVisibleRssi: -94,
        unlockDeviceLogic: UnlockDeviceLogic.allClose,
        lockDeviceLogic: LockDeviceLogic.anyAway,
        wakeOnProximity: true,
        enableMacAutoUnlock: true,
        rssiWindowSize: 3,
      ),
      selectedDeviceIds: {'band-1', 'phone-1'},
      windowsIdentityProfiles: {
        'band-1': WindowsBleIdentityProfile(
          deviceId: 'band-1',
          displayName: 'Xiaomi Smart Band',
          addressHint: 'AA:BB:CC:DD:EE:FF',
          broadcastAddresses: {'aabbccddeeff'},
          deviceInformationIds: {
            r'bluetoothle#bluetoothle00:11:22:33:44:55-aa:bb:cc:dd:ee:ff',
          },
          serviceUuids: {'0000180f-0000-1000-8000-00805f9b34fb'},
          manufacturerCompanyIds: {'76'},
          manufacturerFingerprints: {'76:4c001005'},
        ),
      },
    ),
  );

  final loaded = await repository.load();

  if (loaded == null) {
    throw StateError('expected settings to be loaded');
  }
  assert(loaded.config.unlockRssi == -52);
  assert(loaded.config.lockRssi == -83);
  assert(loaded.config.noSignalTimeout == const Duration(seconds: 45));
  assert(loaded.config.lockDelay == const Duration(seconds: 7));
  assert(loaded.config.minimumVisibleRssi == -94);
  assert(loaded.config.unlockDeviceLogic == UnlockDeviceLogic.allClose);
  assert(loaded.config.lockDeviceLogic == LockDeviceLogic.anyAway);
  assert(loaded.config.wakeOnProximity == true);
  assert(loaded.config.enableMacAutoUnlock == true);
  assert(loaded.config.rssiWindowSize == 3);
  assert(loaded.selectedDeviceIds.length == 2);
  assert(loaded.selectedDeviceIds.contains('band-1'));
  assert(loaded.selectedDeviceIds.contains('phone-1'));
  final profile = loaded.windowsIdentityProfiles['band-1']!;
  assert(profile.displayName == 'Xiaomi Smart Band');
  assert(profile.deviceInformationIds.single ==
      r'bluetoothle#bluetoothle00:11:22:33:44:55-aa:bb:cc:dd:ee:ff');
  assert(profile.serviceUuids.single == '0000180f-0000-1000-8000-00805f9b34fb');
}

Future<void> testSecureStoreRepositoryReturnsNullForMissingSettings() async {
  final store = MockSecureStore(const CapabilityStatus.supported());
  final repository = SecureStoreAppSettingsRepository(store);

  final loaded = await repository.load();

  assert(loaded == null);
}

Future<void> testSecureStoreRepositoryIgnoresCorruptSettings() async {
  final store = MockSecureStore(const CapabilityStatus.supported());
  final repository = SecureStoreAppSettingsRepository(store);

  await store.writeSecret('bleunlock.settings.v1', '{not-json');

  final loaded = await repository.load();

  assert(loaded == null);
}
