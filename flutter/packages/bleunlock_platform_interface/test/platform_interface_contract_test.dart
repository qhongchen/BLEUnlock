import 'dart:async';

import '../lib/bleunlock_platform_interface.dart';

Future<void> main() async {
  await testFakeScannerEmitsEvents();
  await testFakeSecureStoreRoundTrip();
  await testFakeTrayCarriesRecentDeviceSummary();
  await testUnsupportedUnlockProvider();
  testCapabilityHelpers();

  print('All platform interface contract tests passed.');
}

Future<void> testFakeScannerEmitsEvents() async {
  final scanner = FakeBleScanner();
  final received = <BleScanEvent>[];
  final subscription = scanner.events.listen(received.add);

  await scanner.startScan();
  final capability = await scanner.refreshCapability();
  scanner.emit(
      BleScanEvent(deviceId: 'band', rssi: -55, seenAt: DateTime.utc(2026)));
  await scanner.stopScan();
  await Future<void>.delayed(Duration.zero);
  await subscription.cancel();

  assert(scanner.capability.kind == CapabilityStatusKind.supported);
  assert(capability.kind == CapabilityStatusKind.supported);
  assert(received.length == 1);
  assert(received.single.deviceId == 'band');
  assert(received.single.rssi == -55);
}

Future<void> testFakeSecureStoreRoundTrip() async {
  final store = FakeSecureStore();

  await store.writeSecret('password', 'secret');
  assert(await store.readSecret('password') == 'secret');
  await store.deleteSecret('password');
  assert(await store.readSecret('password') == null);
}

Future<void> testFakeTrayCarriesRecentDeviceSummary() async {
  final tray = FakeTrayController();
  final typedTray = tray as TrayController;

  await typedTray.setStatus(
    TrayStatus.monitoring,
    recentDeviceSummary: 'Xiaomi Smart Band -55 dBm',
    isMonitoring: true,
  );

  assert(tray.status == TrayStatus.monitoring);
  assert(tray.recentDeviceSummary == 'Xiaomi Smart Band -55 dBm');
  assert(tray.isMonitoring == true);
}

Future<void> testUnsupportedUnlockProvider() async {
  final provider = UnsupportedUnlockProvider();
  final capability = await provider.refreshCapability();
  await provider.openPermissionSettings();
  final result = await provider.unlock();

  assert(capability.kind == CapabilityStatusKind.unsupported);
  assert(provider.capability.kind == CapabilityStatusKind.unsupported);
  assert(result.success == false);
  assert(result.reason == 'unsupported');
}

void testCapabilityHelpers() {
  assert(const CapabilityStatus.supported().isUsable == true);
  assert(const CapabilityStatus.unsupported().isUsable == false);
  assert(
    const CapabilityStatus.failedWithReason('denied').description == 'denied',
  );
}

class FakeBleScanner implements BleScanner {
  final StreamController<BleScanEvent> _controller =
      StreamController<BleScanEvent>.broadcast();

  var _scanning = false;

  @override
  CapabilityStatus get capability => const CapabilityStatus.supported();

  @override
  Future<CapabilityStatus> refreshCapability() async => capability;

  @override
  Stream<BleScanEvent> get events => _controller.stream;

  @override
  Future<void> startScan() async {
    _scanning = true;
  }

  @override
  Future<void> stopScan() async {
    _scanning = false;
  }

  void emit(BleScanEvent event) {
    assert(_scanning == true);
    _controller.add(event);
  }
}

class FakeSecureStore implements SecureStore {
  final Map<String, String> _secrets = {};

  @override
  CapabilityStatus get capability => const CapabilityStatus.supported();

  @override
  Future<void> deleteSecret(String key) async {
    _secrets.remove(key);
  }

  @override
  Future<String?> readSecret(String key) async => _secrets[key];

  @override
  Future<void> writeSecret(String key, String value) async {
    _secrets[key] = value;
  }
}

class FakeTrayController implements TrayController {
  TrayStatus? status;
  String? recentDeviceSummary;
  bool? isMonitoring;

  @override
  CapabilityStatus get capability => const CapabilityStatus.supported();

  @override
  Stream<TrayAction> get onAction => const Stream<TrayAction>.empty();

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
  Future<void> showQuickMenu() async {}
}
