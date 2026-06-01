import 'package:bleunlock_macos/src/channel_macos_ble_scan_bridge.dart';
import 'package:bleunlock_macos/src/channel_macos_secure_store_bridge.dart';
import 'package:bleunlock_macos/src/channel_macos_session_bridge.dart';
import 'package:bleunlock_macos/src/channel_macos_startup_bridge.dart';
import 'package:bleunlock_macos/src/channel_macos_tray_bridge.dart';
import 'package:bleunlock_macos/src/channel_macos_unlock_bridge.dart';
import 'package:bleunlock_macos/src/macos_platform.dart';

export 'bleunlock_macos.dart';

MacosBleunlockPlatform createChannelMacosBleunlockPlatform() {
  return MacosBleunlockPlatform(
    scanner: MacosBleScanner(scanBridge: ChannelMacosBleScanBridge()),
    session: MacosSessionController(sessionBridge: ChannelMacosSessionBridge()),
    secureStore: MacosSecureStore(storeBridge: ChannelMacosSecureStoreBridge()),
    tray: MacosTrayController(trayBridge: ChannelMacosTrayBridge()),
    startup: MacosStartupManager(startupBridge: ChannelMacosStartupBridge()),
    unlock: MacosUnlockProvider(unlockBridge: ChannelMacosUnlockBridge()),
  );
}
