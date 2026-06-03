# Flutter Cross-Platform BLEUnlock Design

Date: 2026-05-28

Status: Draft approved for documentation only. No implementation is included in this spec.

## 1. Goal

Build a new Flutter-based generation of BLEUnlock for macOS and Windows.

The new app should reduce long-term maintenance by sharing UI, configuration,
logging, and proximity decision logic across platforms, while keeping OS-specific
capabilities isolated behind platform plugins.

This is not a direct port of the existing Swift/AppKit app. It is a new
cross-platform implementation that can eventually replace the current macOS app.

## 2. Confirmed Scope

### Platforms

- Support macOS and Windows in the first cross-platform generation.
- Do not include Linux in the first scope.

### Product Direction

- Flutter version becomes the next-generation app.
- Existing macOS Swift version is not migrated in place.
- Existing user data is not migrated in the first version.
- macOS users configure the Flutter version from scratch.

### First-Version Features

- Full settings window as the main UI.
- Tray/menu bar entry for status and quick actions.
- Passive BLE scanning only.
- Device list with RSSI and recently seen state.
- Select one or more devices to monitor.
- Multi-device rules:
  - close/unlock rule: any selected device close, or all selected devices close
  - away/lock rule: all selected devices away, or any selected device away
- RSSI threshold based close/away detection.
- No-signal timeout based lost detection.
- Delayed lock after a device is away.
- Automatic lock on macOS and Windows.
- Wake-on-proximity support where the platform can provide it.
- macOS automatic unlock retained in the first version.
- Windows automatic unlock is explicitly reserved for future work.
- Capability and error states visible in UI.
- Diagnostic logs for scan, decision, action, and error events.

### Out of Scope for First Version

- Windows automatic unlock.
- Migration from existing Swift app preferences, Keychain items, or login items.
- Script callbacks on lock/unlock.
- Media pause/resume on lock/unlock.
- Active BLE connection mode for reading RSSI.
- Linux support.
- Credential Provider implementation.
- Installer/signing/release automation design beyond what is needed to define
  platform responsibilities.

## 3. Recommended Architecture

Use a Flutter main app plus federated platform plugins.

```text
BLEUnlock Flutter
└── flutter
    └── packages
        ├── bleunlock_app
        ├── bleunlock_core
        ├── bleunlock_platform_interface
        ├── bleunlock_macos
        └── bleunlock_windows
```

### Module Responsibilities

`bleunlock_app`

- Flutter UI.
- Main settings window.
- Tray/menu bar interaction surface.
- Device list presentation.
- Rule editing.
- Status and log views.
- App-level coordinator that connects platform events to core decisions.

`bleunlock_core`

- Pure Dart package.
- No Flutter UI dependency.
- No direct OS API dependency.
- Owns the proximity state machine.
- Owns RSSI smoothing.
- Owns any/all multi-device policy.
- Owns lock/unlock decision policy.
- Owns first-version configuration models.
- Should be heavily unit-tested.

`bleunlock_platform_interface`

- Pure Dart contract package.
- Defines platform capability interfaces.
- Keeps macOS and Windows details out of UI and core logic.
- Defines typed events and capability statuses.

`bleunlock_macos`

- macOS implementation of platform interfaces.
- Uses CoreBluetooth for passive BLE scanning.
- Uses Keychain for macOS unlock password storage.
- Uses AppKit/NSWorkspace notifications for session and display events.
- Uses existing macOS-style lock, wake, and simulated key input capabilities.
- Implements macOS automatic unlock.

`bleunlock_windows`

- Windows implementation of platform interfaces.
- Uses Windows BLE advertisement APIs for passive scanning.
- Uses Windows lock API for lock action.
- Uses Windows session notifications for lock/unlock state where practical.
- Uses DPAPI or Windows Credential Manager for sensitive storage.
- Provides an unsupported implementation for future automatic unlock.

## 4. Core Data Model

### `BleDevice`

Represents a device discovered by a platform BLE scanner.

```text
BleDevice
├── platformId
├── displayName
├── addressHint
├── lastRssi
├── lastSeenAt
├── manufacturerData
└── isSelected
```

Rules:

- `platformId` is the app's stable device key for the current platform.
- `platformId` must not assume a BLE MAC address is available.
- `addressHint` is optional and used only for display/logging.
- Device identity stability is a platform-specific risk, especially on Windows.

### `ProximityConfig`

Represents user-configurable proximity behavior.

