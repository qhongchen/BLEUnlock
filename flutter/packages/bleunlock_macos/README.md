# bleunlock_macos

macOS platform bridge for the Flutter BLEUnlock implementation.

## Current State

The package includes:

- A testable Dart scanner abstraction in `lib/src/macos_platform.dart`.
- A testable Dart session abstraction in `lib/src/macos_platform.dart`.
- A testable Dart secure-store abstraction in `lib/src/macos_platform.dart`.
- A testable Dart tray abstraction in `lib/src/macos_platform.dart`.
- A testable Dart startup-at-login abstraction in `lib/src/macos_platform.dart`.
- A testable Dart automatic-unlock abstraction in `lib/src/macos_platform.dart`.
- A Flutter-only channel bridge source in
  `lib/src/channel_macos_ble_scan_bridge.dart`.
- A Flutter-only session channel bridge source in
  `lib/src/channel_macos_session_bridge.dart`.
- A Flutter-only secure-store channel bridge source in
  `lib/src/channel_macos_secure_store_bridge.dart`.
- A Flutter-only tray channel bridge source in
  `lib/src/channel_macos_tray_bridge.dart`.
- A Flutter-only startup channel bridge source in
  `lib/src/channel_macos_startup_bridge.dart`.
- A Flutter-only automatic-unlock channel bridge source in
  `lib/src/channel_macos_unlock_bridge.dart`.
- A native Swift CoreBluetooth plugin in `macos/Classes`.
- A native Swift session method/event bridge in `macos/Classes`.
- A native Swift Keychain secure-store method bridge in `macos/Classes`.
- A native Swift menu bar status item bridge in `macos/Classes`.
- A native Swift LaunchAgent startup bridge in `macos/Classes`.
- A native Swift automatic-unlock method bridge in `macos/Classes`.
- A channel-backed public entrypoint in `lib/bleunlock_macos_channel.dart` for
  app runtime wiring.
- A macOS podspec and privacy manifest.

The default `MacosBleScanner` still uses `InMemoryMacosBleScanBridge`, and the
default `MacosSessionController` still uses `InMemoryMacosSessionBridge`, so
pure Dart tests can run in the current sandbox. `MacosSecureStore` likewise uses
`InMemoryMacosSecureStoreBridge` from the pure Dart entrypoint, and
`MacosTrayController` uses `InMemoryMacosTrayBridge` there.
`MacosStartupManager` uses `InMemoryMacosStartupBridge` from the pure Dart
entrypoint, and `MacosUnlockProvider` uses an in-memory missing-secret bridge
from the pure Dart entrypoint. The app should use
`createChannelMacosBleunlockPlatform()` from `bleunlock_macos_channel.dart` when
Flutter package resolution is available.

The channel-backed scanner calls `getScannerCapability` on
`bleunlock_macos/ble_scanner_methods`. The native plugin maps CoreBluetooth
state to `supported`, `poweredOff`, `permissionDenied`, `unsupported`,
`temporarilyUnavailable`, or `unknown`, so the app can show Bluetooth capability
failures before monitoring starts.

The channel-backed unlock provider calls `bleunlock_macos/unlock_methods`.
`getCapability` returns `permissionDenied`, `missingSecret`, `supported`, or a
Keychain failure state so the System section can show explicit capability
status. `unlock` reads the Keychain item named `macosAutomaticUnlockPassword`.
It returns `missingSecret` when the password is absent, `notLocked` when the
session is already unlocked, `permissionDenied` when macOS has not trusted the
process for simulated input, and `submitted` after posting the password and
Return key through `CGEvent`. `openPermissionSettings` opens the macOS
Accessibility privacy pane so the user can grant the simulated-input permission
needed by automatic unlock.

## Next Switch

After local Flutter package resolution works, run:

```sh
cd ../bleunlock_app
flutter pub get
```

Then run the app tests and analyzer. The app platform factory already creates
the channel-backed macOS implementation; `flutter pub get` must regenerate the
app package config and macOS plugin registrant.

Until then, analyze only the pure Dart entrypoints in this package:

```sh
dart analyze lib/bleunlock_macos.dart lib/src/macos_platform.dart test/macos_platform_test.dart
```

These files require Flutter package resolution because they import
`package:flutter/services.dart`:

- `lib/src/channel_macos_ble_scan_bridge.dart`
- `lib/src/channel_macos_session_bridge.dart`
- `lib/src/channel_macos_secure_store_bridge.dart`
- `lib/src/channel_macos_tray_bridge.dart`
- `lib/src/channel_macos_startup_bridge.dart`
- `lib/src/channel_macos_unlock_bridge.dart`
