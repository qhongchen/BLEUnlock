import 'package:bleunlock_app/src/controllers/app_coordinator.dart';
import 'package:bleunlock_app/src/lock_sync/lock_sync_controller.dart';
import 'package:bleunlock_app/src/lock_sync/lock_sync_models.dart';
import 'package:bleunlock_app/src/platforms/mock_bleunlock_platform.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server syncs macOS session lock events even when manual sync is off',
      () async {
    final platform = MockBleunlockPlatform(platformLabel: 'macOS');
    final lockSyncController = RecordingLockSyncController();
    final coordinator = AppCoordinator(
      platform: platform,
      lockSyncController: lockSyncController,
    );
    final timestamp = DateTime(2026, 6, 9, 10);

    await coordinator.start();
    await coordinator.updateLockSyncConfig(
      const LockSyncConfig(
        role: LockSyncRole.server,
        sharedSecret: 'secret',
        syncManualLocks: false,
      ),
    );

    platform.mockSession.emitEvent(
      SessionEvent(
        kind: SessionEventKind.locked,
        timestamp: timestamp,
        reason: 'NSWorkspace.sessionDidResignActiveNotification',
      ),
    );
    await pumpEventQueue();

    expect(lockSyncController.broadcasts, hasLength(1));
    expect(lockSyncController.broadcasts.single.reason, 'externalLock');
    expect(lockSyncController.broadcasts.single.timestamp, timestamp);

    await coordinator.dispose();
  });
}

class RecordingLockSyncController extends LockSyncController {
  final List<RecordedLockBroadcast> broadcasts = [];
  LockSyncSnapshot _recordedSnapshot = const LockSyncSnapshot.initial();

  @override
  LockSyncSnapshot get snapshot => _recordedSnapshot;

  @override
  Future<void> updateConfig(LockSyncConfig config) async {
    _recordedSnapshot = LockSyncSnapshot(
      config: config,
      runtimeState: config.role == LockSyncRole.server
          ? LockSyncRuntimeState.listening
          : LockSyncRuntimeState.stopped,
    );
  }

  @override
  Future<void> broadcastLock({
    required String reason,
    required DateTime timestamp,
  }) async {
    broadcasts.add(RecordedLockBroadcast(reason, timestamp));
    _recordedSnapshot = _recordedSnapshot.copyWith(
      lastEventLabel: 'lockRequested:$reason',
    );
  }

  @override
  Future<void> dispose() async {}
}

class RecordedLockBroadcast {
  const RecordedLockBroadcast(this.reason, this.timestamp);

  final String reason;
  final DateTime timestamp;
}
