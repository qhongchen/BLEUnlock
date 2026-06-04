import 'dart:async';
import 'dart:io';

import 'package:bleunlock_macos/bleunlock_macos.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

const _testTimeout = Duration(milliseconds: 500);

Future<void> main() async {
  await testMacosNativeTrayMenuUsesMonitoringState();
  await testMacosNativeScannerPayloadIncludesAddressHint();
  await testMacosNativeScannerResolvesNamesFromSystemCaches();
  await testMacosNativeScannerKeepsLegacyDiscoverySemantics();
  await testMacosNativeScannerDefersBluetoothPrivacyAccessUntilScan();
  await testMacosPodspecIncludesBluetoothPrivacyUsageDescription();
  await testMacosPodspecLinksLoginFrameworkForLockScreen();
  await testMacosNativeLockScreenReportsNativeFailures();
  await testMacosNativeUnlockReturnsStillLockedQuickly();
  await testMacosPlatformReportsFirstVersionCapabilities();
  await testMacosScannerStartsAndStopsWithoutNativeBridge();
  await testMacosScannerMapsNativeAdvertisementEvents();
  await testMacosScannerNormalizesBlankNativeNames();
  await testMacosScannerForwardsMalformedNativeEventsAsPublicErrors();
  await testMacosScannerForwardsNativeStreamErrorsAsPublicErrors();
  await testMacosScannerRefreshesNativeCapability();
  await testMacosSessionDelegatesLockAndWakeToBridge();
  await testMacosSessionMapsNativeSessionEvents();
  await testMacosSessionForwardsMalformedNativeEventsAsPublicErrors();
  await testMacosSecureStoreDelegatesToBridge();
  await testMacosTrayDelegatesStatusAndMapsActions();
  await testMacosTrayForwardsMalformedNativeEventsAsPublicErrors();
  await testMacosStartupDelegatesToBridge();
  await testMacosUnlockProviderDelegatesToBridge();
  await testMacosUnlockProviderRefreshesCapability();
}

Future<void> testMacosNativeTrayMenuUsesMonitoringState() async {
  final source = File(
    'flutter/packages/bleunlock_macos/macos/Classes/BleunlockMacosPlugin.swift',
  ).readAsStringSync();

  assert(source.contains('private var isMonitoring = false'));
  assert(source.contains('isMonitoring = value'));
  assert(source.contains('if isMonitoring {'));
  assert(source.contains('暂停监听'));
  assert(source.contains('} else {'));
  assert(source.contains('开始监听'));
  assert(!source.contains(
    'menu.addItem(menuItem(title: "开始监听", action: #selector(startMonitoring)))\n'
    '    menu.addItem(menuItem(title: "暂停监听", action: #selector(pauseMonitoring)))',
  ));
}

Future<void> testMacosNativeScannerPayloadIncludesAddressHint() async {
  final source = File(
    'flutter/packages/bleunlock_macos/macos/Classes/BleunlockMacosPlugin.swift',
  ).readAsStringSync();

  assert(source.contains('let deviceId = peripheral.identifier.uuidString'));
  assert(source.contains('"deviceId": deviceId'));
  assert(source.contains('"addressHint": addressHint'));
  assert(source.contains('if let displayName'));
  assert(source.contains('"rssi": rssi'));
  assert(source.contains('"seenAtMillis"'));
  assert(source.contains('"manufacturerData"'));
}

Future<void> testMacosNativeScannerResolvesNamesFromSystemCaches() async {
  final source = File(
    'flutter/packages/bleunlock_macos/macos/Classes/BleunlockMacosPlugin.swift',
  ).readAsStringSync();
  final scannerSource = _extractClassSource(source, 'BleunlockBleScanner');

  assert(source.contains('final class BleunlockDeviceNameResolver'));
  assert(source.contains('com.apple.MobileBluetooth.ledevices.paired.db'));
  assert(source.contains('com.apple.MobileBluetooth.ledevices.other.db'));
  assert(source.contains('com.apple.Bluetooth.plist'));
  assert(scannerSource.contains('nameResolver.resolvedDeviceInfo'));
  assert(scannerSource.contains('cached?.displayName'));
  assert(scannerSource.contains('resolvedNameSource'));
  assert(scannerSource.contains('"rawLocalName"'));
  assert(scannerSource.contains('"peripheralName"'));
}

