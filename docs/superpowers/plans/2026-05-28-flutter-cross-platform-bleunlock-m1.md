# Flutter Cross-Platform BLEUnlock M1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start the Flutter cross-platform implementation by creating an isolated `flutter/` workspace with testable Dart core logic, platform interface contracts, and a first settings-window app shell.

**Architecture:** Keep the existing Swift/Xcode app untouched. Add `flutter/packages/bleunlock_core` for pure Dart proximity logic, `flutter/packages/bleunlock_platform_interface` for OS capability contracts, and `flutter/packages/bleunlock_app` for the first Flutter desktop shell. Use plain Dart assertion-based tests for packages that do not need Flutter package resolution; use Flutter test/analyze for the app package and channel-backed platform selection.

**Tech Stack:** Dart 3.6, pure Dart packages, assertion-based test scripts, future Flutter federated plugins.

---

## Current Implementation Status

Updated: 2026-05-31

- [x] Isolated `flutter/` workspace exists and the legacy Swift/AppKit app is
  untouched.
- [x] Local code-side verification is complete on the current macOS host:
  pure Dart assertion tests, Flutter widget/controller tests, cross-package
  Dart analysis, macOS debug build, macOS release build, release code-sign
  validation, release entitlement inspection, and plist/privacy lint all pass.
  The only remaining acceptance work requires a Windows host or real desktop
  runtime/device validation.
- [x] `bleunlock_core` proximity models, RSSI smoothing, selected-device
  monitoring, lost timeout, delayed lock, and any/all multi-device rules are
  implemented with assertion tests.
- [x] `bleunlock_platform_interface` contracts are implemented for scanner,
  session, secure store, tray, startup, and future unlock providers.
- [x] `bleunlock_app` settings shell exists with Overview, Devices, Rules,
  System, and Logs sections.
- [x] The app coordinator wires scanning, selection, monitoring, proximity
  decisions, lock/wake/unlock actions, throttling, settings persistence,
  startup state, tray commands, session events, capability labels, manual
  capability retry, and macOS automatic-unlock password handling.
- [x] The app coordinator catches scanner, startup, session lock/wake,
  automatic-unlock, tray, and session-event bridge failures and records
  structured error logs instead of letting native plugin exceptions break the
  dashboard update loop.
- [x] Automatic capability refreshes are throttled by reason; manual retry and
  password changes force a fresh capability check.
- [x] The Overview section exposes quick actions for monitoring control and
  immediate lock, matching the first-version UI design.
- [x] The Overview aggregate state reflects session lock state as `Locked`.
- [x] The primary device action row explains why monitoring is unavailable when
  scanned devices exist but none are selected.
- [x] The Devices section displays discovered device name, platform ID, RSSI,
  proximity state, and last seen time.
- [x] Long platform IDs are displayed as short codes in the device list while
  retaining the full id for selection and logs.
- [x] Monitoring automatically pauses and stops scanning when the final selected
  device is unselected, keeping UI state, scanning state, and logs aligned.
- [x] Log entries carry and display level, platform, device id, RSSI, and
  reason metadata where available.
- [x] Logs can be copied as JSON lines for real BLE scan diagnostics and
  acceptance checks, including scan name, address hint, and manufacturer data
  when available.
- [x] Logs can export the current filtered diagnostic JSON lines to a local
  `.jsonl` file under the system temporary diagnostics directory for runtime
  acceptance evidence.
- [x] Logs can export an acceptance bundle JSON containing snapshot, config,
  visible logs, session diagnostics, and device diagnostics for real BLE and
  lock-screen validation.
- [x] Acceptance bundle export remains available before any log is recorded, so
  first-start baseline capability/config evidence can be captured.
- [x] Acceptance bundle JSON includes environment metadata such as export
  source, platform, OS version, Dart version, and build mode so macOS/Windows
  manual evidence is self-describing.
- [x] Acceptance bundle JSON includes an acceptance summary with log/device
  counts, selected-device count, observed sessions/devices, and scan, locked
  scan, decision, action, and error evidence flags.
- [x] Logs show an Acceptance readiness summary so manual validation can see
  selected-device count plus scan, locked-scan, decision, action, and error
  evidence without opening the exported JSON.
- [x] Acceptance readiness and bundle JSON now include runtime checklist
  evidence for auto lock, wake, macOS auto unlock, tray actions, and startup
  actions, matching the remaining manual validation categories.
