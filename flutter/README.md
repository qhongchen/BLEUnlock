# BLEUnlock Flutter

This directory contains the new Flutter/Dart implementation of BLEUnlock.

The existing Swift/AppKit macOS app remains in the repository root and should
stay untouched while the cross-platform implementation is built out.

## Package Layout

```text
flutter/
└── packages/
    ├── bleunlock_app
    ├── bleunlock_core
    ├── bleunlock_platform_interface
    ├── bleunlock_macos
    └── bleunlock_windows
```

The first implementation slice creates:

- `bleunlock_core`: pure Dart proximity models and state machine.
- `bleunlock_platform_interface`: pure Dart contracts for platform plugins.
- `bleunlock_app`: Flutter desktop settings-window shell for macOS and Windows.
- `bleunlock_macos`: macOS platform package skeleton with first-version
  capability states.
- `bleunlock_windows`: Windows platform package skeleton with automatic unlock
  explicitly marked unsupported.

`bleunlock_macos` and `bleunlock_windows` have both started their native bridge
layers for BLE scanning, session actions, and secure storage. macOS uses a
native Keychain bridge and a menu bar tray bridge; Windows uses a Credential
Manager bridge and a Win32 notification-area tray bridge. Both platforms now
have user-level startup-at-login bridge skeletons. macOS also has a first native
automatic-unlock bridge; Windows automatic unlock remains future work.

`bleunlock_macos` now includes the first native BLE scan/session spike
skeleton:

- Swift `BleunlockMacosPlugin` under `macos/Classes`.
- Flutter-only `ChannelMacosBleScanBridge` source under `lib/src`.
- Flutter-only `ChannelMacosSessionBridge` source under `lib/src`.
- Flutter-only `ChannelMacosSecureStoreBridge` source under `lib/src`.
- Flutter-only `ChannelMacosTrayBridge` source under `lib/src`.
- Flutter-only `ChannelMacosStartupBridge` source under `lib/src`.
- Flutter-only `ChannelMacosUnlockBridge` source under `lib/src`.
- CoreBluetooth passive scanning with duplicate advertisements enabled.
- Method channel names:
  - `bleunlock_macos/ble_scanner_methods`
  - `bleunlock_macos/ble_scanner_events`
  - `bleunlock_macos/session_methods`
  - `bleunlock_macos/session_events`
  - `bleunlock_macos/secure_store_methods`
  - `bleunlock_macos/tray_methods`
  - `bleunlock_macos/tray_events`
  - `bleunlock_macos/startup_methods`
  - `bleunlock_macos/unlock_methods`
- Native event payload fields:
  - `deviceId`
  - `displayName`
  - `rssi`
  - `seenAtMillis`
  - `manufacturerData`
- Native scanner methods:
  - `getScannerCapability`
- Native session methods:
  - `lock`
  - `wakeDisplay`
  - `isLocked`
- Native session event payload fields:
  - `kind`
  - `timestampMillis`
  - `reason`
- Native secure-store methods:
  - `writeSecret`
  - `readSecret`
  - `deleteSecret`
- Native tray methods:
  - `setStatus`
  - `showQuickMenu`
- Native tray `setStatus` payload fields:
  - `status`
  - `recentDeviceSummary` (optional)
  - `isMonitoring`
- Native tray event payload fields:
  - `kind`
  - `timestampMillis`
- Native startup methods:
  - `isEnabled`
  - `setEnabled`
- Native unlock methods:
  - `getCapability`
  - `openPermissionSettings`
  - `unlock`
- Native unlock password key:
  - `macosAutomaticUnlockPassword`
- Native unlock failure reasons:
  - `permissionDenied`
  - `notLocked`
  - `missingSecret`
  - `keychainReadFailed`
- Native startup backing:
  - `~/Library/LaunchAgents/com.github.skyearn.bleunlock.flutter.startup.plist`

The Dart platform classes keep bridge abstractions so event mapping is testable
without loading Flutter engine channels in pure Dart tests. The app factory
already selects channel-backed macOS and Windows implementations, and Flutter
package resolution has been refreshed so `bleunlock_app` resolves those local
platform packages during Flutter tests and analysis.

`bleunlock_windows` mirrors the same staged shape:

