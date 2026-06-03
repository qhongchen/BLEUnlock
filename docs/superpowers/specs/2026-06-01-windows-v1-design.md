# Windows v1 Design

## Goal
Ship a Windows v1 that is usable for daily testing and local validation with honest automatic-unlock capability reporting.

## In scope
- BLE scan, device ranking, and proximity decision flow
- Auto lock and wake behavior
- Tray menu and startup at login
- Secure storage for secrets
- Validation and diagnostics pages that clearly show Windows v1 readiness
- Windows automatic-unlock app-side wiring
- Credential Provider capability placeholder for Windows automatic unlock

## Out of scope
- Credential Provider DLL implementation
- Credential Provider installer, service, registration, and login desktop integration
- Installer/signing work beyond a release zip

## Product decision
Windows automatic unlock must be Credential Provider-backed.
The Flutter app can expose the capability, diagnostics, and validation boundary, but it must not fake unlock behavior or collect the Windows login password.
Until the Credential Provider component is installed, Windows automatic unlock reports `Credential Provider component is not installed` and unlock attempts return `credentialProviderMissing`.
Windows proximity wake is allowed to request the display and login surface, so Windows Hello can take over when the device and policy already support it. This is wake guidance, not app-side authentication.

## UI and data model changes
- Surface the active platform label in the dashboard snapshot.
- Add a Windows Credential Provider readiness message that depends on the platform label and auto-unlock capability.
- Keep Windows automatic unlock as `temporarilyUnavailable` until the Credential Provider component is installed.
- Add a Windows Credential Provider row in the System section and a Windows-specific acceptance hint in the Validation section.
- Keep the existing macOS auto-unlock flow unchanged.
- Keep the macOS auto-unlock password UI macOS-only.

## Validation changes
- Keep the existing runtime evidence model for BLE scan, lock, wake, tray, and startup.
- Treat auto-unlock as required only for macOS-capable flows.
- For Windows, exclude the macOS Accessibility unlock gate.
- Add a Windows Credential Provider checklist entry that remains missing until the component reports ready.

## Test coverage
- Snapshot/model tests for Windows Credential Provider readiness status.
- Widget tests that verify the Windows Credential Provider message appears.
- Acceptance tests that verify Windows does not require the macOS unlock gate.

## Current progress
- Windows Credential Provider readiness has been encoded in the dashboard snapshot and acceptance summary:
  - Windows platform label is exported in diagnostics.
- Windows readiness label now distinguishes Credential Provider ready, missing, and pending states.
- Validation adds a Windows Credential Provider checklist item and excludes the macOS Accessibility unlock gate on Windows.
- The System section now shows a Windows Credential Provider readiness row.
- The Validation section now exposes the Windows Credential Provider boundary.
- The macOS automatic unlock flow remains unchanged.
- The Windows native plugin exposes `bleunlock_windows/unlock_methods`:
  - `getUnlockCapability` returns `temporarilyUnavailable` while the Credential Provider component is missing.
  - `unlock` returns `success=false` with `credentialProviderMissing`.
  - `openUnlockSettings` opens Windows sign-in settings.
- The Windows native wake path now requests display wake with `SetThreadExecutionState`, asks the monitor to power on, and sends a tiny mouse input pulse to help the lock screen surface become active.
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
- Windows automatic unlock is blocked on the Credential Provider component, not on app-side capability wiring.
- Windows proximity wake can light the lock screen and let Windows Hello proceed if the system chooses to, but it must not focus secure desktop controls, inject credentials, or claim authentication success.
- Windows should continue to focus on BLE scan, automatic lock, wake, tray, startup, secure storage, logs, diagnostics, and Credential Provider readiness.
- The next Windows validation step is runtime testing on real hardware: BLE advertisements, RSSI stability, lock/wake behavior, session events, Credential Manager, tray menu actions, startup-at-login behavior, and Credential Provider installation state.
- If macOS work pulls this branch, verify the Flutter lockfile and generated registrant files against the macOS Flutter SDK before release work.

## Non-goals
- No fake Windows unlock fallback.
- No Windows login password collection or storage.
- No UI that implies Windows auto-unlock works before the Credential Provider component is installed.