- [x] Acceptance checklist items are exported as stable JSON objects and can be
  copied from the Logs section as JSON lines, making real BLE, lock-screen,
  tray, startup, and unlock validation evidence shareable without opening the
  full acceptance bundle.
- [x] Acceptance checklist item JSON now includes evidence count plus first and
  latest evidence timestamps, so captured proof points can be audited from the
  checklist lines or acceptance bundle without manually correlating raw logs.
- [x] Acceptance summary JSON and Validation UI now expose
  `readyForAcceptance` plus `missingRequiredEvidenceCount`, so the app can
  distinguish incomplete evidence from a ready-to-acceptance-run state.
- [x] Validation UI now shows each checklist item's evidence count and latest
  evidence time, so manual validation can inspect proof quality before copying
  or exporting JSON.
- [x] Acceptance summary JSON and Validation UI now group checklist evidence
  into validation steps for BLE scan, lock/wake, macOS auto unlock, tray menu,
  and startup at login, each showing captured/required progress and latest
  supporting evidence time.
- [x] Validation steps are exported as runbook JSON lines with action,
  expected evidence, current status, and missing required labels, so manual
  desktop validation can follow the same evidence model used by the bundle.
- [x] Validation runbook can be exported as a dedicated JSON bundle with
  environment metadata, current snapshot/config, acceptance summary, runbook
  steps, and runbook JSON lines for offline validation runs.
- [x] Validation UI and runbook bundle include missing-only runbook steps and
  JSON lines, so manual validation can focus on uncaptured proof points.
- [x] Missing runbook steps include next-action hints for concrete runtime
  actions, including moving the selected device, using tray menu items, and
  toggling startup at login.
- [x] Validation UI shows those next-action hints near the readiness summary,
  so manual validation can see the next runtime action before exporting
  evidence.
- [x] Validation UI can copy a concise missing-action list, and the runbook
  bundle exports the same list for offline validation notes.
- [x] Validation UI can export the missing-action list as a standalone `.txt`
  file whose filename includes `validationSessionId`, so manual validation can
  follow the remaining actions without opening the full runbook bundle.
- [x] Missing-action `.txt` export includes a metadata header with validation
  id, export time, platform, OS version, and build mode, so the file remains
  self-describing outside its original filename.
- [x] Missing-action `.txt` export renders remaining actions as numbered steps,
  so real validation can be followed and checked off item by item.
- [x] Each missing-action `.txt` step includes `result`, `evidence`, and
  `notes` placeholders, so manual validation outcomes and evidence filenames
  can be recorded directly in the exported checklist.
- [x] Missing-action `.txt` export also includes external validation gates with
  `manualRequired` status and `result`, `evidence`, and `notes` placeholders,
  so Windows build, real BLE, lock-screen, Accessibility, tray, and startup
  results can be recorded in the same checklist.
- [x] Missing-action `.txt` header includes a `relatedFiles` block for the
  matching diagnostics `.jsonl`, acceptance `.json`, and runbook `.json`
  filename patterns from the same validation session, plus the active export
  directory path.
- [x] Acceptance and runbook bundles exported from the same Validation section
  instance share `validationSessionId`, so evidence files from one manual run
  can be correlated later.
- [x] Validation UI shows and copies the current `validationSessionId`, and
  copied checklist/runbook JSON lines include that id for paste-based manual
  evidence.
- [x] Acceptance and runbook bundle filenames include the current
  `validationSessionId`, so exported bundles can be matched to diagnostic
  `.jsonl` files before opening them.
- [x] HomePage shares the same `validationSessionId` across Validation and Logs;
  diagnostic `.jsonl` exports include that id in the filename and each JSON
  line so raw logs, acceptance bundles, and runbook bundles can be correlated.
- [x] Validation UI shows and copies the active export directory path, so
  manual validation can locate evidence files before exporting or after a long
  runtime run.
- [x] Validation UI can export the full validation evidence set in one action:
  diagnostics `.jsonl`, acceptance `.json`, runbook `.json`, and
  missing-actions `.txt`, all sharing the same `validationSessionId`.
- [x] One-action validation export also writes a manifest `.json` listing the
  generated evidence files, export directory, readiness state, missing required
  evidence labels, next action list, and environment metadata for that
  validation session.
