import 'dart:async';

import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

class MacosBleunlockPlatform {
  MacosBleunlockPlatform({
    BleScanner? scanner,
    SessionController? session,
    SecureStore? secureStore,
    TrayController? tray,
    StartupManager? startup,
    FutureUnlockProvider? unlock,
  })  : scanner = scanner ?? MacosBleScanner(),
        session = session ?? MacosSessionController(),
        secureStore = secureStore ?? MacosSecureStore(),
        tray = tray ?? MacosTrayController(),
        startup = startup ?? MacosStartupManager(),
        unlock = unlock ?? MacosUnlockProvider();

  final BleScanner scanner;
  final SessionController session;
  final SecureStore secureStore;
  final TrayController tray;
  final StartupManager startup;
  final FutureUnlockProvider unlock;
}

abstract interface class MacosBleScanBridge {
  Stream<Object?> get events;

  Future<Object?> refreshCapability();

  Future<void> startScan();

  Future<void> stopScan();
}

class InMemoryMacosBleScanBridge implements MacosBleScanBridge {
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

class MacosBleScanner implements BleScanner {
  MacosBleScanner({MacosBleScanBridge? scanBridge})
      : _scanBridge = scanBridge ?? InMemoryMacosBleScanBridge();

  final MacosBleScanBridge _scanBridge;
  StreamSubscription<Object?>? _nativeEventsSubscription;
  final StreamController<BleScanEvent> _events =
      StreamController<BleScanEvent>.broadcast();

  bool _isScanning = false;
  CapabilityStatus _capability = const CapabilityStatus.supported();

  bool get isScanning => _isScanning;

  @override
  CapabilityStatus get capability => _capability;

  @override
  Stream<BleScanEvent> get events => _events.stream;

  @override
  Future<CapabilityStatus> refreshCapability() async {
    _capability = _mapNativeCapability(await _scanBridge.refreshCapability());
    return _capability;
  }

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
    final rawAdvertisement = _rawAdvertisementFromNativeEvent(value);
    return BleScanEvent(
      deviceId: deviceId,
      displayName: _normalizedNativeString(value['displayName']),
      addressHint: _normalizedNativeString(value['addressHint']),
      rssi: rssi,
      seenAt: DateTime.fromMillisecondsSinceEpoch(seenAtMillis),
      manufacturerData: manufacturerData is List
          ? manufacturerData.whereType<int>().toList(growable: false)
          : null,
      rawAdvertisement: rawAdvertisement,
    );
  }
}

Map<String, Object?>? _rawAdvertisementFromNativeEvent(Map value) {
  final result = <String, Object?>{};
  void addText(String key) {
    final text = _normalizedNativeString(value[key]);
    if (text != null) {
      result[key] = text;
    }
  }

  addText('resolvedNameSource');
  addText('rawLocalName');
  addText('peripheralName');
  return result.isEmpty ? null : Map.unmodifiable(result);
}