- Flutter-only `ChannelWindowsBleScanBridge` source under `lib/src`.
- Flutter-only `ChannelWindowsSessionBridge` source under `lib/src`.
- Flutter-only `ChannelWindowsSecureStoreBridge` source under `lib/src`.
- Flutter-only `ChannelWindowsTrayBridge` source under `lib/src`.
- Flutter-only `ChannelWindowsStartupBridge` source under `lib/src`.
- Native Windows plugin under `windows/`.
- WinRT `BluetoothLEAdvertisementWatcher` passive scanning skeleton.
- Method channel names:
  - `bleunlock_windows/ble_scanner_methods`
  - `bleunlock_windows/ble_scanner_events`
  - `bleunlock_windows/session_methods`
  - `bleunlock_windows/session_events`
  - `bleunlock_windows/secure_store_methods`
  - `bleunlock_windows/tray_methods`
  - `bleunlock_windows/tray_events`
  - `bleunlock_windows/startup_methods`
- Native event payload fields:
  - `deviceId`
  - `displayName`
  - `addressHint`
  - `rssi`
  - `seenAtMillis`
  - `manufacturerData`
- Windows scan payload uses a compact Bluetooth address as `deviceId` and a
  colon-separated `addressHint` for readable diagnostics.
- Native scanner methods:
  - `getScannerCapability`
  - `startScan`
  - `stopScan`
- Native session methods:
  - `lock`
  - `wakeDisplay`
  - `isLocked`
- Native session event payload fields:
  - `kind`
  - `timestampMillis`
  - `reason`
- Native secure-store methods:
  - `writeSecret`
  - `readSecret`
  - `deleteSecret`
- Native tray methods:
  - `setStatus`
  - `showQuickMenu`
- Native tray `setStatus` payload fields:
  - `status`
  - `recentDeviceSummary` (optional)
  - `isMonitoring`
- Native tray event payload fields:
  - `kind`
  - `timestampMillis`
- Native startup methods:
  - `isEnabled`
  - `setEnabled`
- Native startup backing:
  - `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`
  - value name `BLEUnlock Flutter`, intentionally separate from a legacy
    `BLEUnlock` startup entry.
- Windows plugin C API registration wrapper for Flutter's generated plugin
  registrant.
- Windows native code has source-level checks only on the current macOS host;
  it still needs a Windows Flutter build to verify WinRT and Win32 linkage.
  The Windows scanner bridge now refreshes capability through the native
  `getScannerCapability` method instead of assuming scanning is always
  supported.

`bleunlock_app` has a `DefaultBleunlockPlatformFactory` entrypoint for platform
selection. It now selects channel-backed macOS and Windows platform
implementations at runtime, while unsupported targets still receive an explicit
unsupported mock platform. Package resolution, widget tests, default platform
factory tests, app-level analysis, and macOS debug/release builds have been
verified with Flutter SDK cache access. The release app bundle passes deep
code-sign validation and carries only the sandbox and Bluetooth entitlements.

The Flutter macOS Runner has the Bluetooth permission pieces needed before a
real scan run:

- `NSBluetoothAlwaysUsageDescription` in `macos/Runner/Info.plist`.
- `com.apple.security.device.bluetooth` in both Debug/Profile and Release
  entitlements.

The current app shell already has the first coordinator path:

- expose Overview quick actions for monitoring control and immediate lock;
- show `Locked` as the aggregate overview state when session events or lock
  actions report the screen is locked;
- scan for nearby devices before selecting one;
- select/unselect a discovered device;
- show each discovered device's RSSI, interpreted proximity state, and last
  seen time in the device list;
- show platform IDs as short codes in the device list while keeping the full
  platform ID internally for selection and logs;
- block monitoring when no device is selected;
- block monitoring when required scanner/lock capabilities are unavailable;
- route scan events through `ProximityEngine`;
- emit structured `scan`, `decision`, `action`, and `error` logs.
- include level, platform, device id, RSSI, and reason details in log entries
  when available.
- include concrete capability labels in blocking failure logs, such as
  Bluetooth powered off, permission denied, unsupported lock, or unsupported
  unlock.
- export diagnostic logs as JSON lines from the Logs section for scan-spike and
  MVP acceptance checks, including scan name, address hint, and manufacturer
  data when available.
- write the current filtered diagnostic log to a local `.jsonl` file under the
  system temporary diagnostics directory, so real BLE and lock-screen runs can
  leave a file artifact instead of relying only on clipboard copy.
- export an acceptance bundle JSON containing the current dashboard snapshot,
  proximity config, visible logs, session diagnostics, and device diagnostics
  for real BLE and lock-screen validation.
- keep acceptance bundle export available before the first log entry so
  first-start capability and config baselines can be captured.
- include export source, platform, OS version, Dart version, and build mode in
  acceptance bundles so runtime evidence is self-describing across macOS and
  Windows.
