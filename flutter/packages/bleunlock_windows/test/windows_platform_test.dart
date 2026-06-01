import 'dart:async';
import 'dart:io';

import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';
import 'package:bleunlock_windows/bleunlock_windows.dart';

const _testTimeout = Duration(milliseconds: 500);

Future<void> main() async {
  await testWindowsNativeStartupUsesFlutterSpecificRunValue();
  await testWindowsNativeRegistersDisplayPowerSessionEvents();
  await testWindowsNativeReportsLockFailuresToDart();
  await testWindowsNativeTrayUsesAppWindowIcon();
  await testWindowsNativeTrayMenuUsesMonitoringState();
  await testWindowsNativeCachesAndResolvesDeviceNames();
  await testWindowsNativeUsesActiveBleScanningForNames();
  await testWindowsNativeFormatsAddressHintForDiagnostics();
  await testWindowsPlatformReportsFirstVersionCapabilities();
  await testWindowsUnlockIsUnsupported();
  await testWindowsScannerRefreshesCapabilityFromBridge();
  await testWindowsScannerStartsAndStopsWithoutNativeBridge();
  await testWindowsScannerMapsNativeAdvertisementEvents();
  await testWindowsScannerNormalizesBlankNativeAdvertisementNames();
  await testWindowsScannerForwardsMalformedNativeEventsAsPublicErrors();
  await testWindowsScannerForwardsNativeStreamErrorsAsPublicErrors();
  await testWindowsSessionDelegatesLockAndWakeToBridge();
  await testWindowsSessionMapsNativeSessionEvents();
  await testWindowsSessionForwardsMalformedNativeEventsAsPublicErrors();
  await testWindowsSecureStoreDelegatesToBridge();
  await testWindowsTrayDelegatesStatusAndMapsActions();
  await testWindowsTrayForwardsMalformedNativeEventsAsPublicErrors();
  await testWindowsStartupDelegatesToBridge();
}

Future<void> testWindowsNativeRegistersDisplayPowerSessionEvents() async {
  const sourcePath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.cpp';
  const headerPath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.h';
  final source = File(sourcePath).readAsStringSync();
  final header = File(headerPath).readAsStringSync();

  assert(header.contains('HPOWERNOTIFY display_power_notify_ = nullptr;'));
  assert(source.contains('RegisterPowerSettingNotification'));
  assert(source.contains('UnregisterPowerSettingNotification'));
  assert(source.contains('WM_POWERBROADCAST'));
  assert(source.contains('PBT_POWERSETTINGCHANGE'));
  assert(source.contains('PBT_APMSUSPEND'));
  assert(source.contains('PBT_APMRESUMEAUTOMATIC'));
  assert(source.contains('EmitSessionEvent("displaySleep"'));
  assert(source.contains('EmitSessionEvent("displayWake"'));
}

Future<void> testWindowsNativeReportsLockFailuresToDart() async {
  const sourcePath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.cpp';
  const headerPath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.h';
  final source = File(sourcePath).readAsStringSync();
  final header = File(headerPath).readAsStringSync();

  assert(header.contains('bool Lock(DWORD *error_code);'));
  assert(source.contains('if (!Lock(&error_code))'));
  assert(source.contains('CompleteWithWin32Error(std::move(result),'));
  assert(source.contains('"LockWorkStation"'));
  assert(source.contains('error_code);'));
  assert(source.contains('if (LockWorkStation())'));
}

Future<void> testWindowsNativeTrayUsesAppWindowIcon() async {
  const sourcePath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.cpp';
  final source = File(sourcePath).readAsStringSync();

  assert(source.contains('HICON LoadTrayIconFromWindow(HWND hwnd)'));
  assert(source.contains('WM_GETICON'));
  assert(source.contains('GetClassLongPtrW'));
  assert(source.contains(
    'tray_icon_data_.hIcon = LoadTrayIconFromWindow(registrar_window_);',
  ));
}

Future<void> testWindowsNativeCachesAndResolvesDeviceNames() async {
  const sourcePath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.cpp';
  final source = File(sourcePath).readAsStringSync();

  assert(source.contains('g_device_name_cache'));
  assert(source.contains('BluetoothLEDevice::FromBluetoothAddressAsync'));
  assert(source.contains('DisplayNameForAdvertisement'));
  assert(source.contains('ScheduleDeviceNameResolution(bluetooth_address);'));
  assert(source.contains('CacheDeviceName(bluetooth_address, display_name);'));
  assert(source.contains('CachedDeviceName(bluetooth_address)'));
  assert(source.contains('ShouldResolveDeviceName(bluetooth_address,'));
  assert(source.contains('if (HasText(display_name))'));
  assert(source.contains(
    'event[flutter::EncodableValue("displayName")] =',
  ));
}

