import 'package:bleunlock_app/src/platforms/default_platform_factory.dart';
import 'package:bleunlock_app/src/platforms/mock_bleunlock_platform.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('uses native macOS platform implementation on macOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final platform = const DefaultBleunlockPlatformFactory().create();

    expect(platform, isNot(isA<MockBleunlockPlatform>()));
  });

  test('uses native Windows platform implementation on Windows', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final platform = const DefaultBleunlockPlatformFactory().create();

    expect(platform, isNot(isA<MockBleunlockPlatform>()));
  });

  test('wires Windows automatic unlock through Credential Provider placeholder',
      () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final platform = const DefaultBleunlockPlatformFactory().create();

    expect(platform.platformLabel, 'Windows');
    expect(
      platform.unlock.capability.kind,
      CapabilityStatusKind.temporarilyUnavailable,
    );
    expect(
      platform.unlock.capability.description,
      'Credential Provider component is not installed',
    );
  });
}