- include acceptance-summary flags in acceptance bundles so manual runs can
  quickly show whether scan, locked-session scan, decision, action, and error
  evidence was captured.
- export `readyForAcceptance` and `missingRequiredEvidenceCount` in acceptance
  summaries, and show the same ready/incomplete state in the Validation section
  before copying or exporting evidence.
- include per-checklist evidence count plus first and latest evidence timestamps
  in copied checklist JSON lines and acceptance bundles, so real validation
  evidence can be audited without manually matching every raw log entry.
- show those checklist evidence counts and latest evidence times directly in
  the Validation section, so runtime acceptance progress can be inspected before
  copying or exporting JSON.
- group required validation evidence into higher-level Validation steps such as
  BLE scan, lock and wake, macOS auto unlock, tray menu, and startup at login,
  each with captured/required progress plus the latest supporting evidence time.
- export those validation steps as runbook JSON lines with the action to
  perform, expected evidence, current status, and missing required labels, so
  real desktop validation can be driven from the same evidence model.
- export a dedicated validation runbook bundle JSON containing environment
  metadata, the current snapshot/config, acceptance summary, runbook steps, and
  runbook JSON lines for offline manual validation.
- include missing-only runbook steps and JSON lines in the Validation UI and
  runbook bundle, so manual validation can focus only on proof points that are
  not captured yet.
- include next-action hints for missing runbook steps, pointing to concrete
  runtime actions such as moving the selected device, using tray menu items, or
  toggling startup at login.
- show those next-action hints near the Validation readiness summary, so manual
  validation can see the next runtime action before exporting evidence.
- expose a copied missing-action list and export the same list in the runbook
  bundle, so manual validation can paste a concise sequence of remaining
  runtime actions.
- export the missing-action list as a standalone `.txt` file with the current
  `validationSessionId` in its filename, so real validation can be driven from a
  short action list without opening the full runbook bundle.
- include `validationSessionId`, export time, platform, OS version, and build
  mode in that missing-action `.txt` header, so the checklist remains
  self-describing after it is copied away from the filename.
- render the missing actions in that `.txt` export as numbered steps, making
  real validation easier to follow and mark off item by item.
- add `result`, `evidence`, and `notes` placeholders under each numbered action,
  so manual validation results and related evidence filenames can be recorded
  directly in the exported text file.
- include external validation gates in the missing-action `.txt` file with
  `manualRequired` status plus `result`, `evidence`, and `notes` placeholders.
- include a `relatedFiles` block in the missing-action `.txt` header for the
  diagnostics `.jsonl`, acceptance `.json`, and runbook `.json` filenames from
  the same validation session, plus the active export directory path.
- attach the same `validationSessionId` to acceptance and runbook bundles
  exported from the Validation section, so evidence files from one manual run
  can be correlated later.
- show and copy the current `validationSessionId` from the Validation section,
  and include it in copied checklist and runbook JSON lines for paste-based
  manual evidence.
- include that `validationSessionId` in acceptance and runbook bundle filenames,
  so exported JSON bundles can be matched to raw diagnostic logs before opening
  the files.
- share that `validationSessionId` with the Logs section from the home page and
  include it in exported diagnostic `.jsonl` filenames and JSON lines, so raw
  logs, acceptance bundles, and runbook bundles from the same run can be matched.
- show and copy the active Validation export directory path before exporting, so
  manual validation can quickly locate evidence files.
- export validation evidence from one Validation action, writing diagnostics
  `.jsonl`, acceptance `.json`, runbook `.json`, and missing-actions `.txt`
  files with the same `validationSessionId`.
- include a validation manifest `.json` in that one-action export, listing the
  generated evidence files, export directory, readiness state, missing required
  evidence labels, next action list, external validation gate summary counts,
  overall acceptance status, overall blocker labels, and environment.
- show and export external validation gates for Windows build verification,
  real BLE scan, lock-screen scan continuity, macOS Accessibility unlock, tray
  actions, and startup-at-login actions as `manualRequired`.
- combine runtime evidence readiness with external validation gate status in
  the Validation UI, acceptance bundle, runbook bundle, and manifest, so
  acceptance is only ready after the runtime checklist is complete and all
  external gates are resolved without failures.
- show external validation gate summary counts in the Validation section, so a
  manual run can see resolved, pending, and failed gate totals before exporting.
- allow those external validation gates to be marked pending, passed, or failed
  in the Validation section, and include the current gate statuses in the
  acceptance bundle, runbook bundle, validation manifest, and missing-actions
  `.txt` export.
