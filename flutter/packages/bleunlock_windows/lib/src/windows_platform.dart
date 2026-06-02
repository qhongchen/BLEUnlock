import 'dart:async';

import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

class WindowsBleunlockPlatform {
  WindowsBleunlockPlatform({
    BleScanner? scanner,
    SessionController? session,
    SecureStore? secureStore,
    TrayController? tray,
    StartupManager? startup,
    FutureUnlockProvider? unlock,
  })  : scanner = scanner ?? WindowsBleScanner(),
        session = session ?? WindowsSessionController(),
        secureStore = secureStore ?? WindowsSecureStore(),
        tray = tray ?? WindowsTrayController(),
        startup = startup ?? WindowsStartupManager(),
        unlock = unlock ?? WindowsUnlockProvider();

  final BleScanner scanner;
  final SessionController session;
  final SecureStore secureStore;
  final TrayController tray;
  final StartupManager startup;
  final FutureUnlockProvider unlock;
}

abstract interface class WindowsBleScanBridge {
  Stream<Object?> get events;

  Future<Object?> refreshCapability();

  Future<void> startScan();

  Future<void> stopScan();
}

class InMemoryWindowsBleScanBridge implements WindowsBleScanBridge {
  final StreamController<Object?> _events =
      StreamController<Object?>.broadcast();
  bool _isScanning = false;

  bool get isScanning => _isScanning;

  @override
  Stream<Object?> get events => _events.stream;

  @override
  Future<Object?> refreshCapability() async {
    return {'kind': 'supported'};
  }

  @override
  Future<void> startScan() async {
    _isScanning = true;
  }

  @override
  Future<void> stopScan() async {
    _isScanning = false;
  }
}

class WindowsBleScanner implements BleScanner {
  WindowsBleScanner({WindowsBleScanBridge? scanBridge})
      : _scanBridge = scanBridge ?? InMemoryWindowsBleScanBridge();

  final WindowsBleScanBridge _scanBridge;
  StreamSubscription<Object?>? _nativeEventsSubscription;
  final StreamController<BleScanEvent> _events =
      StreamController<BleScanEvent>.broadcast();

  bool _isScanning = false;
  CapabilityStatus _capability = const CapabilityStatus.supported();

  bool get isScanning => _isScanning;

  @override
  CapabilityStatus get capability => _capability;

  @override
  Future<CapabilityStatus> refreshCapability() async {
    _capability = _mapNativeCapability(await _scanBridge.refreshCapability());
    return _capability;
  }

  @override
  Stream<BleScanEvent> get events => _events.stream;

  @override
  Future<void> startScan() async {
    _nativeEventsSubscription ??= _scanBridge.events
        .map(_mapNativeEvent)
        .listen(_events.add, onError: _events.addError);
    await _scanBridge.startScan();
    _isScanning = true;
  }

  @override
  Future<void> stopScan() async {
    await _scanBridge.stopScan();
    await _nativeEventsSubscription?.cancel();
    _nativeEventsSubscription = null;
    _isScanning = false;
  }

  BleScanEvent _mapNativeEvent(Object? value) {
    if (value is! Map) {
      throw ArgumentError.value(value, 'value', 'Expected map BLE event');
    }

    final deviceId = value['deviceId'];
    final rssi = value['rssi'];
    final seenAtMillis = value['seenAtMillis'];
    if (deviceId is! String || rssi is! int || seenAtMillis is! int) {
      throw ArgumentError.value(value, 'value', 'Invalid BLE event shape');
    }

    final manufacturerData = value['manufacturerData'];
    return BleScanEvent(
      deviceId: deviceId,
      displayName: _normalizedNativeText(value['displayName']),
      addressHint: _normalizedNativeText(value['addressHint']),
      rssi: rssi,
      seenAt: DateTime.fromMillisecondsSinceEpoch(seenAtMillis),
      manufacturerData: manufacturerData is List
          ? manufacturerData.whereType<int>().toList(growable: false)
          : null,
      rawAdvertisement: _jsonMap(value['rawAdvertisement']),
    );
  }
}

Map<String, Object?>? _jsonMap(Object? value) {
  if (value is! Map) {
    return null;
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      continue;
    }
    result[key] = _jsonValue(entry.value);
  }
  return result.isEmpty ? null : Map.unmodifiable(result);
}

Object? _jsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is List) {
    return value.map(_jsonValue).toList(growable: false);
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is String) {
        result[key] = _jsonValue(entry.value);
      }
    }
    return Map.unmodifiable(result);
  }
  return value.toString();
}