Future<void> testWindowsNativeUsesActiveBleScanningForNames() async {
  const sourcePath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.cpp';
  final source = File(sourcePath).readAsStringSync();

  assert(source.contains('BluetoothLEScanningMode::Active'));
  assert(!source.contains('ScanningMode(BluetoothLEScanningMode::Passive);'));
}

Future<void> testWindowsNativeFormatsAddressHintForDiagnostics() async {
  const sourcePath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.cpp';
  final source = File(sourcePath).readAsStringSync();

  assert(source.contains('std::string FormatBluetoothAddressHint'));
  assert(source.contains('event[flutter::EncodableValue("deviceId")]'));
  assert(source.contains('event[flutter::EncodableValue("addressHint")]'));
  assert(source.contains('FormatBluetoothAddress(args.BluetoothAddress())'));
  assert(
    source.contains('FormatBluetoothAddressHint(args.BluetoothAddress())'),
  );
}

Future<void> testWindowsNativeTrayMenuUsesMonitoringState() async {
  const sourcePath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.cpp';
  const headerPath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.h';
  final source = File(sourcePath).readAsStringSync();
  final header = File(headerPath).readAsStringSync();

  assert(header.contains('bool tray_is_monitoring_ = false;'));
  assert(source.contains('tray_is_monitoring_ = is_monitoring;'));
  assert(source.contains('if (tray_is_monitoring_)'));
  assert(source.contains('L"暂停监听"'));
  assert(source.contains('L"开始监听"'));
  assert(!source.contains(
    'AppendMenuW(menu, MF_STRING, kTrayCommandStartMonitoring, L"开始监听");\n'
    '    AppendMenuW(menu, MF_STRING, kTrayCommandPauseMonitoring, L"暂停监听");',
  ));
}

Future<void> testWindowsNativeStartupUsesFlutterSpecificRunValue() async {
  const sourcePath =
      'flutter/packages/bleunlock_windows/windows/bleunlock_windows_plugin.cpp';
  final source = File(sourcePath).readAsStringSync();

  assert(source.contains(
    'constexpr wchar_t kStartupValueName[] = L"BLEUnlock Flutter";',
  ));
  assert(!source
      .contains('constexpr wchar_t kStartupValueName[] = L"BLEUnlock";'));
}

Future<void> testWindowsPlatformReportsFirstVersionCapabilities() async {
  final platform = WindowsBleunlockPlatform();

  assert(platform.scanner.capability.kind == CapabilityStatusKind.supported);
  assert(platform.session.capability.kind == CapabilityStatusKind.supported);
  assert(
      platform.secureStore.capability.kind == CapabilityStatusKind.supported);
  assert(platform.tray.capability.kind == CapabilityStatusKind.supported);
  assert(platform.startup.capability.kind == CapabilityStatusKind.supported);
  assert(platform.unlock.capability.kind == CapabilityStatusKind.unsupported);
}

Future<void> testWindowsUnlockIsUnsupported() async {
  final unlock = WindowsUnlockProvider();
  final result = await unlock.unlock();

  assert(unlock.capability.kind == CapabilityStatusKind.unsupported);
  assert(!result.success);
  assert(result.reason == 'unsupported');
}

Future<void> testWindowsScannerRefreshesCapabilityFromBridge() async {
  final bridge = FakeWindowsBleScanBridge(
    capability: {
      'kind': 'temporarilyUnavailable',
      'description': 'Bluetooth watcher unavailable',
    },
  );
  final scanner = WindowsBleScanner(scanBridge: bridge);

  final capability = await scanner.refreshCapability();

  assert(capability.kind == CapabilityStatusKind.temporarilyUnavailable);
  assert(capability.description == 'Bluetooth watcher unavailable');
  assert(
      scanner.capability.kind == CapabilityStatusKind.temporarilyUnavailable);
  assert(bridge.refreshCapabilityCount == 1);
}

Future<void> testWindowsScannerStartsAndStopsWithoutNativeBridge() async {
  final scanner = WindowsBleScanner();

  await scanner.startScan();
  await scanner.stopScan();

  final isEmpty = await scanner.events
      .timeout(
        const Duration(milliseconds: 1),
        onTimeout: (sink) => sink.close(),
      )
      .isEmpty;

  assert(isEmpty);
}