- render each external validation gate as a collapsible editor whose collapsed
  row shows the status and result summary, keeping the validation surface
  scannable during long manual runs.
- copy all external validation gates as validation-scoped JSON lines, so
  Windows and real-device gate status can be pasted into notes without opening
  the full bundle.
- copy a single external validation gate as validation-scoped JSON from its
  expanded editor, so one Windows or real-device result can be shared without
  copying unrelated manual gates.
- export a single external validation gate as a validation-scoped JSON file
  from its expanded editor, so a Windows or real-device proof can be archived
  independently from the full evidence bundle.
- include `schemaVersion`, `bundleType`, `exportedAt`, and environment metadata
  in those single-gate JSON files, so they remain self-describing after being
  moved away from the main evidence directory.
- write a cumulative `externalValidationGateIndex` JSON file alongside
  single-gate exports, listing gate id, label, status, filename, and path so
  split Windows/real-device validation files can be collected later without
  losing earlier gate proofs from the same validation session.
- keep index merge and parsing logic in the validation export helper with pure
  Dart coverage for duplicate gate replacement and malformed index input.
- keep latest-index file discovery in the validation export helper with pure
  Dart coverage for missing directories, empty directories, malformed JSON, and
  choosing the newest index file for the active validation session.
- copy the latest cumulative external gate index from the Validation section,
  so split Windows/real-device proof files can be pasted into acceptance notes
  without manually finding the newest index file.
- export the latest cumulative external gate index from the Validation section,
  so the final split Windows/real-device proof index can be archived on demand.
- show the same acceptance readiness status in the Logs section for quick
  manual validation before exporting the evidence bundle.
- include the current session state on scan diagnostic logs so real runs can
  compare advertisements seen while unlocked, locked, display sleeping, or
  system sleeping/waking.
- filter logs by category, level, and identity text so scan, decision, action,
  and error events can be inspected without leaving the app.
- filter logs by session state to isolate BLE advertisements seen during
  unlocked, locked, display sleep, or system sleep/wake phases.
- summarize logs per session state with log count, scan count, latest scan
  time, latest scan device, and RSSI for lock-screen BLE validation.
- copy the current session-state summary as JSON lines for sharing
  lock-screen BLE evidence.
- summarize scan events per device with seen count, RSSI range, latest RSSI,
  last seen time, and identity stability indicators.
- include average RSSI, average advertisement interval, and longest silent gap
  in per-device diagnostics for passive-scan reliability checks.
- record Windows or other unsupported automatic-unlock decisions as unsupported
  action logs rather than error logs.
- include device-level proximity reasons such as close, away, lost, RSSI
  thresholds, and no-signal timeout in decision logs.
- throttle repeated lock, wake, and unlock actions so noisy RSSI decisions do
  not repeatedly fire system actions.
- check session lock capability before manual or tray lock requests and log
  `lockUnavailable` instead of calling an unsupported platform action.
- run a periodic proximity tick while monitoring so delayed lock and
  no-signal lost transitions can happen even when the selected device stops
  advertising.
- skip proximity-triggered lock while the session is already treated as
  locked, preventing repeated lock calls and tick-driven diagnostic noise.
- confirm the session is locked before submitting the macOS automatic-unlock
  password; proximity-triggered unlock is skipped with `sessionNotLocked` when
  the session is already unlocked.
- retry macOS automatic unlock once after a short delay when the password was
  submitted but the session still reports locked, and cancel that retry when
  monitoring pauses, automatic unlock is disabled, or the session unlocks.
- log `Unlock retry skipped` with concrete reasons when a queued retry is
  canceled or fires after runtime state changes, including stopped monitoring,
  disabled automatic unlock, unavailable unlock capability, unavailable session
  capability, and no-longer-locked session state.
- require explicit user acknowledgement before enabling macOS automatic unlock,
  disable that switch when the platform reports automatic unlock unsupported,
  and only show the password entry row after the feature is enabled on a
  configurable platform.
- edit proximity rules from the Rules section and rebuild the engine when those
  settings change.
- persist proximity rules and selected monitored devices through a
  `SecureStore`-backed settings repository, with corrupt settings ignored
  safely on startup.
- read and toggle startup-at-login state through the platform interface.
- handle tray/menu start and pause monitoring actions and mark those diagnostic
  action logs with `trayAction`.
- pass `isMonitoring` to native tray implementations so macOS and Windows menus
  show Start Monitoring or Pause Monitoring according to current state.