```text
ProximityConfig
├── unlockRssi
├── lockRssi
├── noSignalTimeout
├── lockDelay
├── minimumVisibleRssi
├── unlockDeviceLogic
├── lockDeviceLogic
├── wakeOnProximity
└── enableMacAutoUnlock
```

Recommended defaults:

```text
minimumVisibleRssi = -90
unlockRssi = -60
lockRssi = -80
noSignalTimeout = 60s
lockDelay = 5s
unlockDeviceLogic = anyClose
lockDeviceLogic = allAway
wakeOnProximity = false
enableMacAutoUnlock = false
```

### `DevicePresence`

Represents the current interpreted state for a monitored device.

```text
DevicePresence
├── deviceId
├── smoothedRssi
├── state: close | away | lost
├── lastStateChangedAt
└── reason
```

### `PresenceDecision`

Represents an aggregate decision emitted by the core engine.

```text
PresenceDecision
├── shouldLock
├── shouldWake
├── shouldUnlock
├── reason
├── deviceStates
└── timestamp
```

Rules:

- `shouldLock` can execute on macOS and Windows.
- `shouldWake` executes only when platform capability is available.
- `shouldUnlock` executes on macOS only in the first version.
- Windows first version logs `shouldUnlock` as unsupported, not as an error.

## 5. Runtime Data Flow

```text
Platform BLE scanner
    ↓
BleScanEvent(deviceId, name, rssi, timestamp)
    ↓
ProximityEngine
    ├── update device cache
    ├── smooth RSSI
    ├── evaluate close / away / lost
    ├── aggregate any/all rules
    └── emit PresenceDecision
            ↓
AppCoordinator
    ├── shouldLock   -> SessionController.lock()
    ├── shouldWake   -> SessionController.wakeDisplay()
    ├── shouldUnlock -> FutureUnlockProvider.unlock()
    └── appendLog    -> LogStore
```

Design principle:

- Platform plugins report facts.
- Core decides state.
- App coordinator executes actions.
- UI presents state and collects user configuration.

This keeps BLE scanning, decision logic, and OS actions from becoming tangled.

## 6. Platform Interface Design

### `BleScanner`

```text
startScan()
stopScan()
events: Stream<BleScanEvent>
capability: CapabilityStatus
refreshCapability()
```

### `SessionController`

```text
lock()
wakeDisplay()
isLocked()
events: Stream<SessionEvent>
capability: CapabilityStatus
```

### `SecureStore`

```text
writeSecret(key, value)
readSecret(key)
deleteSecret(key)
capability: CapabilityStatus
```

### `TrayController`

```text
setStatus(status)
showQuickMenu()
onAction: Stream<TrayAction>
capability: CapabilityStatus
```

### `StartupManager`

```text
isEnabled()
setEnabled(bool)
capability: CapabilityStatus
```

### `FutureUnlockProvider`

```text
capability: CapabilityStatus
refreshCapability()
openPermissionSettings()
unlock()
```

`openPermissionSettings()` is a recovery hook for platforms that can guide the
user to the OS permission page needed by automatic unlock. Unsupported
platforms should implement it as a no-op.

`FutureUnlockProvider` is intentionally separate from `SessionController`
because Windows automatic unlock is a future system-level capability, not just
another session action.

## 7. Platform Capability Matrix

| Capability | macOS first version | Windows first version |
| --- | --- | --- |
| Passive BLE scan | Supported | Supported |
| Device selection | Supported | Supported |
| RSSI monitoring | Supported | Supported |
| Auto lock | Supported | Supported |
| Wake on proximity | Supported | Best effort |
| Auto unlock | Supported | Reserved, unsupported |
| Secure storage | Keychain | DPAPI or Credential Manager |
| Tray/menu bar | Supported | Supported |
| Startup at login | Supported | Supported |
| Script callbacks | Reserved | Reserved |
| Media pause/resume | Reserved | Reserved |
| Active RSSI mode | Out of scope | Out of scope |

## 8. UI Design

The first version uses a full settings window as the primary surface, with a
tray/menu bar entry for status and quick actions.

```text
Main Window
├── Overview
├── Devices
├── Rules
├── System
└── Logs
```

### Overview

- Current monitoring state.
- Current best RSSI.
- Current aggregate state: idle, monitoring, close, away, lost, locked.
- Quick actions:
  - start/pause monitoring
  - lock now

### Devices

