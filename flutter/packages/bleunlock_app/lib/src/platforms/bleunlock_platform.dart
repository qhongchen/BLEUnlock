import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

class BleunlockPlatform {
  const BleunlockPlatform({
    required this.platformLabel,
    required this.scanner,
    required this.session,
    required this.secureStore,
    required this.tray,
    required this.startup,
    required this.unlock,
  });

  final String platformLabel;
  final BleScanner scanner;
  final SessionController session;
  final SecureStore secureStore;
  final TrayController tray;
  final StartupManager startup;
  final FutureUnlockProvider unlock;
}

abstract interface class BleunlockPlatformFactory {
  BleunlockPlatform create();
}
