import 'package:bleunlock_windows/src/channel_windows_ble_scan_bridge.dart';
import 'package:bleunlock_windows/src/channel_windows_secure_store_bridge.dart';
import 'package:bleunlock_windows/src/channel_windows_session_bridge.dart';
import 'package:bleunlock_windows/src/channel_windows_startup_bridge.dart';
import 'package:bleunlock_windows/src/channel_windows_tray_bridge.dart';
import 'package:bleunlock_windows/src/windows_platform.dart';

export 'bleunlock_windows.dart';

WindowsBleunlockPlatform createChannelWindowsBleunlockPlatform() {
  return WindowsBleunlockPlatform(
    scanner: WindowsBleScanner(scanBridge: ChannelWindowsBleScanBridge()),
    session: WindowsSessionController(
      sessionBridge: ChannelWindowsSessionBridge(),
    ),
    secureStore: WindowsSecureStore(
      storeBridge: ChannelWindowsSecureStoreBridge(),
    ),
    tray: WindowsTrayController(trayBridge: ChannelWindowsTrayBridge()),
    startup: WindowsStartupManager(
      startupBridge: ChannelWindowsStartupBridge(),
    ),
    unlock: WindowsUnlockProvider(),
  );
}