Future<void> testMacosNativeScannerKeepsLegacyDiscoverySemantics() async {
  final source = File(
    'flutter/packages/bleunlock_macos/macos/Classes/BleunlockMacosPlugin.swift',
  ).readAsStringSync();
  final scannerSource = _extractClassSource(source, 'BleunlockBleScanner');
  final resolverSource =
      _extractClassSource(source, 'BleunlockDeviceNameResolver');

  assert(scannerSource.contains('exposureNotificationService'));
  assert(scannerSource.contains('CBUUID(string: "FD6F")'));
  assert(scannerSource.contains('legacyDiscoveryRssiThreshold = -70'));
  assert(scannerSource.contains('containsExposureNotification'));
  assert(scannerSource.contains(
    'rssi < Self.legacyDiscoveryRssiThreshold',
  ));
  assert(scannerSource.contains('legacySignalTimeout'));
  assert(resolverSource.contains('looksLikeTemporaryBroadcastName'));
  assert(resolverSource.contains('stableName'));
  assert(resolverSource.contains('displayName: stableName'));
}

Future<void>
    testMacosNativeScannerDefersBluetoothPrivacyAccessUntilScan() async {
  final source = File(
    'flutter/packages/bleunlock_macos/macos/Classes/BleunlockMacosPlugin.swift',
  ).readAsStringSync();
  final scannerSource = _extractClassSource(source, 'BleunlockBleScanner');
  final onListenSource = _extractFunctionSource(scannerSource, 'onListen');
  final capabilitySource = _extractFunctionSource(scannerSource, 'capability');
  final startScanSource = _extractFunctionSource(scannerSource, 'startScan');

  assert(!onListenSource.contains('CBCentralManager('));
  assert(!capabilitySource.contains('CBCentralManager('));
  assert(capabilitySource.contains('"kind": "supported"'));
  assert(startScanSource.contains('ensureCentralManager()'));
}

Future<void> testMacosPodspecIncludesBluetoothPrivacyUsageDescription() async {
  final source = File(
    'flutter/packages/bleunlock_macos/macos/bleunlock_macos.podspec',
  ).readAsStringSync();

  assert(source.contains('s.info_plist'));
  assert(source.contains('NSBluetoothAlwaysUsageDescription'));
  assert(source.contains('NSBluetoothPeripheralUsageDescription'));
  assert(source.contains('proximity-based lock and unlock decisions'));
}

Future<void> testMacosPodspecLinksLoginFrameworkForLockScreen() async {
  final source = File(
    'flutter/packages/bleunlock_macos/macos/bleunlock_macos.podspec',
  ).readAsStringSync();

  assert(source.contains('login'));
  assert(source.contains('SYSTEM_FRAMEWORK_SEARCH_PATHS'));
  assert(source.contains('PrivateFrameworks'));
}

Future<void> testMacosNativeLockScreenReportsNativeFailures() async {
  final source = File(
    'flutter/packages/bleunlock_macos/macos/Classes/BleunlockMacosPlugin.swift',
  ).readAsStringSync();
  final sessionSource =
      _extractClassSource(source, 'BleunlockSessionController');
  final lockSource = _extractFunctionSource(sessionSource, 'lock');

  assert(source.contains('@_silgen_name("SACLockScreenImmediate")'));
  assert(source.contains('result(FlutterError(code: "lock-failed"'));
  assert(lockSource.contains('func lock() throws'));
  assert(lockSource.contains('SACLockScreenImmediate()'));
  assert(lockSource.contains('waitUntilLocked'));
  assert(!lockSource.contains('try?'));
  assert(!lockSource.contains('CGSession'));
  assert(
      !source.contains('/System/Library/CoreServices/Menu Extras/User.menu'));
}

Future<void> testMacosNativeUnlockReturnsStillLockedQuickly() async {
  final source = File(
    'flutter/packages/bleunlock_macos/macos/Classes/BleunlockMacosPlugin.swift',
  ).readAsStringSync();
  final unlockSource = _extractClassSource(source, 'BleunlockUnlockController');

  assert(unlockSource.contains('waitUntilUnlocked(timeout: 0.7)'));
  assert(!unlockSource.contains('waitUntilUnlocked(timeout: 3.0)'));
  assert(unlockSource
      .contains('return ["success": false, "reason": "stillLocked"]'));
}

