# bleunlock_app

Cross-platform Flutter shell for the next-generation BLEUnlock desktop app.

## Scope

- Main settings window first.
- Tray/menu bar support through platform packages.
- macOS and Windows desktop targets.
- Core proximity logic comes from `bleunlock_core`.
- Platform capability contracts come from `bleunlock_platform_interface`.

## Current State

This package is the first settings-window shell. It renders Overview, Devices,
Rules, System, and Logs sections, routes scan events through
`bleunlock_core`, persists selected devices and proximity rules, and wires to
the channel-backed macOS/Windows platform packages at runtime. The Devices
section shows discovered device names, platform IDs, RSSI, proximity state, and
last seen time. Long platform IDs are presented as short codes for scanning,
while the full id remains the internal selection and log key. The Overview
section includes quick actions for monitoring control and immediate lock.

The System section can save and clear the macOS automatic-unlock password. The
password is written through `SecureStore` under `macosAutomaticUnlockPassword`;
it is not stored in the JSON settings payload. The app requires an explicit
security acknowledgement before enabling macOS automatic unlock, and the
password input is only shown after the feature is enabled on a configurable
platform. When automatic unlock is unsupported, the Rules switch is disabled so
Windows does not present a configurable password feature.

The coordinator throttles repeated lock, wake, and unlock decisions. For macOS
automatic unlock, it first confirms that the session is currently locked before
calling the unlock provider. If the proximity rule fires while the session is
already unlocked, the app logs `sessionNotLocked` and skips password submission.
It also schedules one delayed retry if the password submit call succeeds but the
session still reports locked. While monitoring is active, the coordinator runs a
periodic proximity tick so delayed lock and no-signal lost decisions can fire
even when no new BLE advertisement arrives. Once the app has entered a locked
session state, proximity-triggered lock requests are skipped so a sustained
away/lost state does not repeatedly call the platform lock API or fill the
diagnostic log with throttle entries.

Session wake, sleep, lock, and unlock events refresh startup state, scanner
capability, automatic-unlock capability, and password status so permission or
secret changes do not stay stale in the UI. When the screen is locked, the
Overview aggregate state is shown as `Locked` instead of only relying on the
last action label.

Tray/menu status updates include the current app status plus a recent device
summary, such as the selected device name and RSSI when scan data is available.
Manual lock requests from the main window or tray first check session
capability; permission or unsupported failures are logged as `lockUnavailable`
without calling the platform lock action. Tray start and pause monitoring
actions are logged with `trayAction`, so tray validation can be separated from
main-window user actions in diagnostics. The app also passes `isMonitoring` to
native tray implementations, so macOS and Windows menus show either Start
Monitoring or Pause Monitoring according to current state.

The System section also exposes a manual capability refresh action. It reruns
the same scanner/startup/automatic-unlock checks and logs a `capabilityRetry`
action so permission recovery is visible in diagnostics.
Automatic capability refreshes are throttled by reason to avoid repeated
permission prompts or event loops. Manual retry and password save/clear paths
force a fresh check.

When macOS automatic unlock reports missing Accessibility permission, the
System section shows an Accessibility settings button. The button delegates to
the platform unlock provider instead of hardcoding system URLs in the app
layer.

Tray open-settings and quit actions are exposed as app-level commands. The
Flutter shell returns to the root settings view for open-settings and requests a
clean Flutter application exit for quit.

Blocking capability failures are logged with the concrete capability label, so
logs can distinguish Bluetooth powered off, permission denied, unsupported lock,
and automatic-unlock permission or secret failures from generic action failure.
Unsupported automatic unlock is logged as an unsupported action, not as an
error, because it is an expected first-version Windows limitation. Log rows show
the level and platform label plus available device id, RSSI, and reason
metadata, including scan display name, address hint, and manufacturer data when
the platform provides them. The Logs section can copy the current diagnostic log
as JSON lines so real scan sessions can be inspected for device identity, RSSI,
decision reason, session state, and platform capability failures. It can also
export the current filtered diagnostic log to a local `.jsonl` file under the
system temporary diagnostics directory, which is useful for runtime BLE and
lock-screen acceptance evidence. Windows scan logs keep the compact Bluetooth
address as the stable `deviceId` and expose a colon-separated `addressHint` for
readable diagnostics. It can also export an acceptance bundle JSON
containing the current dashboard snapshot, proximity config, visible logs,
session diagnostics, and device diagnostics for real BLE and lock-screen
validation. Acceptance bundle export remains available before the first log
entry so first-start capability and config baselines can be captured. The
bundle also includes export source, platform, OS version, Dart version, and
build mode metadata so runtime evidence is self-describing across macOS and
Windows. It also includes an acceptance summary with log/device counts,
selected-device count, observed sessions/devices, and evidence flags for scan,
locked-session scan, decision, action, and error events. Scan log entries
include `sessionState` values
such as `unlocked`, `locked`,
`displaySleep`, and `systemWake` to help verify whether advertisements continue
while the desktop session is locked or sleeping. The Logs section shows the
same acceptance readiness status before export, so manual runs can confirm
selected-device count and scan, locked-scan, decision, action, and error
evidence without opening the JSON bundle. Coordinator-generated action,
decision, and error logs also carry the current session context so filtered
diagnostics keep surrounding events. Logs can also be filtered by
category, level, and identity text such as device id, display name, address
hint, reason, session state, or manufacturer data. A dedicated Session filter
can narrow the log view to advertisements seen while unlocked, locked, display
sleeping, or system sleeping/waking. The Logs section also shows session
diagnostics with log counts, scan counts, latest event time, latest scan time,
device id, and RSSI for each observed session state. This makes locked-session
BLE validation visible without reading raw JSON lines. The current session
summary can also be copied as JSON lines for sharing lock-screen scan evidence.
The Logs section summarizes scan events per device, including seen count, RSSI
range, latest RSSI, last seen time, and whether identity fields changed across
advertisements. It also reports average RSSI, average advertisement interval,
and longest silent gap to help tune passive-scan thresholds.

