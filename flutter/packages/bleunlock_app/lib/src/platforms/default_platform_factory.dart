import 'package:bleunlock_app/src/platforms/bleunlock_platform.dart';
import 'package:bleunlock_app/src/platforms/mock_bleunlock_platform.dart';
import 'package:bleunlock_macos/bleunlock_macos_channel.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';
import 'package:bleunlock_windows/bleunlock_windows_channel.dart';
import 'package:flutter/foundation.dart';

class DefaultBleunlockPlatformFactory implements BleunlockPlatformFactory {
  const DefaultBleunlockPlatformFactory();

  @override
  BleunlockPlatform create() {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return _fromMacos(createChannelMacosBleunlockPlatform());
    }

    if (defaultTargetPlatform == TargetPlatform.windows) {
      return _fromWindows(createChannelWindowsBleunlockPlatform());
    }

    return MockBleunlockPlatform(
      platformLabel: 'unsupported',
      scannerCapability: const CapabilityStatus.unsupported(),
      sessionCapability: const CapabilityStatus.unsupported(),
      storeCapability: const CapabilityStatus.unsupported(),
      trayCapability: const CapabilityStatus.unsupported(),
      startupCapability: const CapabilityStatus.unsupported(),
      unlockCapability: const CapabilityStatus.unsupported(),
    );
  }

  BleunlockPlatform _fromMacos(MacosBleunlockPlatform platform) {
    return BleunlockPlatform(
      platformLabel: 'macOS',
      scanner: platform.scanner,
      session: platform.session,
      secureStore: platform.secureStore,
      tray: platform.tray,
      startup: platform.startup,
      unlock: platform.unlock,
    );
  }

  BleunlockPlatform _fromWindows(WindowsBleunlockPlatform platform) {
    return BleunlockPlatform(
      platformLabel: 'Windows',
      scanner: platform.scanner,
      session: platform.session,
      secureStore: platform.secureStore,
      tray: platform.tray,
      startup: platform.startup,
      unlock: platform.unlock,
    );
  }
}