String _extractClassSource(String source, String className) {
  final start = source.indexOf('final class $className');
  assert(start >= 0);
  final end = source.indexOf('\nfinal class ', start + 1);
  return source.substring(start, end < 0 ? source.length : end);
}

String _extractFunctionSource(String source, String functionName) {
  final start = source.indexOf('func $functionName');
  assert(start >= 0);
  final nextFunction = source.indexOf('\n  func ', start + 1);
  final nextPrivateFunction = source.indexOf('\n  private func ', start + 1);
  final candidates = [
    if (nextFunction >= 0) nextFunction,
    if (nextPrivateFunction >= 0) nextPrivateFunction,
  ]..sort();
  return source.substring(
      start, candidates.isEmpty ? source.length : candidates.first);
}

Future<void> testMacosPlatformReportsFirstVersionCapabilities() async {
  final platform = MacosBleunlockPlatform();

  assert(platform.scanner.capability.kind == CapabilityStatusKind.supported);
  assert(platform.session.capability.kind == CapabilityStatusKind.supported);
  assert(
      platform.secureStore.capability.kind == CapabilityStatusKind.supported);
  assert(platform.tray.capability.kind == CapabilityStatusKind.supported);
  assert(platform.startup.capability.kind == CapabilityStatusKind.supported);
  assert(platform.unlock.capability.kind == CapabilityStatusKind.missingSecret);
}

Future<void> testMacosScannerStartsAndStopsWithoutNativeBridge() async {
  final scanner = MacosBleScanner();

  await scanner.startScan();
  await scanner.stopScan();

  final event = await scanner.events
      .timeout(
        const Duration(milliseconds: 1),
        onTimeout: (sink) => sink.close(),
      )
      .isEmpty;

  assert(event);
}

Future<void> testMacosScannerMapsNativeAdvertisementEvents() async {
  final bridge = FakeMacosBleScanBridge(
    events: Stream<Object?>.fromIterable([
      {
        'deviceId': 'peripheral-1',
        'displayName': 'Xiaomi Smart Band',
        'addressHint': 'peripheral-1',
        'rssi': -47,
        'seenAtMillis': 1779943200000,
        'manufacturerData': [1, 2, 255],
        'resolvedNameSource': 'CBPeripheral.name',
        'rawLocalName': 'N/A',
        'peripheralName': 'Xiaomi Smart Band',
      },
    ]),
  );
  final scanner = MacosBleScanner(scanBridge: bridge);

  final eventFuture = scanner.events.first.timeout(_testTimeout);
  await scanner.startScan();
  final event = await eventFuture;

  assert(bridge.started);
  assert(event.deviceId == 'peripheral-1');
  assert(event.displayName == 'Xiaomi Smart Band');
  assert(event.addressHint == 'peripheral-1');
  assert(event.rssi == -47);
  assert(event.seenAt == DateTime.fromMillisecondsSinceEpoch(1779943200000));
  assert(event.manufacturerData!.length == 3);
  assert(event.rawAdvertisement?['resolvedNameSource'] == 'CBPeripheral.name');
  assert(event.rawAdvertisement?['rawLocalName'] == 'N/A');
  assert(event.rawAdvertisement?['peripheralName'] == 'Xiaomi Smart Band');

  await scanner.stopScan();
  assert(bridge.stopped);
}

Future<void> testMacosScannerNormalizesBlankNativeNames() async {
  final bridge = FakeMacosBleScanBridge(
    events: Stream<Object?>.fromIterable([
      {
        'deviceId': 'peripheral-1',
        'displayName': '   ',
        'addressHint': '  ',
        'rssi': -47,
        'seenAtMillis': 1779943200000,
      },
    ]),
  );
  final scanner = MacosBleScanner(scanBridge: bridge);

  final eventFuture = scanner.events.first.timeout(_testTimeout);
  await scanner.startScan();
  final event = await eventFuture;

  assert(event.displayName == null);
  assert(event.addressHint == null);

  await scanner.stopScan();
}