- save and clear the macOS automatic-unlock password through `SecureStore`
  without placing the password in JSON settings.
- show an Accessibility settings shortcut when macOS automatic unlock reports
  missing simulated-input permission, and route it through the macOS platform
  provider.
- expose a manual capability refresh action in the System section so users can
  retry after changing Bluetooth, startup, or Accessibility permissions.
- subscribe to tray/menu actions and publish normal, monitoring, locked, or
  warning tray status updates.
- publish a recent device summary to the tray/menu, preferring selected
  devices and showing the best current RSSI.
- turn tray open-settings and quit requests into app-level commands. The
  Flutter shell returns to the root settings view on open-settings and requests
  a clean Flutter application exit on quit.
- subscribe to session events so wake, sleep, lock, and unlock events refresh
  app state, startup state, scanner capability, automatic-unlock capability,
  password status, and logs.
- throttle repeated automatic capability refreshes by reason, while keeping
  manual retry and password changes as forced refresh paths.

## Verification Status

The pure Dart packages and non-UI coordinator tests can be checked without
Flutter package resolution:

```sh
dart --enable-asserts flutter/packages/bleunlock_core/test/proximity_engine_test.dart
dart --enable-asserts flutter/packages/bleunlock_core/test/proximity_config_test.dart
dart --enable-asserts flutter/packages/bleunlock_platform_interface/test/platform_interface_contract_test.dart
dart --enable-asserts flutter/packages/bleunlock_app/test/dashboard_state_test.dart
dart --enable-asserts flutter/packages/bleunlock_app/test/app_coordinator_test.dart
dart --enable-asserts flutter/packages/bleunlock_app/test/settings_repository_test.dart
dart --enable-asserts flutter/packages/bleunlock_macos/test/macos_platform_test.dart
dart --enable-asserts flutter/packages/bleunlock_windows/test/windows_platform_test.dart
dart analyze flutter/packages/bleunlock_core flutter/packages/bleunlock_platform_interface flutter/packages/bleunlock_macos/lib/bleunlock_macos.dart flutter/packages/bleunlock_macos/lib/src/macos_platform.dart flutter/packages/bleunlock_macos/test/macos_platform_test.dart flutter/packages/bleunlock_windows/lib/bleunlock_windows.dart flutter/packages/bleunlock_windows/lib/src/windows_platform.dart flutter/packages/bleunlock_windows/test/windows_platform_test.dart flutter/packages/bleunlock_app/lib/src/controllers/app_coordinator.dart flutter/packages/bleunlock_app/lib/src/controllers/capability_monitor.dart flutter/packages/bleunlock_app/lib/src/view_models/dashboard_state.dart flutter/packages/bleunlock_app/lib/src/home_page.dart flutter/packages/bleunlock_app/lib/src/sections/overview_section.dart flutter/packages/bleunlock_app/lib/src/sections/device_section.dart flutter/packages/bleunlock_app/lib/src/sections/log_section.dart flutter/packages/bleunlock_app/lib/src/sections/rules_section.dart flutter/packages/bleunlock_app/lib/src/sections/system_section.dart flutter/packages/bleunlock_app/lib/src/platforms/bleunlock_platform.dart flutter/packages/bleunlock_app/lib/src/platforms/mock_bleunlock_platform.dart flutter/packages/bleunlock_app/test/app_coordinator_test.dart flutter/packages/bleunlock_app/test/dashboard_state_test.dart flutter/packages/bleunlock_app/test/widget_test.dart flutter/packages/bleunlock_app/test/default_platform_factory_test.dart
```

The app package depends on Flutter SDK package resolution. If the sandbox cannot
write the Flutter SDK cache lockfile, rerun the Flutter commands with explicit
permission. After changing plugin dependencies, run from the app package:

```sh
cd flutter/packages/bleunlock_app
flutter pub get
flutter test
flutter analyze
flutter build macos --debug
flutter build macos --release
codesign --verify --deep --strict --verbose=2 build/macos/Build/Products/Release/bleunlock_app.app
codesign -d --entitlements :- build/macos/Build/Products/Release/bleunlock_app.app
```

This step is now required after adding `bleunlock_macos` and
`bleunlock_windows` to the app dependency graph. The current verified app-level
commands are `flutter test`, `flutter analyze`, and
`flutter build macos --debug` / `--release` from
`flutter/packages/bleunlock_app`. Use Flutter test/analyze, not plain `dart`,
for Flutter-only channel files or tests that import `package:flutter`.