- Scan start/stop.
- Nearby devices.
- Selected monitored devices.
- Device details:
  - display name
  - platform ID short code
  - RSSI
  - last seen time

### Rules

- Unlock/close RSSI threshold.
- Lock/away RSSI threshold.
- No-signal timeout.
- Lock delay.
- Multi-device close rule: any/all.
- Multi-device away rule: all/any.

### System

- Startup at login.
- Wake on proximity.
- macOS automatic unlock.
- Platform capability status.
- Manual capability refresh/retry.

Windows first version should show automatic unlock as unsupported or reserved,
not as a configurable password feature.

macOS automatic unlock should default to off. When enabling it, the app should
show a security notice and request the password only after the user confirms.

### Logs

Logs should answer these questions:

- Which device was seen?
- What RSSI was used?
- Why did the state become close, away, or lost?
- Why did the app lock, wake, unlock, or skip an action?
- Which capability or permission failed?

## 9. Tray/Menu Bar Design

The tray/menu bar should be lightweight.

```text
Tray/Menu Bar
├── status icon
├── open settings
├── start/pause monitoring
├── lock now
├── recent device summary
└── quit
```

It should not become the primary settings surface. Complex rules and platform
permissions belong in the main window.

## 10. Security Design

### RSSI Unlock Risk

RSSI proximity does not prove user identity. BLE advertisements can be observed
or spoofed. This is a product-level limitation, not a Flutter limitation.

When macOS automatic unlock is enabled, show a clear one-time warning:

```text
BLE signals cannot prove who is holding the device.
If the device is lost or a signal is spoofed, automatic unlock may be triggered.
Only enable this in trusted environments.
```

### Secrets

- macOS stores automatic unlock password in Keychain.
- Windows first version must not collect or store a Windows login password.
- Windows sensitive settings use DPAPI or Windows Credential Manager if needed.
- Secrets should never be written to logs.

### Windows Automatic Unlock

Windows automatic unlock is explicitly not part of the first version.

The design keeps `FutureUnlockProvider` so future work can explore Credential
Provider, a helper service, an installer, signing, and recovery paths without
changing the core proximity engine.

## 11. Capability, Permission, and Error Handling

Use explicit capability states instead of silent failure.

```text
CapabilityStatus
├── supported
├── unsupported
├── permissionDenied
├── temporarilyUnavailable
├── poweredOff
├── missingSecret
├── failedWithReason
└── unknown
```

### Blocking Failures

- BLE scanning unavailable blocks monitoring.
- Lock action unavailable blocks automatic lock.
- No selected devices blocks monitoring.

### Non-Blocking Failures

- Tray unavailable does not block monitoring, but the main window must show it.
- Wake-on-proximity failure does not block automatic lock.
- macOS automatic unlock failure does not block lock behavior.
- Windows automatic unlock unsupported is not an error.

### Recovery

Introduce a `CapabilityMonitor` that checks capabilities:

- on app start
- before monitoring starts
- after system wake
- after unlock/session change
- when the user clicks retry
- when a likely permission change is detected

Capability checks should be throttled to avoid repeated prompts or event loops.

## 12. Logging

Use structured logs with four categories.

```text
scan
decision
action
error
```

Each log entry should include:

```text
timestamp
level
category
message
platform
deviceId?
rssi?
reason?
```

Example log messages:

```text
[scan] device A seen: rssi=-58 name=Xiaomi Smart Band
[decision] device A away: smoothed RSSI -84 below lock threshold -80 for 5s
[action] lock requested: reason=allAway
[error] wakeDisplay unsupported on this Windows version
```

## 13. Testing Strategy

### Core Unit Tests

- RSSI smoothing.
- close state transition.
- away state transition.
- lost state transition.
- lock delay behavior.
- no-signal timeout behavior.
- `anyClose`.
- `allClose`.
- `allAway`.
- `anyAway`.
- unsupported unlock decision on Windows.

### Platform Contract Tests

- `BleScanner` event schema.
- `SessionController` capability result.
- `SecureStore` read/write/delete.
- `StartupManager` enable/disable.
- `FutureUnlockProvider` supported/unsupported behavior.

### Flutter Widget Tests

- First startup with no selected devices.
- Device selection.
- Monitoring disabled until a device is selected.
- Rule editing.
- Platform capability display.
- Logs display.
- Windows automatic unlock shown as unsupported.
- macOS automatic unlock prompt flow.

### Manual Acceptance Tests