- [x] The validation manifest includes external validation gate summary counts,
  including passed, failed, pending, completed, incomplete, pending gate labels,
  and failed gate labels, so Windows/real-device acceptance status can be
  audited without manually reading every gate object.
- [x] The acceptance bundle, runbook bundle, validation manifest, and
  Validation UI expose overall acceptance readiness by combining runtime
  checklist readiness with external gate pending/failed status, so manual runs
  cannot be mistaken for complete while Windows or real-device gates are still
  unresolved.
- [x] Validation UI shows external gate summary counts for resolved, pending,
  and failed gates, so manual acceptance runs can see external validation
  progress before exporting bundles.
- [x] External validation gates render as collapsible editors with status and
  result summaries in the collapsed row, keeping the Validation section usable
  during long Windows and real-device acceptance runs.
- [x] Validation UI can copy external validation gates as JSON lines scoped by
  `validationSessionId`, so Windows and real-device gate status can be shared
  without opening the full acceptance or runbook bundle.
- [x] Each external validation gate editor can copy only that gate as
  `validationSessionId`-scoped JSON, so a single Windows or real-device result
  can be pasted into notes without unrelated gate records.
- [x] Each external validation gate editor can export only that gate as a
  `validationSessionId`-scoped JSON file, so a single Windows or real-device
  proof can be archived independently from the full evidence bundle.
- [x] Single external gate export JSON includes `schemaVersion`, `bundleType`,
  `exportedAt`, and environment metadata, so a copied Windows or real-device
  proof remains self-describing outside the full evidence bundle.
- [x] Single external gate export writes a cumulative
  `externalValidationGateIndex` JSON alongside the proof file, listing gate id,
  label, status, filename, and path so split Windows/real-device validation
  files can be collected later without losing earlier gate proofs from the same
  validation session.
- [x] External gate index merge and parsing are covered in the validation
  export helper, including duplicate gate replacement and malformed index
  input, keeping the Validation UI focused on orchestration.
- [x] Latest external gate index file discovery is covered in the validation
  export helper, including missing directories, empty directories, malformed
  JSON, and choosing the newest index file for the active validation session.
- [x] Validation UI can copy the latest cumulative external gate index, so
  split Windows/real-device proof files can be pasted into acceptance notes
  without manually finding the newest index file.
- [x] Validation UI can export the latest cumulative external gate index, so
  the final split Windows/real-device proof index can be archived on demand.
- [x] Validation UI and manifest list external validation gates for Windows
  build verification, real BLE scan, lock-screen scan continuity, macOS
  Accessibility unlock, tray actions, and startup-at-login actions as
  `manualRequired`, so unverified external work is visible instead of implied.
- [x] Validation UI can mark those external validation gates as pending,
  passed, or failed, and the current statuses are exported in the acceptance
  bundle, runbook bundle, validation manifest, and missing-actions `.txt` file
  for structured manual acceptance tracking.
- [x] External validation gate definitions, status serialization, manifest
  generation, missing-actions text generation, and one-action evidence file
  writing are now isolated in a pure Dart validation export helper with
  assertion coverage. Standalone acceptance, runbook, and missing-action
  exports reuse the same helper writer, keeping the Validation widget focused
  on interaction and export orchestration.
- [x] Runtime acceptance evidence now has a dedicated Validation section, so
  checklist status, checklist copy, and acceptance bundle export are separated
  from raw log filtering and diagnostics.
- [x] Acceptance bundle JSON records `exportSource=validationSection` when
  exported from the dedicated Validation section, making manual evidence source
  explicit.
- [x] Acceptance summary and Validation UI now show required-checklist progress
  and missing required evidence labels, so runtime validation can identify the
  remaining manual proof points directly from the app and exported bundle.
- [x] Acceptance checklist is platform-capability aware: unsupported automatic
  unlock, including Windows first version, is reported as `unsupported` and not
  as a missing required macOS unlock validation item.
- [x] Tray/menu acceptance evidence is split into open settings, start
  monitoring, pause monitoring, lock now, and quit actions, so the MVP tray
  acceptance criterion can be verified item-by-item instead of by a single
  aggregate `trayAction` flag.
- [x] Startup-at-login acceptance evidence is split into enable and disable
  actions, so LaunchAgent/HKCU Run validation can prove both sides of the
  toggle instead of only proving that some startup setting changed.
- [x] Scan diagnostic logs include current session state (`unlocked`, `locked`,
  display/system sleep or wake) to validate whether advertisements continue
  while the desktop session is locked or sleeping.
