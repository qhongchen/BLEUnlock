import 'models.dart';
import 'rssi_smoother.dart';

class ProximityEngine {
  ProximityEngine({
    required this.config,
    required Set<String> selectedDeviceIds,
  }) : selectedDeviceIds = Set.unmodifiable(selectedDeviceIds);

  final ProximityConfig config;
  final Set<String> selectedDeviceIds;
  final Map<String, BleDevice> _devices = {};
  final Map<String, _TrackedDevice> _trackedDevices = {};

  PresenceDecision ingestScan(BleScanSample sample) {
    final isSelected = selectedDeviceIds.contains(sample.deviceId);
    final isVisible = sample.rssi >= config.minimumVisibleRssi;

    if (!isSelected && !isVisible) {
      return _buildDecision(
        reason: 'belowVisibleThreshold',
        timestamp: sample.seenAt,
      );
    }

    final previousDevice = _devices[sample.deviceId];
    _devices[sample.deviceId] = BleDevice(
      platformId: sample.deviceId,
      displayName: _normalizedText(sample.displayName) ??
          _normalizedText(previousDevice?.displayName),
      addressHint: _normalizedText(sample.addressHint) ??
          _normalizedText(previousDevice?.addressHint),
      lastRssi: sample.rssi,
      lastSeenAt: sample.seenAt,
      manufacturerData: _preferredManufacturerData(
          previousDevice?.manufacturerData, sample.manufacturerData),
      rawAdvertisement:
          sample.rawAdvertisement ?? previousDevice?.rawAdvertisement,
      isSelected: isSelected,
    );

    if (!isSelected) {
      return _buildDecision(reason: 'unmonitored', timestamp: sample.seenAt);
    }

    final tracked = _trackedDevices.putIfAbsent(
      sample.deviceId,
      () => _TrackedDevice(sample.deviceId, config.rssiWindowSize),
    );

    final smoothedRssi = tracked.smoother.add(sample.rssi);
    tracked.lastSeenAt = sample.seenAt;
    tracked.lastRssi = smoothedRssi;

    if (smoothedRssi >= config.unlockRssi) {
      _setState(
        tracked,
        DevicePresenceState.close,
        sample.seenAt,
        'rssiAboveUnlockThreshold',
      );
      tracked.awaySince = null;
    } else if (smoothedRssi < config.lockRssi) {
      tracked.awaySince ??= sample.seenAt;
      if (sample.seenAt.difference(tracked.awaySince!) >= config.lockDelay) {
        _setState(
          tracked,
          DevicePresenceState.away,
          sample.seenAt,
          'rssiBelowLockThresholdForDelay',
        );
      }
    } else {
      tracked.awaySince = null;
    }

    return _buildDecision(reason: 'scan', timestamp: sample.seenAt);
  }

  PresenceDecision tick(DateTime now) {
    for (final tracked in _trackedDevices.values) {
      final lastSeenAt = tracked.lastSeenAt;
      if (lastSeenAt == null) {
        continue;
      }

      if (now.difference(lastSeenAt) >= config.noSignalTimeout) {
        _setState(tracked, DevicePresenceState.lost, now, 'noSignalTimeout');
        tracked.awaySince = null;
        continue;
      }

      final awaySince = tracked.awaySince;
      if (awaySince != null && now.difference(awaySince) >= config.lockDelay) {
        _setState(
          tracked,
          DevicePresenceState.away,
          now,
          'rssiBelowLockThresholdForDelay',
        );
      }
    }

    return _buildDecision(reason: 'tick', timestamp: now);
  }

  void _setState(
    _TrackedDevice tracked,
    DevicePresenceState state,
    DateTime changedAt,
    String reason,
  ) {
    if (tracked.state != state) {
      tracked.lastStateChangedAt = changedAt;
    }
    tracked.state = state;
    tracked.reason = reason;
  }

  PresenceDecision _buildDecision({
    required String reason,
    required DateTime timestamp,
  }) {
    final deviceStates = <String, DevicePresence>{};
    for (final entry in _trackedDevices.entries) {
      final presence = entry.value.toPresence();
      if (presence != null) {
        deviceStates[entry.key] = presence;
      }
    }

    final aggregateClose = _aggregateClose(deviceStates);
    final aggregateAway = _aggregateAway(deviceStates);

    return PresenceDecision(
      shouldLock: aggregateAway,
      shouldWake: aggregateClose && config.wakeOnProximity,
      shouldUnlock: aggregateClose && config.enableMacAutoUnlock,
      reason: reason,
      devices: Map.unmodifiable(_devices),
      deviceStates: Map.unmodifiable(deviceStates),
      timestamp: timestamp,
    );
  }

  bool _aggregateClose(Map<String, DevicePresence> deviceStates) {
    if (selectedDeviceIds.isEmpty) {
      return false;
    }

    final closeIds = deviceStates.entries
        .where((entry) => entry.value.state == DevicePresenceState.close)
        .map((entry) => entry.key)
        .toSet();

    switch (config.unlockDeviceLogic) {
      case UnlockDeviceLogic.anyClose:
        return closeIds.isNotEmpty;
      case UnlockDeviceLogic.allClose:
        return selectedDeviceIds.every(closeIds.contains);
    }
  }

  bool _aggregateAway(Map<String, DevicePresence> deviceStates) {
    if (selectedDeviceIds.isEmpty) {
      return false;
    }

    bool isAway(String deviceId) {
      final state = deviceStates[deviceId]?.state;
      return state == DevicePresenceState.away ||
          state == DevicePresenceState.lost;
    }

    final trackedSelectedIds = selectedDeviceIds
        .where((deviceId) => deviceStates.containsKey(deviceId))
        .toSet();
    if (trackedSelectedIds.isEmpty) {
      return false;
    }

    switch (config.lockDeviceLogic) {
      case LockDeviceLogic.allAway:
        return trackedSelectedIds.every(isAway);
      case LockDeviceLogic.anyAway:
        return trackedSelectedIds.any(isAway);
    }
  }
}

String? _normalizedText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

List<int>? _preferredManufacturerData(List<int>? previous, List<int>? next) {
  if (next != null && next.isNotEmpty) {
    return next;
  }
  return previous;
}

class _TrackedDevice {
  _TrackedDevice(this.deviceId, int windowSize)
      : smoother = RssiSmoother(windowSize: windowSize);

  final String deviceId;
  final RssiSmoother smoother;
  int? lastRssi;
  DateTime? lastSeenAt;
  DateTime? awaySince;
  DateTime? lastStateChangedAt;
  DevicePresenceState? state;
  String reason = 'unknown';

  DevicePresence? toPresence() {
    final currentState = state;
    final currentRssi = lastRssi;
    final changedAt = lastStateChangedAt;
    if (currentState == null || currentRssi == null || changedAt == null) {
      return null;
    }

    return DevicePresence(
      deviceId: deviceId,
      smoothedRssi: currentRssi,
      state: currentState,
      lastStateChangedAt: changedAt,
      reason: reason,
    );
  }
}
