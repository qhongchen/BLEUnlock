import 'dart:async';

import 'package:bleunlock_app/src/platforms/bleunlock_platform.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

class MockBleunlockPlatform extends BleunlockPlatform {
  factory MockBleunlockPlatform({
    CapabilityStatus scannerCapability = const CapabilityStatus.supported(),
    CapabilityStatus sessionCapability = const CapabilityStatus.supported(),
    CapabilityStatus storeCapability = const CapabilityStatus.supported(),
    CapabilityStatus trayCapability = const CapabilityStatus.supported(),
    CapabilityStatus startupCapability = const CapabilityStatus.supported(),
    CapabilityStatus unlockCapability = const CapabilityStatus.supported(),
    String platformLabel = 'mock',
  }) {
    final scanner = MockBleScanner(scannerCapability);
    final session = MockSessionController(sessionCapability);
    final secureStore = MockSecureStore(storeCapability);
    final tray = MockTrayController(trayCapability);
    final startup = MockStartupManager(startupCapability);
    final unlock = MockUnlockProvider(unlockCapability);

    return MockBleunlockPlatform._(
      mockScanner: scanner,
      mockSession: session,
      mockSecureStore: secureStore,
      mockTray: tray,
      mockStartup: startup,
      mockUnlock: unlock,
      platformLabel: platformLabel,
    );
  }

  const MockBleunlockPlatform._({
    required this.mockScanner,
    required this.mockSession,
    required this.mockSecureStore,
    required this.mockTray,
    required this.mockStartup,
    required this.mockUnlock,
    required String platformLabel,
  }) : super(
          platformLabel: platformLabel,
          scanner: mockScanner,
          session: mockSession,
          secureStore: mockSecureStore,
          tray: mockTray,
          startup: mockStartup,
          unlock: mockUnlock,
        );

  final MockBleScanner mockScanner;
  final MockSessionController mockSession;
  final MockSecureStore mockSecureStore;
  final MockTrayController mockTray;
  final MockStartupManager mockStartup;
  final MockUnlockProvider mockUnlock;

  void emitScan(BleScanEvent event) {
    mockScanner.emit(event);
  }
}

class MockBleScanner implements BleScanner {
  MockBleScanner(this.capability);

  final StreamController<BleScanEvent> _events =
      StreamController<BleScanEvent>.broadcast();

  @override
  CapabilityStatus capability;

  bool isScanning = false;
  BleScanMode lastScanMode = BleScanMode.passive;
  CapabilityStatus? refreshedCapability;
  int refreshCapabilityCount = 0;
  Object? refreshCapabilityError;
  Object? startScanError;
  Object? stopScanError;

  @override
  Stream<BleScanEvent> get events => _events.stream;

  @override
  Future<CapabilityStatus> refreshCapability() async {
    final error = refreshCapabilityError;
    if (error != null) {
      throw error;
    }
    refreshCapabilityCount += 1;
    capability = refreshedCapability ?? capability;
    return capability;
  }

  @override
  Future<void> startScan({BleScanMode mode = BleScanMode.passive}) async {
    final error = startScanError;
    if (error != null) {
      throw error;
    }
    lastScanMode = mode;
    isScanning = true;
  }

  @override
  Future<void> stopScan() async {
    final error = stopScanError;
    if (error != null) {
      throw error;
    }
    isScanning = false;
  }

  void emit(BleScanEvent event) {
    _events.add(event);
  }

  void emitError(Object error) {
    _events.addError(error);
  }
}

class MockSessionController implements SessionController {
  MockSessionController(this.capability);

  @override
  CapabilityStatus capability;

  final StreamController<SessionEvent> _events =
      StreamController<SessionEvent>.broadcast();
  int lockCount = 0;
  int wakeCount = 0;
  bool locked = false;
  Object? isLockedError;
  Object? lockError;
  Object? wakeError;

  @override
  Stream<SessionEvent> get events => _events.stream;