- [x] Logs can be filtered by category, level, and identity text to inspect
  scan, decision, action, and error events during real device validation.
- [x] Logs can be filtered by session state so locked-session BLE behavior can
  be inspected without reading raw JSON lines.
- [x] Coordinator-generated action, decision, and error logs carry current
  session context, so session filters preserve surrounding diagnostic events.
- [x] Logs summarize each observed session state with log count, scan count,
  latest scan time, device id, and RSSI for lock-screen BLE validation.
- [x] Logs can copy the current session-state summary as JSON lines for
  sharing locked-session BLE evidence.
- [x] Scan logs are summarized per device with seen count, RSSI range, latest
  RSSI, last seen time, and identity stability indicators.
- [x] Per-device diagnostics include average RSSI, average advertisement
  interval, and longest silent gap for passive-scan reliability checks.
- [x] Tray/menu status updates include a recent device summary, preferring
  selected devices and showing the best current RSSI when scan data exists.
- [x] Tray/menu start and pause monitoring actions are handled by the
  coordinator and logged with `trayAction`, so tray validation can be
  distinguished from main-window user actions.
- [x] Tray/menu status payloads include `isMonitoring`, and native macOS/Windows
  menus show either Start Monitoring or Pause Monitoring according to current
  monitoring state.
- [x] Manual and tray lock requests check session capability first and log
  `lockUnavailable` instead of calling unsupported platform lock actions.
- [x] Monitoring starts a periodic proximity tick so `lockDelay` and
  `noSignalTimeout` decisions can fire even when no new BLE advertisement
  arrives.
- [x] Proximity-triggered lock is skipped while the app already considers the
  session locked, avoiding repeated lock calls and tick-driven log noise.
- [x] Repeated proximity lock skips while already locked are logged once per
  locked-state cycle with `sessionAlreadyLocked`, so diagnostics explain why
  the action was skipped without overwriting the last real lock action.
- [x] macOS automatic unlock confirms the session is locked before password
  submission and logs `sessionNotLocked` when proximity fires while unlocked.
- [x] Repeated automatic-unlock failures are covered by coordinator tests and
  throttled through the shared action-throttle path, avoiding rapid repeated
  password input attempts.
- [x] Pending automatic-unlock retries now log `Unlock retry skipped` with a
  concrete reason such as `sessionNotLockedForRetry` when session unlock/wake
  cancels a queued retry, so retry disappearance is diagnosable.
- [x] Automatic-unlock retry execution also logs `Unlock retry skipped` with
  `sessionNotLockedForRetry` when the retry timer fires after the session has
  silently become unlocked, covering lock-state changes without a session event.
- [x] Automatic-unlock retry execution now reports other timer-fired guard
  skips with explicit reasons, including `monitoringStoppedForRetry`,
  `autoUnlockDisabledForRetry`, `unlockUnavailableForRetry`, and
  `sessionUnavailableForRetry`, so retry attempts no longer disappear silently
  when runtime capabilities change during the delay.
- [x] Starting monitoring now ensures session-event subscription is active even
  when the coordinator is exercised through `startMonitoring()` directly,
  keeping lock/unlock state and retry cancellation behavior independent of app
  initialization order.
- [x] Unsupported automatic unlock capability, including Windows first version,
  is gated in the System UI so password input is not shown or collected even if
  a caller accidentally requests the password row.
- [x] macOS and Windows platform packages exist with channel-backed bridge
  sources and pure Dart test doubles.
- [x] macOS native bridge source covers BLE scanning, session events, Keychain,
  menu bar tray, LaunchAgent startup, automatic unlock, and Accessibility
  settings recovery.
- [x] macOS BLE scan payload exposes the CoreBluetooth peripheral UUID as
  `addressHint`, matching the shared diagnostics/export field while avoiding an
  unavailable BLE MAC-address assumption.
- [x] macOS scanner capability probing and event subscription no longer create
  `CBCentralManager` during first-window initialization. Bluetooth privacy
  access is deferred until an explicit scan/monitoring start, avoiding the
  startup TCC crash observed in debug and release smoke runs.
- [x] Windows native bridge source covers BLE scan skeleton, scanner capability
  probing, session actions/events, Credential Manager, tray, startup, and
  unsupported automatic unlock.
