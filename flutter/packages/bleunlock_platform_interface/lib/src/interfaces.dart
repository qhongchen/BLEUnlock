import 'capability_status.dart';
import 'events.dart';

enum BleScanMode {
  passive,
  active,
}

abstract interface class BleScanner {
  CapabilityStatus get capability;

  Future<CapabilityStatus> refreshCapability();

  Stream<BleScanEvent> get events;

  Future<void> startScan({BleScanMode mode = BleScanMode.passive});

  Future<void> stopScan();
}

abstract interface class SessionController {
  CapabilityStatus get capability;

  Stream<SessionEvent> get events;

  Future<void> lock();

  Future<void> wakeDisplay();

  Future<bool> isLocked();
}

abstract interface class SecureStore {
  CapabilityStatus get capability;

  Future<void> writeSecret(String key, String value);

  Future<String?> readSecret(String key);

  Future<void> deleteSecret(String key);
}

abstract interface class TrayController {
  CapabilityStatus get capability;

  Stream<TrayAction> get onAction;

  Future<void> setStatus(
    TrayStatus status, {
    String? recentDeviceSummary,
    bool isMonitoring = false,
  });

  Future<void> showQuickMenu();
}

abstract interface class StartupManager {
  CapabilityStatus get capability;

  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

abstract interface class FutureUnlockProvider {
  CapabilityStatus get capability;

  Future<CapabilityStatus> refreshCapability();

  Future<void> openPermissionSettings();

  Future<UnlockResult> unlock();
}

class UnsupportedUnlockProvider implements FutureUnlockProvider {
  const UnsupportedUnlockProvider();

  @override
  CapabilityStatus get capability => const CapabilityStatus.unsupported();

  @override
  Future<CapabilityStatus> refreshCapability() async => capability;

  @override
  Future<void> openPermissionSettings() async {}

  @override
  Future<UnlockResult> unlock() async {
    return const UnlockResult(success: false, reason: 'unsupported');
  }
}
