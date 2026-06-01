# bleunlock_windows

Windows platform bridge for the Flutter BLEUnlock implementation.

## Current State

The package includes:

- A testable Dart scanner abstraction in `lib/src/windows_platform.dart`.
- A testable Dart session abstraction in `lib/src/windows_platform.dart`.
- A testable Dart secure-store abstraction in `lib/src/windows_platform.dart`.
- A testable Dart tray abstraction in `lib/src/windows_platform.dart`.
- A testable Dart startup-at-login abstraction in `lib/src/windows_platform.dart`.
- A Flutter-only channel bridge source in
  `lib/src/channel_windows_ble_scan_bridge.dart`.
- A Flutter-only session channel bridge source in
  `lib/src/channel_windows_session_bridge.dart`.
- A Flutter-only secure-store channel bridge source in
  `lib/src/channel_windows_secure_store_bridge.dart`.
- A Flutter-only tray channel bridge source in
  `lib/src/channel_windows_tray_bridge.dart`.
- A Flutter-only startup channel bridge source in
  `lib/src/channel_windows_startup_bridge.dart`.
- A native Windows plugin skeleton in `windows/`.
- A native WinRT `BluetoothLEAdvertisementWatcher` passive scan skeleton in
  `windows/`.
- A native `getScannerCapability` method that probes WinRT watcher creation and
  maps failures into explicit scanner capability states.
- A native Win32 lock/wake/session-event skeleton in `windows/`.
- A native Credential Manager secure-store skeleton in `windows/`.
- A native Win32 notification-area tray skeleton in `windows/`.
- A native HKCU Run registry startup skeleton in `windows/`.
- The Windows startup value name is `BLEUnlock Flutter`, intentionally separate
  from a legacy `BLEUnlock` entry so the Flutter app does not overwrite an
  existing startup configuration.
- A Windows plugin C API wrapper for Flutter's generated plugin registrant.
- CMake links `windowsapp`, `runtimeobject`, `Advapi32`, `Shell32`, `User32`,
  and `Wtsapi32` for the current native bridge set.

The default `WindowsBleScanner` still uses `InMemoryWindowsBleScanBridge`, and
the default `WindowsSessionController` still uses
`InMemoryWindowsSessionBridge`, so pure Dart tests can run in the current
sandbox. `WindowsSecureStore` likewise defaults to an in-memory bridge from the
pure Dart entrypoint, and `WindowsTrayController` uses an in-memory bridge
there. `WindowsStartupManager` uses an in-memory bridge from the pure Dart
entrypoint. The app should use
`createChannelWindowsBleunlockPlatform()` from `bleunlock_windows_channel.dart`
when Flutter package resolution is available.

`WindowsBleScanner.refreshCapability()` now consumes the bridge capability map,
so the app can show WinRT watcher initialization failures instead of assuming
Windows BLE scanning is always supported.

## Next Switch

After local Flutter package resolution works, run:

```sh
cd ../bleunlock_app
flutter pub get
```

Then run the app tests and analyzer. The app platform factory already creates
the channel-backed Windows implementation; `flutter pub get` must regenerate the
app package config, Windows plugin registrant, and plugin symlinks.

The native Windows source has not been compiled in this macOS sandbox. Verify
the WinRT Bluetooth watcher and Win32 tray/startup pieces with a Windows Flutter
build before treating the Windows plugin as production-ready.

Until then, analyze only the pure Dart entrypoints in this package:

```sh
dart analyze lib/bleunlock_windows.dart lib/src/windows_platform.dart test/windows_platform_test.dart
```

These files require Flutter package resolution because they import
`package:flutter/services.dart`:

- `lib/src/channel_windows_ble_scan_bridge.dart`
- `lib/src/channel_windows_session_bridge.dart`
- `lib/src/channel_windows_secure_store_bridge.dart`
- `lib/src/channel_windows_tray_bridge.dart`
- `lib/src/channel_windows_startup_bridge.dart`