- [x] Windows BLE scan payload keeps a compact Bluetooth address as `deviceId`
  while exposing colon-separated `addressHint` for readable diagnostics and
  acceptance bundles.
- [x] Windows startup-at-login source uses a Flutter-specific HKCU Run value
  name so the new app does not overwrite a legacy `BLEUnlock` startup entry.
- [x] Windows channel platform construction explicitly wires the unsupported
  unlock provider so first-version Windows automatic unlock stays reserved
  instead of silently inheriting a future implementation.
- [x] macOS and Windows Dart platform wrappers forward malformed native event
  payloads and native event-stream errors through their public streams, allowing
  the app coordinator to record structured scanner/session/tray failures.
- [x] App coordinator tests cover scanner, session, and tray public stream
  errors end-to-end, proving native event failures become dashboard error logs.
- [x] Assertion-based async test entrypoints return `Future<void>` so pure Dart
  tests cannot falsely exit green before awaited checks finish.
- [x] `bleunlock_app` Flutter package resolution, widget tests, default
  platform factory tests, and package analysis are verified after allowing
  Flutter SDK cache access.
- [x] `bleunlock_app` macOS debug build is verified, including Flutter Runner,
  CocoaPods, plugin registration, and Swift plugin compilation.
- [x] `bleunlock_app` macOS debug startup smoke is verified after deferring
  CoreBluetooth initialization: `flutter run -d macos --debug` stayed attached
  beyond the prior TCC crash window, and no newer `bleunlock_app-*.ips` crash
  report appeared after `bleunlock_app-2026-05-29-141452.ips`.
- [x] `bleunlock_app` macOS release build is verified. The release app bundle
  passes deep code-sign validation and its entitlements include sandbox and
  Bluetooth access without `get-task-allow`.
- [ ] Windows native code has source-level coverage only on the current macOS
  host. A Windows Flutter build is still required to verify WinRT and Win32
  linkage.
- [ ] Runtime behavior still needs local desktop validation: real BLE scan,
  lock-screen scan continuity, macOS Accessibility unlock, and tray/startup
  actions.

Latest verified commands:

