import 'package:bleunlock_app/src/platforms/bleunlock_platform.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

class CapabilitySnapshot {
  const CapabilitySnapshot({
    required this.scanner,
    required this.session,
    required this.secureStore,
    required this.tray,
    required this.startup,
    required this.unlock,
  });

  final CapabilityStatus scanner;
  final CapabilityStatus session;
  final CapabilityStatus secureStore;
  final CapabilityStatus tray;
  final CapabilityStatus startup;
  final CapabilityStatus unlock;

  bool get canScan => scanner.isUsable;

  bool get canLock => session.isUsable;
}

class CapabilityMonitor {
  CapabilityMonitor(
    this.platform, {
    this.throttleWindow = const Duration(seconds: 2),
  });

  final BleunlockPlatform platform;
  final Duration throttleWindow;
  final Map<CapabilityRefreshReason, DateTime> _lastRefreshAt = {};

  CapabilitySnapshot check() {
    return CapabilitySnapshot(
      scanner: platform.scanner.capability,
      session: platform.session.capability,
      secureStore: platform.secureStore.capability,
      tray: platform.tray.capability,
      startup: platform.startup.capability,
      unlock: platform.unlock.capability,
    );
  }

  Future<void> refreshScanner({
    required CapabilityRefreshReason reason,
    bool force = false,
    DateTime? now,
  }) async {
    if (!_shouldRefresh(reason: reason, force: force, now: now)) {
      return;
    }
    await platform.scanner.refreshCapability();
  }

  Future<void> refreshUnlock({
    required CapabilityRefreshReason reason,
    bool force = false,
    DateTime? now,
  }) async {
    if (!_shouldRefresh(reason: reason, force: force, now: now)) {
      return;
    }
    await platform.unlock.refreshCapability();
  }

  Future<void> refreshSystemCapabilities({
    required CapabilityRefreshReason reason,
    bool force = false,
    DateTime? now,
  }) async {
    if (!_shouldRefresh(reason: reason, force: force, now: now)) {
      return;
    }
    await platform.scanner.refreshCapability();
    await platform.unlock.refreshCapability();
  }

  bool _shouldRefresh({
    required CapabilityRefreshReason reason,
    required bool force,
    DateTime? now,
  }) {
    final refreshAt = now ?? DateTime.now();
    final lastRefreshAt = _lastRefreshAt[reason];
    if (!force &&
        lastRefreshAt != null &&
        refreshAt.difference(lastRefreshAt) < throttleWindow) {
      return false;
    }

    _lastRefreshAt[reason] = refreshAt;
    return true;
  }
}

enum CapabilityRefreshReason {
  appStart,
  monitoring,
  sessionEvent,
  userAction,
}
