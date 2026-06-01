# Windows v1 Design

## Goal
Ship a Windows v1 that is usable for daily testing and local validation without pretending to support automatic unlock.

## In scope
- BLE scan, device ranking, and proximity decision flow
- Auto lock and wake behavior
- Tray menu and startup at login
- Secure storage for secrets
- Validation and diagnostics pages that clearly show Windows v1 readiness
- Explicit unsupported status for Windows automatic unlock in v1

## Out of scope
- Windows automatic unlock implementation
- Credential Provider / login desktop integration
- Installer/signing work beyond a release zip

## Product decision
Windows v1 should be framed as an automatic-lock build, not an automatic-unlock build.
The UI must state that automatic unlock is unsupported on Windows v1, while still showing the rest of the platform as ready or pending according to runtime evidence.

## UI and data model changes
- Surface the active platform label in the dashboard snapshot.
- Add a Windows v1 readiness message that depends on the platform label and auto-unlock capability.
- Keep the auto-unlock capability as an unsupported state on Windows.
- Add a Windows v1 readiness row in the System section and a Windows-specific acceptance hint in the Validation section.
- Keep the existing macOS auto-unlock flow unchanged.

## Validation changes
- Keep the existing runtime evidence model for BLE scan, lock, wake, tray, and startup.
- Treat auto-unlock as required only for macOS-capable flows.
- For Windows, show auto-unlock as explicitly unsupported and exclude it from the required acceptance count.
- Add a Windows v1 readiness checklist entry that confirms the app is on Windows and that automatic unlock is intentionally unsupported.

## Test coverage
- Snapshot/model tests for Windows v1 readiness status.
- Widget tests that verify the Windows readiness message appears.
- Acceptance tests that verify Windows auto-unlock remains unsupported and is excluded from required readiness.

## Current progress
- Windows v1 scope has been encoded in the dashboard snapshot and acceptance summary:
  - Windows platform label is exported in diagnostics.
  - Windows v1 readiness label is shown when automatic unlock is unsupported by design.
  - Validation adds a Windows v1 scope checklist item instead of requiring automatic unlock evidence.
- The System section now shows a Windows v1 readiness row.
- The Validation section now exposes the Windows v1 readiness boundary.
- The macOS automatic unlock flow remains unchanged.
- The Windows native plugin now compiles on Windows with the current fixes:
  - `flutter/encodable_value.h` included for encodable map/list values.
  - `winrt/Windows.Foundation.Collections.h` included for WinRT collection types.
  - `/utf-8` enabled for the plugin target.

## Verified on Windows
- `dart run .\test\dashboard_state_test.dart` passed.
- `flutter test test/widget_test.dart` passed.
- `.\scripts\build-windows-x64.ps1` passed on a Windows host.
- Release artifact produced:
  - `flutter\packages\bleunlock_app\build\windows\bleunlock_app-windows-x64.zip`
  - SHA256: `C8D8E8694275187AE2939DDFBF711025326714D1F15748187A98947BEF18ACDE`

## Handoff notes for macOS continuation
- Windows automatic unlock is still intentionally unsupported in v1.
- Windows v1 should continue to focus on BLE scan, automatic lock, wake, tray, startup, secure storage, logs, and diagnostics.
- The next Windows validation step is runtime testing on real hardware: BLE advertisements, RSSI stability, lock/wake behavior, session events, Credential Manager, tray menu actions, and startup-at-login behavior.
- If macOS work pulls this branch, verify the Flutter lockfile and generated registrant files against the macOS Flutter SDK before release work.

## Non-goals
- No fake Windows unlock fallback.
- No UI that implies Windows auto-unlock is available in v1.