The dedicated Validation section groups the required runtime checklist into
higher-level steps for BLE scan, lock and wake, macOS auto unlock, tray menu,
and startup at login. Each step shows captured/required progress plus the
latest supporting evidence time, while the detailed rows still expose the
individual checklist evidence counts and timestamps. The same steps can be
copied as runbook JSON lines with the action to perform, expected evidence,
current status, and missing required labels. The runbook can also be exported
as a dedicated JSON bundle with environment metadata, the current
snapshot/config, acceptance summary, runbook steps, and runbook JSON lines.
The UI and bundle also include missing-only runbook steps so manual validation
can focus on proof points that are not captured yet. Missing runbook steps also
carry next-action hints for concrete runtime actions such as moving the
selected device, using tray menu items, or toggling startup at login. The
Validation section shows those next-action hints near the readiness summary so
manual validation can start with the most relevant runtime action before
opening exports. It can copy a concise missing-action list, and the runbook
bundle exports the same list for offline validation notes. It can also export
that missing-action list as a standalone `.txt` file with the current
`validationSessionId` in its filename. The `.txt` file also includes a compact
metadata header with validation id, export time, platform, OS version, and build
mode before a numbered action list. Each numbered item includes empty `result`,
`evidence`, and `notes` placeholders for recording manual validation output.
The `.txt` file also includes the external validation gates with
`manualRequired` status and the same `result`, `evidence`, and `notes`
placeholders.
The header also has a `relatedFiles` block for the matching diagnostics
`.jsonl`, acceptance `.json`, and runbook `.json` filename patterns, plus the
active export directory path.
Acceptance and runbook bundles exported from the
same Validation section instance share a
`validationSessionId`, making evidence files from one manual run easier to
correlate later. The Validation section shows that id, can copy it directly,
injects it into copied checklist and runbook JSON lines, and includes it in
acceptance/runbook bundle filenames. The home page also passes that same id to
the Logs section;
diagnostic `.jsonl` exports include the id in both the filename and each JSON
line so raw logs, acceptance bundles, and runbook bundles can be matched. The
Validation section also shows the active export directory and can copy that
path before any export action, making evidence files easier to find during
manual validation. It also has a single validation-evidence export action that
writes diagnostics `.jsonl`, acceptance `.json`, runbook `.json`, and
missing-actions `.txt` files with the same `validationSessionId`. The same
action also writes a validation manifest `.json` that lists the generated
files, export directory, readiness state, missing required evidence labels,
next action list, and environment metadata. The Validation section and manifest
also list external validation gates for Windows build verification, real BLE
scan, lock-screen scan continuity, macOS Accessibility unlock, tray actions,
and startup-at-login actions. Those gates can be marked pending, passed, or
failed in the Validation section, and the current gate statuses are exported in
the acceptance bundle, runbook bundle, validation manifest, and missing-actions
`.txt` file. Gate definitions, status serialization, manifest generation, and
missing-actions text generation live in a pure Dart validation export helper;
the same helper writes the one-action evidence file set, standalone
acceptance/runbook/missing-action exports, and the file index used by the
manifest, so the export format can be tested independently from the widget.

Run checks from the repository root:

```sh
dart --enable-asserts flutter/packages/bleunlock_app/test/dashboard_state_test.dart
dart --enable-asserts flutter/packages/bleunlock_app/test/app_coordinator_test.dart
dart --enable-asserts flutter/packages/bleunlock_app/test/settings_repository_test.dart
```

Run Flutter checks from this package directory:

```sh
flutter test
flutter analyze
flutter build macos --debug
flutter build macos --release
codesign --verify --deep --strict --verbose=2 build/macos/Build/Products/Release/bleunlock_app.app
codesign -d --entitlements :- build/macos/Build/Products/Release/bleunlock_app.app
```

`test/default_platform_factory_test.dart` and the widget tests must run through
Flutter's test runner because they import Flutter bindings and channel-backed
platform implementations. The macOS debug build verifies the Flutter Runner,
CocoaPods, generated plugin registration, and Swift plugin compilation. The
release build verifies the production macOS entitlement set and app bundle
signature.