  @override
  Future<bool> isLocked() async {
    final error = isLockedError;
    if (error != null) {
      throw error;
    }
    return locked;
  }

  @override
  Future<void> lock() async {
    final error = lockError;
    if (error != null) {
      throw error;
    }
    lockCount += 1;
    locked = true;
  }

  @override
  Future<void> wakeDisplay() async {
    final error = wakeError;
    if (error != null) {
      throw error;
    }
    wakeCount += 1;
  }

  void emitEvent(SessionEvent event) {
    switch (event.kind) {
      case SessionEventKind.locked:
      case SessionEventKind.displaySleep:
      case SessionEventKind.systemSleep:
        locked = true;
        break;
      case SessionEventKind.unlocked:
      case SessionEventKind.displayWake:
      case SessionEventKind.systemWake:
        locked = false;
        break;
    }
    _events.add(event);
  }

  void emitError(Object error) {
    _events.addError(error);
  }
}

class MockSecureStore implements SecureStore {
  MockSecureStore(this.capability);

  final Map<String, String> _values = {};

  @override
  final CapabilityStatus capability;

  @override
  Future<void> deleteSecret(String key) async {
    _values.remove(key);
  }

  @override
  Future<String?> readSecret(String key) async {
    return _values[key];
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    _values[key] = value;
  }
}

class MockTrayController implements TrayController {
  MockTrayController(this.capability);

  final StreamController<TrayAction> _actions =
      StreamController<TrayAction>.broadcast();
  TrayStatus? status;
  String? recentDeviceSummary;
  bool isMonitoring = false;
  Object? setStatusError;

  @override
  final CapabilityStatus capability;

  @override
  Stream<TrayAction> get onAction => _actions.stream;

  @override
  Future<void> setStatus(
    TrayStatus status, {
    String? recentDeviceSummary,
    bool isMonitoring = false,
  }) async {
    final error = setStatusError;
    if (error != null) {
      throw error;
    }
    this.status = status;
    this.recentDeviceSummary = recentDeviceSummary;
    this.isMonitoring = isMonitoring;
  }

  @override
  Future<void> showQuickMenu() async {}

  void emitAction(TrayAction action) {
    _actions.add(action);
  }

  void emitError(Object error) {
    _actions.addError(error);
  }
}

class MockStartupManager implements StartupManager {
  MockStartupManager(this.capability);

  @override
  final CapabilityStatus capability;

  bool enabled = false;
  Object? isEnabledError;
  Object? setEnabledError;

  @override
  Future<bool> isEnabled() async {
    final error = isEnabledError;
    if (error != null) {
      throw error;
    }
    return enabled;
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    final error = setEnabledError;
    if (error != null) {
      throw error;
    }
    this.enabled = enabled;
  }
}

class MockUnlockProvider implements FutureUnlockProvider {
  MockUnlockProvider(this.capability);

  @override
  CapabilityStatus capability;

  int unlockCount = 0;
  int refreshCapabilityCount = 0;
  int openPermissionSettingsCount = 0;
  CapabilityStatus? refreshedCapability;
  Object? refreshCapabilityError;
  Object? openPermissionSettingsError;
  Object? unlockError;
  UnlockResult unlockResult = const UnlockResult(success: true, reason: 'mock');

  @override
  Future<CapabilityStatus> refreshCapability() async {
    final error = refreshCapabilityError;
    if (error != null) {
      throw error;
    }
    refreshCapabilityCount += 1;
    capability = refreshedCapability ?? capability;
    return capability;
  }

  @override
  Future<void> openPermissionSettings() async {
    final error = openPermissionSettingsError;
    if (error != null) {
      throw error;
    }
    openPermissionSettingsCount += 1;
  }

  @override
  Future<UnlockResult> unlock() async {
    final error = unlockError;
    if (error != null) {
      throw error;
    }
    unlockCount += 1;
    return unlockResult;
  }
}