Future<void> testWindowsScannerMapsNativeAdvertisementEvents() async {
  final bridge = FakeWindowsBleScanBridge(
    events: Stream<Object?>.fromIterable([
      {
        'deviceId': 'bluetooth-address-or-runtime-id',
        'displayName': 'Xiaomi Smart Band',
        'addressHint': 'AA:BB:CC:DD:EE:FF',
        'rssi': -51,
        'seenAtMillis': 1779943200000,
        'manufacturerData': [7, 8, 9],
      },
    ]),
  );
  final scanner = WindowsBleScanner(scanBridge: bridge);

  final eventFuture = scanner.events.first.timeout(_testTimeout);
  await scanner.startScan();
  final event = await eventFuture;

  assert(bridge.started);
  assert(event.deviceId == 'bluetooth-address-or-runtime-id');
  assert(event.displayName == 'Xiaomi Smart Band');
  assert(event.addressHint == 'AA:BB:CC:DD:EE:FF');
  assert(event.rssi == -51);
  assert(event.seenAt == DateTime.fromMillisecondsSinceEpoch(1779943200000));
  assert(event.manufacturerData!.length == 3);

  await scanner.stopScan();
  assert(bridge.stopped);
}

Future<void> testWindowsScannerNormalizesBlankNativeAdvertisementNames() async {
  final bridge = FakeWindowsBleScanBridge(
    events: Stream<Object?>.fromIterable([
      {
        'deviceId': 'bluetooth-address-or-runtime-id',
        'displayName': '   ',
        'addressHint': '',
        'rssi': -51,
        'seenAtMillis': 1779943200000,
      },
    ]),
  );
  final scanner = WindowsBleScanner(scanBridge: bridge);

  final eventFuture = scanner.events.first.timeout(_testTimeout);
  await scanner.startScan();
  final event = await eventFuture;

  assert(event.displayName == null);
  assert(event.addressHint == null);

  await scanner.stopScan();
}

Future<void>
    testWindowsScannerForwardsMalformedNativeEventsAsPublicErrors() async {
  final uncaughtErrors = <Object>[];

  final publicError = await runZonedGuarded<Future<Object?>>(
    () async {
      final bridge = FakeWindowsBleScanBridge(
        events: Stream<Object?>.fromIterable(['bad-event']),
      );
      final scanner = WindowsBleScanner(scanBridge: bridge);
      final publicErrorFuture = _firstPublicStreamError(scanner.events);

      await scanner.startScan();

      return publicErrorFuture;
    },
    (error, stackTrace) => uncaughtErrors.add(error),
  );

  assert(publicError is ArgumentError);
  assert(uncaughtErrors.isEmpty);
}

Future<void>
    testWindowsScannerForwardsNativeStreamErrorsAsPublicErrors() async {
  final uncaughtErrors = <Object>[];
  final nativeError = StateError('native scanner failed');

  final publicError = await runZonedGuarded<Future<Object?>>(
    () async {
      final bridge = FakeWindowsBleScanBridge(
        events: Stream<Object?>.error(nativeError),
      );
      final scanner = WindowsBleScanner(scanBridge: bridge);
      final publicErrorFuture = _firstPublicStreamError(scanner.events);

      await scanner.startScan();

      return publicErrorFuture;
    },
    (error, stackTrace) => uncaughtErrors.add(error),
  );

  assert(identical(publicError, nativeError));
  assert(uncaughtErrors.isEmpty);
}

Future<void> testWindowsSessionDelegatesLockAndWakeToBridge() async {
  final bridge = FakeWindowsSessionBridge();
  final session = WindowsSessionController(sessionBridge: bridge);

  assert(await session.isLocked() == false);

  await session.lock();
  assert(bridge.lockCount == 1);
  assert(await session.isLocked() == true);

  await session.wakeDisplay();
  assert(bridge.wakeCount == 1);
}

Future<void> testWindowsSessionMapsNativeSessionEvents() async {
  final nativeEvents = StreamController<Object?>();
  final bridge = FakeWindowsSessionBridge(
    events: nativeEvents.stream,
  );
  final session = WindowsSessionController(sessionBridge: bridge);

  final eventFuture = session.events.first.timeout(_testTimeout);
  nativeEvents.add({
    'kind': 'locked',
    'timestampMillis': 1779943200000,
    'reason': 'WM_WTSSESSION_CHANGE',
  });
  final event = await eventFuture;

  assert(event.kind == SessionEventKind.locked);
  assert(event.timestamp == DateTime.fromMillisecondsSinceEpoch(1779943200000));
  assert(event.reason == 'WM_WTSSESSION_CHANGE');

  await nativeEvents.close();
}