Future<void>
    testMacosScannerForwardsMalformedNativeEventsAsPublicErrors() async {
  final uncaughtErrors = <Object>[];

  final publicError = await runZonedGuarded<Future<Object?>>(
    () async {
      final bridge = FakeMacosBleScanBridge(
        events: Stream<Object?>.fromIterable(['bad-event']),
      );
      final scanner = MacosBleScanner(scanBridge: bridge);
      final publicErrorFuture = _firstPublicStreamError(scanner.events);

      await scanner.startScan();

      return publicErrorFuture;
    },
    (error, stackTrace) => uncaughtErrors.add(error),
  );

  assert(publicError is ArgumentError);
  assert(uncaughtErrors.isEmpty);
}

Future<void> testMacosScannerForwardsNativeStreamErrorsAsPublicErrors() async {
  final uncaughtErrors = <Object>[];
  final nativeError = StateError('native scanner failed');

  final publicError = await runZonedGuarded<Future<Object?>>(
    () async {
      final bridge = FakeMacosBleScanBridge(
        events: Stream<Object?>.error(nativeError),
      );
      final scanner = MacosBleScanner(scanBridge: bridge);
      final publicErrorFuture = _firstPublicStreamError(scanner.events);

      await scanner.startScan();

      return publicErrorFuture;
    },
    (error, stackTrace) => uncaughtErrors.add(error),
  );

  assert(identical(publicError, nativeError));
  assert(uncaughtErrors.isEmpty);
}

Future<void> testMacosScannerRefreshesNativeCapability() async {
  final bridge = FakeMacosBleScanBridge(
    events: const Stream<Object?>.empty(),
    refreshedCapability: {
      'kind': 'poweredOff',
      'description': 'Bluetooth is powered off',
    },
  );
  final scanner = MacosBleScanner(scanBridge: bridge);

  final capability = await scanner.refreshCapability();

  assert(capability.kind == CapabilityStatusKind.poweredOff);
  assert(capability.description == 'Bluetooth is powered off');
  assert(scanner.capability.kind == CapabilityStatusKind.poweredOff);
  assert(bridge.refreshCapabilityCount == 1);
}

Future<void> testMacosSecureStoreDelegatesToBridge() async {
  final bridge = FakeMacosSecureStoreBridge();
  final store = MacosSecureStore(storeBridge: bridge);

  assert(store.capability.kind == CapabilityStatusKind.supported);

  await store.writeSecret('password', 'secret');
  assert(await store.readSecret('password') == 'secret');
  await store.deleteSecret('password');
  assert(await store.readSecret('password') == null);
  assert(bridge.writeCount == 1);
  assert(bridge.readCount == 2);
  assert(bridge.deleteCount == 1);
}

Future<void> testMacosSessionDelegatesLockAndWakeToBridge() async {
  final bridge = FakeMacosSessionBridge();
  final session = MacosSessionController(sessionBridge: bridge);

  assert(await session.isLocked() == false);

  await session.lock();
  assert(bridge.lockCount == 1);
  assert(await session.isLocked() == true);

  await session.wakeDisplay();
  assert(bridge.wakeCount == 1);
}

Future<void> testMacosSessionMapsNativeSessionEvents() async {
  final nativeEvents = StreamController<Object?>();
  final bridge = FakeMacosSessionBridge(
    events: nativeEvents.stream,
  );
  final session = MacosSessionController(sessionBridge: bridge);

  final eventFuture = session.events.first.timeout(_testTimeout);
  nativeEvents.add({
    'kind': 'systemWake',
    'timestampMillis': 1779943200000,
    'reason': 'NSWorkspace.didWakeNotification',
  });
  final event = await eventFuture;

  assert(event.kind == SessionEventKind.systemWake);
  assert(event.timestamp == DateTime.fromMillisecondsSinceEpoch(1779943200000));
  assert(event.reason == 'NSWorkspace.didWakeNotification');

  await nativeEvents.close();
}