String? _normalizedNativeString(Object? value) {
  if (value is! String) {
    return null;
  }
  final text = value.trim();
  if (text.isEmpty) {
    return null;
  }
  return text;
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

abstract interface class MacosSessionBridge {
  Stream<Object?> get events;

  Future<void> lock();

  Future<void> wakeDisplay();

  Future<bool> isLocked();
}

class InMemoryMacosSessionBridge implements MacosSessionBridge {
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

class MacosSessionController implements SessionController {
  MacosSessionController({MacosSessionBridge? sessionBridge})
      : _sessionBridge = sessionBridge ?? InMemoryMacosSessionBridge() {
    _sessionBridge.events
        .map(_mapNativeEvent)
        .listen(_events.add, onError: _events.addError);
  }

  final MacosSessionBridge _sessionBridge;
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

abstract interface class MacosSecureStoreBridge {
  Future<void> writeSecret(String key, String value);

  Future<String?> readSecret(String key);

  Future<void> deleteSecret(String key);
}

class InMemoryMacosSecureStoreBridge implements MacosSecureStoreBridge {
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

class MacosSecureStore implements SecureStore {
  MacosSecureStore({MacosSecureStoreBridge? storeBridge})
      : _storeBridge = storeBridge ?? InMemoryMacosSecureStoreBridge();

  final MacosSecureStoreBridge _storeBridge;

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

class MacosTrayController implements TrayController {
  MacosTrayController({MacosTrayBridge? trayBridge})
      : _trayBridge = trayBridge ?? InMemoryMacosTrayBridge() {
    _trayBridge.events
        .map(_mapNativeEvent)
        .listen(_actions.add, onError: _actions.addError);
  }

  final MacosTrayBridge _trayBridge;
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

abstract interface class MacosTrayBridge {
  Stream<Object?> get events;

  Future<void> setStatus(
    TrayStatus status, {
    String? recentDeviceSummary,
    bool isMonitoring = false,
  });

  Future<void> showQuickMenu();
}

class InMemoryMacosTrayBridge implements MacosTrayBridge {
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

class MacosStartupManager implements StartupManager {
  MacosStartupManager({MacosStartupBridge? startupBridge})
      : _startupBridge = startupBridge ?? InMemoryMacosStartupBridge();

  final MacosStartupBridge _startupBridge;

  @override
  CapabilityStatus get capability => const CapabilityStatus.supported();

  @override
  Future<bool> isEnabled() async => _startupBridge.isEnabled();

  @override
  Future<void> setEnabled(bool enabled) async {
    await _startupBridge.setEnabled(enabled);
  }
}

abstract interface class MacosStartupBridge {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool enabled);
}

class InMemoryMacosStartupBridge implements MacosStartupBridge {
  bool enabled = false;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    this.enabled = enabled;
  }
}

abstract interface class MacosUnlockBridge {
  CapabilityStatus get capability;

  Future<Object?> refreshCapability();

  Future<void> openPermissionSettings();

  Future<Object?> unlock();
}

class InMemoryMacosUnlockBridge implements MacosUnlockBridge {
  InMemoryMacosUnlockBridge({
    this.capability = const CapabilityStatus.missingSecret(
      'Automatic unlock password is not configured',
    ),
    UnlockResult result =
        const UnlockResult(success: false, reason: 'missingSecret'),
  }) : _result = result;

  @override
  final CapabilityStatus capability;

  final UnlockResult _result;

  @override
  Future<Object?> refreshCapability() async {
    return {
      'kind': capability.kind.name,
      'description': capability.description,
    };
  }

  @override
  Future<void> openPermissionSettings() async {}

  @override
  Future<Object?> unlock() async {
    return {
      'success': _result.success,
      'reason': _result.reason,
    };
  }
}

class MacosUnlockProvider implements FutureUnlockProvider {
  MacosUnlockProvider({MacosUnlockBridge? unlockBridge})
      : this._(unlockBridge ?? InMemoryMacosUnlockBridge());

  MacosUnlockProvider._(MacosUnlockBridge unlockBridge)
      : _unlockBridge = unlockBridge,
        _capability = unlockBridge.capability;

  final MacosUnlockBridge _unlockBridge;
  CapabilityStatus _capability;

  @override
  CapabilityStatus get capability => _capability;

  @override
  Future<CapabilityStatus> refreshCapability() async {
    _capability = _mapNativeCapability(
      await _unlockBridge.refreshCapability(),
    );
    return _capability;
  }

  @override
  Future<void> openPermissionSettings() async {
    await _unlockBridge.openPermissionSettings();
  }

  @override
  Future<UnlockResult> unlock() async {
    return _mapNativeResult(await _unlockBridge.unlock());
  }

  UnlockResult _mapNativeResult(Object? value) {
    if (value is! Map) {
      throw ArgumentError.value(value, 'value', 'Expected map unlock result');
    }

    final success = value['success'];
    final reason = value['reason'];
    if (success is! bool || reason is! String) {
      throw ArgumentError.value(value, 'value', 'Invalid unlock result shape');
    }

    return UnlockResult(success: success, reason: reason);
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
}