String? _normalizedNativeText(Object? value) {
  if (value is! String) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

CapabilityStatus _mapNativeCapability(Object? value) {
  if (value is! Map) {
    throw ArgumentError.value(value, 'value', 'Expected map capability');
  }

  final kind = value['kind'];
  final description = value['description'];
  if (kind is! String || (description != null && description is! String)) {
    throw ArgumentError.value(value, 'value', 'Invalid capability shape');
  }

  switch (kind) {
    case 'supported':
      return const CapabilityStatus.supported();
    case 'unsupported':
      return const CapabilityStatus.unsupported();
    case 'permissionDenied':
      return CapabilityStatus.permissionDenied(description as String?);
    case 'temporarilyUnavailable':
      return CapabilityStatus.temporarilyUnavailable(description as String?);
    case 'poweredOff':
      return CapabilityStatus.poweredOff(description as String?);
    case 'missingSecret':
      return CapabilityStatus.missingSecret(description as String?);
    case 'failedWithReason':
      return CapabilityStatus.failedWithReason(description as String? ?? '');
    case 'unknown':
      return CapabilityStatus.unknown(description as String?);
    default:
      throw ArgumentError.value(kind, 'kind', 'Unknown capability kind');
  }
}

abstract interface class WindowsSessionBridge {
  Stream<Object?> get events;

  Future<void> lock();

  Future<void> wakeDisplay();

  Future<bool> isLocked();
}

class InMemoryWindowsSessionBridge implements WindowsSessionBridge {
  final StreamController<Object?> _events =
      StreamController<Object?>.broadcast();
  bool _locked = false;
  int _wakeCount = 0;

  bool get locked => _locked;

  int get wakeCount => _wakeCount;

  @override
  Stream<Object?> get events => _events.stream;

  @override
  Future<bool> isLocked() async => _locked;

  @override
  Future<void> lock() async {
    _locked = true;
  }

  @override
  Future<void> wakeDisplay() async {
    _wakeCount += 1;
  }
}

class WindowsSessionController implements SessionController {
  WindowsSessionController({WindowsSessionBridge? sessionBridge})
      : _sessionBridge = sessionBridge ?? InMemoryWindowsSessionBridge() {
    _sessionBridge.events
        .map(_mapNativeEvent)
        .listen(_events.add, onError: _events.addError);
  }

  final WindowsSessionBridge _sessionBridge;
  final StreamController<SessionEvent> _events =
      StreamController<SessionEvent>.broadcast();

  @override
  CapabilityStatus get capability => const CapabilityStatus.supported();

  @override
  Stream<SessionEvent> get events => _events.stream;

  @override
  Future<bool> isLocked() async => _sessionBridge.isLocked();

  @override
  Future<void> lock() async {
    await _sessionBridge.lock();
  }

  @override
  Future<void> wakeDisplay() async {
    await _sessionBridge.wakeDisplay();
  }

  SessionEvent _mapNativeEvent(Object? value) {
    if (value is! Map) {
      throw ArgumentError.value(value, 'value', 'Expected map session event');
    }

    final kind = value['kind'];
    final timestampMillis = value['timestampMillis'];
    if (kind is! String || timestampMillis is! int) {
      throw ArgumentError.value(value, 'value', 'Invalid session event shape');
    }

    return SessionEvent(
      kind: _sessionEventKind(kind),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
      reason: value['reason'] as String?,
    );
  }
}

SessionEventKind _sessionEventKind(String value) {
  switch (value) {
    case 'locked':
      return SessionEventKind.locked;
    case 'unlocked':
      return SessionEventKind.unlocked;
    case 'displaySleep':
      return SessionEventKind.displaySleep;
    case 'displayWake':
      return SessionEventKind.displayWake;
    case 'systemSleep':
      return SessionEventKind.systemSleep;
    case 'systemWake':
      return SessionEventKind.systemWake;
    default:
      throw ArgumentError.value(value, 'value', 'Unknown session event kind');
  }
}

abstract interface class WindowsSecureStoreBridge {
  Future<void> writeSecret(String key, String value);

  Future<String?> readSecret(String key);

  Future<void> deleteSecret(String key);
}

class InMemoryWindowsSecureStoreBridge implements WindowsSecureStoreBridge {
  final Map<String, String> _values = {};

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

class WindowsSecureStore implements SecureStore {
  WindowsSecureStore({WindowsSecureStoreBridge? storeBridge})
      : _storeBridge = storeBridge ?? InMemoryWindowsSecureStoreBridge();

  final WindowsSecureStoreBridge _storeBridge;

  @override
  CapabilityStatus get capability => const CapabilityStatus.supported();

  @override
  Future<void> deleteSecret(String key) async {
    await _storeBridge.deleteSecret(key);
  }

  @override
  Future<String?> readSecret(String key) async {
    return _storeBridge.readSecret(key);
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    await _storeBridge.writeSecret(key, value);
  }
}

class WindowsTrayController implements TrayController {
  WindowsTrayController({WindowsTrayBridge? trayBridge})
      : _trayBridge = trayBridge ?? InMemoryWindowsTrayBridge() {
    _trayBridge.events
        .map(_mapNativeEvent)
        .listen(_actions.add, onError: _actions.addError);
  }

  final WindowsTrayBridge _trayBridge;
  final StreamController<TrayAction> _actions =
      StreamController<TrayAction>.broadcast();

  @override
  CapabilityStatus get capability => const CapabilityStatus.supported();

  @override
  Stream<TrayAction> get onAction => _actions.stream;

  @override
  Future<void> setStatus(
    TrayStatus status, {
    String? recentDeviceSummary,
    bool isMonitoring = false,
  }) async {
    await _trayBridge.setStatus(
      status,
      recentDeviceSummary: recentDeviceSummary,
      isMonitoring: isMonitoring,
    );
  }

  @override
  Future<void> showQuickMenu() async {
    await _trayBridge.showQuickMenu();
  }

  TrayAction _mapNativeEvent(Object? value) {
    if (value is! Map) {
      throw ArgumentError.value(value, 'value', 'Expected map tray event');
    }

    final kind = value['kind'];
    final timestampMillis = value['timestampMillis'];
    if (kind is! String || timestampMillis is! int) {
      throw ArgumentError.value(value, 'value', 'Invalid tray event shape');
    }

    return TrayAction(
      kind: _trayActionKind(kind),
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMillis),
    );
  }
}

abstract interface class WindowsTrayBridge {
  Stream<Object?> get events;

  Future<void> setStatus(
    TrayStatus status, {
    String? recentDeviceSummary,
    bool isMonitoring = false,
  });

  Future<void> showQuickMenu();
}

class InMemoryWindowsTrayBridge implements WindowsTrayBridge {
  final StreamController<Object?> _events =
      StreamController<Object?>.broadcast();
  TrayStatus? status;
  String? recentDeviceSummary;
  bool isMonitoring = false;
  int showQuickMenuCount = 0;

  @override
  Stream<Object?> get events => _events.stream;

  @override
  Future<void> setStatus(
    TrayStatus status, {
    String? recentDeviceSummary,
    bool isMonitoring = false,
  }) async {
    this.status = status;
    this.recentDeviceSummary = recentDeviceSummary;
    this.isMonitoring = isMonitoring;
  }

  @override
  Future<void> showQuickMenu() async {
    showQuickMenuCount += 1;
  }
}

TrayActionKind _trayActionKind(String value) {
  switch (value) {
    case 'openSettings':
      return TrayActionKind.openSettings;
    case 'startMonitoring':
      return TrayActionKind.startMonitoring;
    case 'pauseMonitoring':
      return TrayActionKind.pauseMonitoring;
    case 'lockNow':
      return TrayActionKind.lockNow;
    case 'quit':
      return TrayActionKind.quit;
    default:
      throw ArgumentError.value(value, 'value', 'Unknown tray action kind');
  }
}

class WindowsStartupManager implements StartupManager {
  WindowsStartupManager({WindowsStartupBridge? startupBridge})
      : _startupBridge = startupBridge ?? InMemoryWindowsStartupBridge();

  final WindowsStartupBridge _startupBridge;

  @override
  CapabilityStatus get capability => const CapabilityStatus.supported();

  @override
  Future<bool> isEnabled() async => _startupBridge.isEnabled();

  @override
  Future<void> setEnabled(bool enabled) async {
    await _startupBridge.setEnabled(enabled);
  }
}

abstract interface class WindowsStartupBridge {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

class InMemoryWindowsStartupBridge implements WindowsStartupBridge {
  bool enabled = false;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    this.enabled = enabled;
  }
}

class WindowsUnlockProvider implements FutureUnlockProvider {
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