Future<void>
    testMacosSessionForwardsMalformedNativeEventsAsPublicErrors() async {
  final uncaughtErrors = <Object>[];

  final publicError = await runZonedGuarded<Future<Object?>>(
    () async {
      final nativeEvents = StreamController<Object?>();
      final bridge = FakeMacosSessionBridge(
        events: nativeEvents.stream,
      );
      final session = MacosSessionController(sessionBridge: bridge);
      final publicErrorFuture = _firstPublicStreamError(session.events);

      nativeEvents.add({
        'kind': 'notARealSessionEvent',
        'timestampMillis': 1779943200000,
      });
      final publicError = await publicErrorFuture;
      await nativeEvents.close();

      return publicError;
    },
    (error, stackTrace) => uncaughtErrors.add(error),
  );

  assert(publicError is ArgumentError);
  assert(uncaughtErrors.isEmpty);
}

Future<void> testMacosTrayDelegatesStatusAndMapsActions() async {
  final nativeEvents = StreamController<Object?>();
  final bridge = FakeMacosTrayBridge(
    events: nativeEvents.stream,
  );
  final tray = MacosTrayController(trayBridge: bridge);

  final actionFuture = tray.onAction.first.timeout(_testTimeout);
  await tray.setStatus(
    TrayStatus.monitoring,
    recentDeviceSummary: 'Xiaomi Smart Band -55 dBm',
    isMonitoring: true,
  );
  await tray.showQuickMenu();
  nativeEvents.add({
    'kind': 'lockNow',
    'timestampMillis': 1779943200000,
  });
  final action = await actionFuture;

  assert(tray.capability.kind == CapabilityStatusKind.supported);
  assert(bridge.statuses.single == TrayStatus.monitoring);
  assert(bridge.recentDeviceSummaries.single == 'Xiaomi Smart Band -55 dBm');
  assert(bridge.isMonitoringStates.single == true);
  assert(bridge.showQuickMenuCount == 1);
  assert(action.kind == TrayActionKind.lockNow);
  assert(
      action.timestamp == DateTime.fromMillisecondsSinceEpoch(1779943200000));

  await nativeEvents.close();
}

Future<void> testMacosTrayForwardsMalformedNativeEventsAsPublicErrors() async {
  final uncaughtErrors = <Object>[];

  final publicError = await runZonedGuarded<Future<Object?>>(
    () async {
      final nativeEvents = StreamController<Object?>();
      final bridge = FakeMacosTrayBridge(
        events: nativeEvents.stream,
      );
      final tray = MacosTrayController(trayBridge: bridge);
      final publicErrorFuture = _firstPublicStreamError(tray.onAction);

      nativeEvents.add({
        'kind': 'notARealTrayAction',
        'timestampMillis': 1779943200000,
      });
      final publicError = await publicErrorFuture;
      await nativeEvents.close();

      return publicError;
    },
    (error, stackTrace) => uncaughtErrors.add(error),
  );

  assert(publicError is ArgumentError);
  assert(uncaughtErrors.isEmpty);
}

Future<void> testMacosStartupDelegatesToBridge() async {
  final bridge = FakeMacosStartupBridge();
  final startup = MacosStartupManager(startupBridge: bridge);

  assert(startup.capability.kind == CapabilityStatusKind.supported);
  assert(await startup.isEnabled() == false);

  await startup.setEnabled(true);
  assert(await startup.isEnabled() == true);
  await startup.setEnabled(false);
  assert(await startup.isEnabled() == false);
  assert(bridge.setCalls.length == 2);
}

Future<void> testMacosUnlockProviderDelegatesToBridge() async {
  final bridge = FakeMacosUnlockBridge(
    capability: const CapabilityStatus.supported(),
    result: {
      'success': true,
      'reason': 'submitted',
    },
  );
  final unlock = MacosUnlockProvider(unlockBridge: bridge);

  final result = await unlock.unlock();
  await unlock.openPermissionSettings();

  assert(unlock.capability.kind == CapabilityStatusKind.supported);
  assert(result.success == true);
  assert(result.reason == 'submitted');
  assert(bridge.unlockCount == 1);
  assert(bridge.openPermissionSettingsCount == 1);
}