```sh
dart --enable-asserts flutter/packages/bleunlock_core/test/proximity_config_test.dart
dart --enable-asserts flutter/packages/bleunlock_core/test/proximity_engine_test.dart
dart --enable-asserts flutter/packages/bleunlock_platform_interface/test/platform_interface_contract_test.dart
dart --enable-asserts flutter/packages/bleunlock_app/test/dashboard_state_test.dart
dart --enable-asserts flutter/packages/bleunlock_app/test/settings_repository_test.dart
dart --enable-asserts flutter/packages/bleunlock_app/test/app_coordinator_test.dart
dart --enable-asserts flutter/packages/bleunlock_app/test/validation_evidence_export_test.dart
dart --enable-asserts flutter/packages/bleunlock_macos/test/macos_platform_test.dart
dart --enable-asserts flutter/packages/bleunlock_windows/test/windows_platform_test.dart
swiftc -parse flutter/packages/bleunlock_macos/macos/Classes/BleunlockMacosPlugin.swift
cd flutter/packages/bleunlock_app && flutter run -d macos --debug
cd flutter/packages/bleunlock_app && flutter test
cd flutter/packages/bleunlock_app && HOME=/private/tmp DART_SUPPRESS_ANALYTICS=true flutter test
cd flutter/packages/bleunlock_app && flutter test test/default_platform_factory_test.dart --plain-name 'keeps Windows automatic unlock unsupported in first version'
cd flutter/packages/bleunlock_app && flutter test test/widget_test.dart --plain-name 'unsupported auto unlock does not show password input'
cd flutter/packages/bleunlock_app && flutter test test/widget_test.dart --plain-name 'logs show structured diagnostic details'
cd flutter/packages/bleunlock_app && flutter test test/widget_test.dart --plain-name 'acceptance readiness shows runtime action checklist'
cd flutter/packages/bleunlock_app && flutter test test/widget_test.dart --plain-name 'acceptance readiness marks unsupported auto unlock'
cd flutter/packages/bleunlock_app && flutter test test/widget_test.dart --plain-name 'acceptance readiness shows tray menu action checklist'
cd flutter/packages/bleunlock_app && flutter test test/widget_test.dart --plain-name 'acceptance readiness shows startup enable disable checklist'
cd flutter/packages/bleunlock_app && flutter test test/widget_test.dart --plain-name 'exports acceptance bundle before any log is recorded'
cd flutter/packages/bleunlock_app && flutter test test/widget_test.dart --plain-name 'exports acceptance bundle with config and summaries'
cd flutter/packages/bleunlock_app && flutter analyze
cd flutter/packages/bleunlock_app && flutter build macos --debug
cd flutter/packages/bleunlock_app && flutter build macos --release
cd flutter/packages/bleunlock_app && HOME=/private/tmp DART_SUPPRESS_ANALYTICS=true flutter build macos --debug
cd flutter/packages/bleunlock_app && HOME=/private/tmp DART_SUPPRESS_ANALYTICS=true flutter build macos --release
cd flutter/packages/bleunlock_app && codesign --verify --deep --strict --verbose=2 build/macos/Build/Products/Release/bleunlock_app.app
cd flutter/packages/bleunlock_app && codesign -d --entitlements :- build/macos/Build/Products/Release/bleunlock_app.app
dart analyze flutter/packages/bleunlock_core flutter/packages/bleunlock_platform_interface flutter/packages/bleunlock_macos/lib/bleunlock_macos.dart flutter/packages/bleunlock_macos/lib/src/macos_platform.dart flutter/packages/bleunlock_macos/test/macos_platform_test.dart flutter/packages/bleunlock_windows/lib/bleunlock_windows.dart flutter/packages/bleunlock_windows/lib/src/windows_platform.dart flutter/packages/bleunlock_windows/test/windows_platform_test.dart flutter/packages/bleunlock_app/lib/src/controllers/app_coordinator.dart flutter/packages/bleunlock_app/lib/src/controllers/capability_monitor.dart flutter/packages/bleunlock_app/lib/src/view_models/dashboard_state.dart flutter/packages/bleunlock_app/lib/src/home_page.dart flutter/packages/bleunlock_app/lib/src/sections/overview_section.dart flutter/packages/bleunlock_app/lib/src/sections/device_section.dart flutter/packages/bleunlock_app/lib/src/sections/log_section.dart flutter/packages/bleunlock_app/lib/src/sections/rules_section.dart flutter/packages/bleunlock_app/lib/src/sections/system_section.dart flutter/packages/bleunlock_app/lib/src/platforms/bleunlock_platform.dart flutter/packages/bleunlock_app/lib/src/platforms/mock_bleunlock_platform.dart flutter/packages/bleunlock_app/test/app_coordinator_test.dart flutter/packages/bleunlock_app/test/dashboard_state_test.dart flutter/packages/bleunlock_app/test/widget_test.dart flutter/packages/bleunlock_app/test/default_platform_factory_test.dart
plutil -lint flutter/packages/bleunlock_app/macos/Runner/Info.plist flutter/packages/bleunlock_app/macos/Runner/DebugProfile.entitlements flutter/packages/bleunlock_app/macos/Runner/Release.entitlements flutter/packages/bleunlock_macos/macos/Resources/PrivacyInfo.xcprivacy
```

---

### Task 1: Create Isolated Workspace Skeleton

**Files:**
- Create: `flutter/README.md`
- Create: `flutter/packages/bleunlock_core/pubspec.yaml`
- Create: `flutter/packages/bleunlock_platform_interface/pubspec.yaml`

- [x] **Step 1: Add workspace README**

Create `flutter/README.md` explaining that this directory contains the new Flutter/Dart implementation and that the legacy Swift app remains untouched.

- [x] **Step 2: Add package manifests**

Create pure Dart package manifests for `bleunlock_core` and `bleunlock_platform_interface`, both constrained to Dart SDK `>=3.6.0 <4.0.0`.

- [x] **Step 3: Verify package files exist**

Run: `find flutter -maxdepth 3 -type f -print | sort`

Expected: README and both `pubspec.yaml` files are listed.

### Task 2: Implement Core Proximity Behavior With Tests

**Files:**
- Create: `flutter/packages/bleunlock_core/lib/bleunlock_core.dart`
- Create: `flutter/packages/bleunlock_core/lib/src/models.dart`
- Create: `flutter/packages/bleunlock_core/lib/src/rssi_smoother.dart`
- Create: `flutter/packages/bleunlock_core/lib/src/proximity_engine.dart`
- Create: `flutter/packages/bleunlock_core/test/proximity_engine_test.dart`

- [x] **Step 1: Write behavior tests**