Future<void>
    testWindowsSessionForwardsMalformedNativeEventsAsPublicErrors() async {
  final uncaughtErrors = <Object>[];

  final publicError = await runZonedGuarded<Future<Object?>>(
    () async {
      final nativeEvents = StreamController<Object?>();
      final bridge = FakeWindowsSessionBridge(
        events: nativeEvents.stream,
      );
      final session = WindowsSessionController(sessionBridge: bridge);
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

Future<void> testWindowsSecureStoreDelegatesToBridge() async {
  final bridge = FakeWindowsSecureStoreBridge();
  final store = WindowsSecureStore(storeBridge: bridge);

  assert(store.capability.kind == CapabilityStatusKind.supported);

  await store.writeSecret('password', 'secret');
  assert(await store.readSecret('password') == 'secret');
  await store.deleteSecret('password');
  assert(await store.readSecret('password') == null);
  assert(bridge.writeCount == 1);
  assert(bridge.readCount == 2);
  assert(bridge.deleteCount == 1);
}

Future<void> testWindowsTrayDelegatesStatusAndMapsActions() async {
  final nativeEvents = StreamController<Object?>();
  final bridge = FakeWindowsTrayBridge(
    events: nativeEvents.stream,
  );
  final tray = WindowsTrayController(trayBridge: bridge);

  final actionFuture = tray.onAction.first.timeout(_testTimeout);
  await tray.setStatus(
    TrayStatus.warning,
    recentDeviceSummary: 'Xiaomi Smart Band -55 dBm',
    isMonitoring: true,
  );
  await tray.showQuickMenu();
  nativeEvents.add({
    'kind': 'pauseMonitoring',
    'timestampMillis': 1779943200000,
  });
  final action = await actionFuture;

  assert(tray.capability.kind == CapabilityStatusKind.supported);
  assert(bridge.statuses.single == TrayStatus.warning);
  assert(bridge.recentDeviceSummaries.single == 'Xiaomi Smart Band -55 dBm');
  assert(bridge.isMonitoringStates.single == true);
  assert(bridge.showQuickMenuCount == 1);
  assert(action.kind == TrayActionKind.pauseMonitoring);
  assert(
      action.timestamp == DateTime.fromMillisecondsSinceEpoch(1779943200000));

  await nativeEvents.close();
}

Future<void>
    testWindowsTrayForwardsMalformedNativeEventsAsPublicErrors() async {
  final uncaughtErrors = <Object>[];

  final publicError = await runZonedGuarded<Future<Object?>>(
    () async {
      final nativeEvents = StreamController<Object?>();
      final bridge = FakeWindowsTrayBridge(
        events: nativeEvents.stream,
      );
      final tray = WindowsTrayController(trayBridge: bridge);
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

Future<void> testWindowsStartupDelegatesToBridge() async {
  final bridge = FakeWindowsStartupBridge();
  final startup = WindowsStartupManager(startupBridge: bridge);

  assert(startup.capability.kind == CapabilityStatusKind.supported);
  assert(await startup.isEnabled() == false);

  await startup.setEnabled(true);
  assert(await startup.isEnabled() == true);
  await startup.setEnabled(false);
  assert(await startup.isEnabled() == false);
  assert(bridge.setCalls.length == 2);
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

class FakeWindowsBleScanBridge implements WindowsBleScanBridge {
  FakeWindowsBleScanBridge({
    this.events = const Stream<Object?>.empty(),
    this.capability = const {'kind': 'supported'},
  });

  @override
  final Stream<Object?> events;
  final Object? capability;

  bool started = false;
  bool stopped = false;
  int refreshCapabilityCount = 0;

  @override
  Future<Object?> refreshCapability() async {
    refreshCapabilityCount += 1;
    return capability;
  }

  @override
  Future<void> startScan() async {
    started = true;
  }

  @override
  Future<void> stopScan() async {
    stopped = true;
  }
}

class FakeWindowsSessionBridge implements WindowsSessionBridge {
  FakeWindowsSessionBridge({Stream<Object?>? events})
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

class FakeWindowsSecureStoreBridge implements WindowsSecureStoreBridge {
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

class FakeWindowsTrayBridge implements WindowsTrayBridge {
  FakeWindowsTrayBridge({Stream<Object?>? events})
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

class FakeWindowsStartupBridge implements WindowsStartupBridge {
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