- macOS real BLE scan.
- Windows real BLE scan.
- macOS automatic lock.
- Windows automatic lock.
- macOS wake-on-proximity.
- Windows wake-on-proximity best-effort behavior.
- macOS automatic unlock.
- Tray/menu actions on both platforms.
- Startup at login on both platforms.

## 14. Milestones for Future Implementation

This spec only requests documentation, not implementation. Future implementation
can be planned in these milestones:

```text
M0 Design spec
M1 Flutter skeleton and core contracts
M2 BLE scan spike on macOS and Windows
M3 MVP main flow
M4 macOS automatic unlock
M5 packaging and release validation
```

### M0 Design Spec

- Produce this design document.
- No implementation.
- No git commit required by current user instruction.

### M1 Flutter Skeleton and Core Contracts

- Create package structure.
- Add `bleunlock_core`.
- Add `bleunlock_platform_interface`.
- Define model classes and interfaces.
- Add core unit tests.

### M2 BLE Scan Spike

- Implement passive scan proof-of-concept on macOS.
- Implement passive scan proof-of-concept on Windows.
- Capture real device logs.
- Validate device identity stability.
- Validate RSSI update frequency.
- Validate whether Windows still receives scan events after lock.

### M3 MVP Main Flow

- Implement settings window.
- Implement device selection.
- Implement monitoring state.
- Implement automatic lock.
- Implement logs.
- Implement basic tray/menu actions.

### M4 macOS Automatic Unlock

- Implement Keychain storage.
- Implement permission checks.
- Implement locked-state checks.
- Implement simulated password input.
- Add retry and throttling behavior.

### M5 Packaging and Release Validation

- macOS app packaging.
- Windows app packaging.
- Startup at login verification.
- Upgrade behavior.
- Release notes.

## 15. Acceptance Criteria for First Implemented MVP

When implementation starts later, the first MVP should pass these criteria:

- macOS and Windows both display nearby BLE devices with RSSI.
- User can select at least one monitored device.
- Monitoring cannot start with zero selected devices.
- RSSI below lock threshold for `lockDelay` triggers lock.
- No broadcast for `noSignalTimeout` triggers lost.
- Multi-device any/all rules match configured behavior.
- macOS automatic unlock can be enabled and disabled.
- macOS automatic unlock failures are visible and throttled.
- Windows automatic unlock is clearly shown as unsupported.
- Permission failures are visible in UI.
- Logs explain scan, decision, action, and error events.
- Tray/menu can open settings, pause monitoring, lock now, and quit.
- First startup does not depend on old Swift app configuration.

## 16. Risks and Required Spikes

### Windows BLE Identity Stability

Windows may expose identifiers differently from macOS. The first implementation
milestone must verify whether selected devices can be recognized reliably across
app restarts and system lock/unlock.

### Windows BLE While Locked

The app must verify whether BLE advertisement events continue while the user
session is locked. This affects future wake/unlock behavior and current logs.

### Passive-Only RSSI Reliability

The first version intentionally avoids active BLE connections. Some devices may
broadcast less frequently or with less stable RSSI. The app should make this
visible through logs and allow threshold tuning.

### macOS Automatic Unlock Safety

Automatic unlock must confirm locked state, throttle repeated attempts, and avoid
rapid repeated password input.

### Tray/Menu Plugin Reliability

Flutter desktop tray support depends on plugin behavior. The first implementation
should validate tray behavior early on both macOS and Windows.

## 17. Explicit Non-Goals

- Do not preserve the existing Swift app's menu-heavy settings structure.
- Do not read existing Swift app preferences in the first version.
- Do not migrate existing Keychain records in the first version.
- Do not collect Windows login passwords in the first version.
- Do not implement Credential Provider in the first version.
- Do not introduce script or media automation in the first version.
- Do not add Linux support in the first version.

## 18. Design Approval State

The interactive design discussion approved these decisions:

- Use Flutter for a new macOS + Windows generation.
- Use a federated plugin architecture.
- Treat Flutter as the future replacement, not just an experiment.
- Keep macOS automatic unlock in scope.
- Keep Windows automatic unlock as future work.
- Do not migrate old data in the first version.
- Use a full settings window as the main UI.
- Use tray/menu bar only for status and quick actions.
- Use passive BLE scanning in the first version.
- Support multi-device any/all rules.
- Reserve script callbacks for future work.
- Reserve media pause/resume for future work.
- Produce a design document first, with no git commit.