Future<void> testMacosUnlockProviderRefreshesCapability() async {
  final bridge = FakeMacosUnlockBridge(
    capability: const CapabilityStatus.unknown(),
    refreshedCapability: {
      'kind': 'permissionDenied',
      'description': 'Accessibility permission is required',
    },
    result: {
      'success': false,
      'reason': 'permissionDenied',
    },
  );
  final unlock = MacosUnlockProvider(unlockBridge: bridge);

  final capability = await unlock.refreshCapability();

  assert(capability.kind == CapabilityStatusKind.permissionDenied);
  assert(capability.description == 'Accessibility permission is required');
  assert(unlock.capability.kind == CapabilityStatusKind.permissionDenied);
  assert(bridge.refreshCapabilityCount == 1);
}

Future<Object?> _firstPublicStreamError<T>(Stream<T> stream) {
  return stream.first
      .then<Object?>(
        (_) => null,
        onError: (Object error) => error,
      )
      .timeout(
        _testTimeout,
        onTimeout: () => null,
      );
}

class FakeMacosUnlockBridge implements MacosUnlockBridge {
  FakeMacosUnlockBridge({
    required this.capability,
    required this.result,
    this.refreshedCapability,
  });

  @override
  CapabilityStatus capability;

  final Object? result;
  final Object? refreshedCapability;
  int unlockCount = 0;
  int refreshCapabilityCount = 0;
  int openPermissionSettingsCount = 0;

  @override
  Future<Object?> refreshCapability() async {
    refreshCapabilityCount += 1;
    return refreshedCapability;
  }

  @override
  Future<Object?> unlock() async {
    unlockCount += 1;
    return result;
  }

  @override
  Future<void> openPermissionSettings() async {
    openPermissionSettingsCount += 1;
  }
}

class FakeMacosBleScanBridge implements MacosBleScanBridge {
  FakeMacosBleScanBridge({
    required this.events,
    this.refreshedCapability,
  });

  @override
  final Stream<Object?> events;
  final Object? refreshedCapability;

  bool started = false;
  bool stopped = false;
  int refreshCapabilityCount = 0;

  @override
  Future<Object?> refreshCapability() async {
    refreshCapabilityCount += 1;
    return refreshedCapability;
  }

  @override
  Future<void> startScan({BleScanMode mode = BleScanMode.passive}) async {
    started = true;
  }

  @override
  Future<void> stopScan() async {
    stopped = true;
  }
}

class FakeMacosSessionBridge implements MacosSessionBridge {
  FakeMacosSessionBridge({Stream<Object?>? events})
      : events = events ?? const Stream<Object?>.empty();

  @override
  final Stream<Object?> events;

  int lockCount = 0;
  int wakeCount = 0;
  bool locked = false;

  @override
  Future<bool> isLocked() async => locked;

  @override
  Future<void> lock() async {
    lockCount += 1;
    locked = true;
  }

  @override
  Future<void> wakeDisplay() async {
    wakeCount += 1;
  }
}

class FakeMacosSecureStoreBridge implements MacosSecureStoreBridge {
  final Map<String, String> _values = {};
  int writeCount = 0;
  int readCount = 0;
  int deleteCount = 0;

  @override
  Future<void> deleteSecret(String key) async {
    deleteCount += 1;
    _values.remove(key);
  }

  @override
  Future<String?> readSecret(String key) async {
    readCount += 1;
    return _values[key];
  }

  @override
  Future<void> writeSecret(String key, String value) async {
    writeCount += 1;
    _values[key] = value;
  }
}

class FakeMacosTrayBridge implements MacosTrayBridge {
  FakeMacosTrayBridge({Stream<Object?>? events})
      : events = events ?? const Stream<Object?>.empty();

  @override
  final Stream<Object?> events;

  final List<TrayStatus> statuses = [];
  final List<String?> recentDeviceSummaries = [];
  final List<bool> isMonitoringStates = [];
  int showQuickMenuCount = 0;

  @override
  Future<void> setStatus(
    TrayStatus status, {
    String? recentDeviceSummary,
    bool isMonitoring = false,
  }) async {
    statuses.add(status);
    recentDeviceSummaries.add(recentDeviceSummary);
    isMonitoringStates.add(isMonitoring);
  }

  @override
  Future<void> showQuickMenu() async {
    showQuickMenuCount += 1;
  }
}

class FakeMacosStartupBridge implements MacosStartupBridge {
  bool enabled = false;
  final List<bool> setCalls = [];

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    setCalls.add(enabled);
    this.enabled = enabled;
  }
}