Write assertion-based tests covering RSSI smoothing, close detection, delayed away lock, lost timeout, and multi-device any/all rules.

- [x] **Step 2: Run tests and confirm RED**

Run: `dart --enable-asserts flutter/packages/bleunlock_core/test/proximity_engine_test.dart`

Expected: failure because implementation files do not exist yet.

- [x] **Step 3: Implement minimal core**

Implement immutable models, a moving-average RSSI smoother, and `ProximityEngine` with passive-scan state transitions.

- [x] **Step 4: Run tests and confirm GREEN**

Run: `dart --enable-asserts flutter/packages/bleunlock_core/test/proximity_engine_test.dart`

Expected: all tests print `All proximity engine tests passed.`

### Task 3: Implement Platform Interface Contracts

**Files:**
- Create: `flutter/packages/bleunlock_platform_interface/lib/bleunlock_platform_interface.dart`
- Create: `flutter/packages/bleunlock_platform_interface/lib/src/capability_status.dart`
- Create: `flutter/packages/bleunlock_platform_interface/lib/src/events.dart`
- Create: `flutter/packages/bleunlock_platform_interface/lib/src/interfaces.dart`
- Create: `flutter/packages/bleunlock_platform_interface/test/platform_interface_contract_test.dart`

- [x] **Step 1: Write contract compile test**

Write assertion-based tests with fake implementations for scanner, session, secure store, tray, startup, and unlock provider interfaces.

- [x] **Step 2: Run tests and confirm RED**

Run: `dart --enable-asserts flutter/packages/bleunlock_platform_interface/test/platform_interface_contract_test.dart`

Expected: failure because interface files do not exist yet.

- [x] **Step 3: Implement minimal contracts**

Define capability statuses, typed platform events, and abstract platform interfaces from the design spec.

- [x] **Step 4: Run tests and confirm GREEN**

Run: `dart --enable-asserts flutter/packages/bleunlock_platform_interface/test/platform_interface_contract_test.dart`

Expected: all tests print `All platform interface contract tests passed.`

### Task 4: Format and Verify

**Files:**
- Modify only files under `flutter/` and `docs/superpowers/plans/`.

- [x] **Step 1: Format Dart files**

Run: `dart format flutter/packages/bleunlock_core flutter/packages/bleunlock_platform_interface`

Expected: formatter completes successfully.

- [x] **Step 2: Run all assertion tests**

Run core test:

```sh
dart --enable-asserts flutter/packages/bleunlock_core/test/proximity_engine_test.dart
```

Run platform interface test:

```sh
dart --enable-asserts flutter/packages/bleunlock_platform_interface/test/platform_interface_contract_test.dart
```

Expected: both scripts print success messages.

- [x] **Step 3: Inspect git status**

Run: `git status --short`

Expected: existing `docs/` plus new `flutter/` files are untracked or modified; no legacy Swift files are modified.

### Task 5: Add Flutter App Shell

**Files:**
- Create/Modify: `flutter/packages/bleunlock_app/pubspec.yaml`
- Create/Modify: `flutter/packages/bleunlock_app/lib/main.dart`
- Create/Modify: `flutter/packages/bleunlock_app/test/widget_test.dart`
- Modify: `flutter/README.md`

- [x] **Step 1: Generate app shell**

Run:

```sh
flutter create --no-pub --platforms=macos,windows --project-name bleunlock_app --org com.github.skyearn flutter/packages/bleunlock_app
```

Expected: Flutter creates macOS and Windows desktop scaffolding under `flutter/packages/bleunlock_app`.

- [x] **Step 2: Replace template counter app**

Replace the generated counter app with a BLEUnlock settings shell containing Overview, Devices, Rules, System, and Logs sections.

- [x] **Step 3: Add local path dependencies**

Add local path dependencies from `bleunlock_app` to `../bleunlock_core` and `../bleunlock_platform_interface`.

- [x] **Step 4: Add widget smoke test**

Replace the counter widget test with a smoke test that verifies the settings shell renders the main section labels and default threshold values.

- [x] **Step 5: Verify app when Flutter package resolution is available**

Run:

```sh
cd flutter/packages/bleunlock_app
flutter pub get
flutter test
flutter analyze
```

Expected: package resolution succeeds, widget test passes, and analysis reports no issues.

Current result: verified with explicit Flutter SDK cache access on 2026-05-29.
