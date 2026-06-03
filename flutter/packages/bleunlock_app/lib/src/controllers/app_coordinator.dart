import 'dart:async';

import 'package:bleunlock_app/src/controllers/capability_monitor.dart';
import 'package:bleunlock_app/src/platforms/bleunlock_platform.dart';
import 'package:bleunlock_app/src/settings/app_settings_repository.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_core/bleunlock_core.dart';
import 'package:bleunlock_platform_interface/bleunlock_platform_interface.dart';

class AppCoordinator {
  static const String macosAutomaticUnlockPasswordKey =
      'macosAutomaticUnlockPassword';
  static const Duration _scanLogSampleInterval = Duration(seconds: 5);
  static const int _scanLogRssiChangeThreshold = 5;

  AppCoordinator({
    required this.platform,
    ProximityConfig config = const ProximityConfig(),
    Set<String> selectedDeviceIds = const {},
    Duration actionThrottleWindow = const Duration(seconds: 30),
    Duration capabilityRefreshThrottle = const Duration(seconds: 2),
    Duration deviceListRefreshInterval = const Duration(seconds: 5),
    Duration unlockRetryDelay = const Duration(milliseconds: 350),
    Duration wakeUnlockDelay = const Duration(milliseconds: 650),
    int unlockRetryLimit = 1,
    Duration tickInterval = const Duration(seconds: 1),
    AppSettingsRepository? settingsRepository,
  })  : _engine = ProximityEngine(
          config: config,
          selectedDeviceIds: selectedDeviceIds,
        ),
        _config = config,
        _selectedDeviceIds = {...selectedDeviceIds},
        _settingsRepository = settingsRepository ??
            SecureStoreAppSettingsRepository(platform.secureStore),
        _capabilityMonitor = CapabilityMonitor(
          platform,
          throttleWindow: capabilityRefreshThrottle,
        ),
        _deviceListRefreshInterval = deviceListRefreshInterval,
        _actionThrottleWindow = actionThrottleWindow,
        _unlockRetryDelay = unlockRetryDelay,
        _wakeUnlockDelay = wakeUnlockDelay,
        _unlockRetryLimit = unlockRetryLimit,
        _tickInterval = tickInterval,
        _value = DashboardState.initial(config: config);

  final BleunlockPlatform platform;
  final CapabilityMonitor _capabilityMonitor;
  final Duration _deviceListRefreshInterval;
  final Duration _actionThrottleWindow;
  final Duration _unlockRetryDelay;
  final Duration _wakeUnlockDelay;
  final Duration _tickInterval;
  final int _unlockRetryLimit;
  final AppSettingsRepository _settingsRepository;
  ProximityEngine _engine;
  ProximityConfig _config;
  final Set<String> _selectedDeviceIds;
  final Map<String, BleScanEvent> _visibleDevices = {};
  final Map<String, BleScanEvent> _publishedVisibleDevices = {};
  final Map<_ActionKind, DateTime> _lastActionAt = {};
  final Map<String, String> _lastLoggedPresenceSignatures = {};
  final Map<String, _LoggedScanSample> _lastLoggedScanSamples = {};
  final StreamController<DashboardState> _states =
      StreamController<DashboardState>.broadcast();
  final StreamController<AppCommand> _commands =
      StreamController<AppCommand>.broadcast();
  final List<DashboardLogEntry> _logs = [];

  StreamSubscription<BleScanEvent>? _scanSubscription;
  StreamSubscription<TrayAction>? _traySubscription;
  StreamSubscription<SessionEvent>? _sessionSubscription;
  Timer? _unlockRetryTimer;
  Timer? _wakeUnlockTimer;
  Timer? _tickTimer;
  Timer? _deviceListRefreshTimer;
  DashboardState _value;
  PresenceDecision? _lastDecision;
  PresenceDecision? _visibleDeviceListDecision;
  bool _isMonitoring = false;
  bool _isScanning = false;
  bool _isStartupEnabled = false;
  DashboardSessionState _sessionState = DashboardSessionState.unlocked;
  bool _isAutoUnlockSecretConfigured = false;
  String _lastActionLabel = 'None';
  DateTime? _latestScanAt;
  bool _hasLoggedAlreadyLockedSkip = false;
  bool _isPollingSessionState = false;
  bool _isDisposed = false;
  String? _lastLoggedDecisionSignature;
  String? _autoUnlockSuppressionReason;
  bool _hasLoggedAutoUnlockSuppression = false;

  DashboardState get value => _value;

  Stream<DashboardState> get states => _states.stream;

  Stream<AppCommand> get commands => _commands.stream;

  ProximityConfig get config => _config;

  String get diagnosticLogJsonLines {
    return _logs.map((entry) => entry.diagnosticJsonLine).join('\n');
  }

  Future<void> initialize() async {
    await loadSettings();
    await refreshSystemSettings();
  }

  Future<void> loadSettings() async {
    final settings = await _settingsRepository.load();
    if (settings == null) {
      _publish(_lastDecision);
      return;
    }

    _config = settings.config;
    _selectedDeviceIds
      ..clear()
      ..addAll(settings.selectedDeviceIds);
    _rebuildEngine();
    _lastActionLabel = 'Settings loaded';
    _appendLog(
      timestamp: DateTime.now(),
      category: DashboardLogCategory.action,
      message: _lastActionLabel,
      reason: 'settingsLoaded',
    );
    _publish(_lastDecision);
  }

  Future<void> start() async {
    await startMonitoring();
  }

  Future<void> startScanning({bool refreshCapability = true}) async {
    if (refreshCapability) {
      try {
        await _capabilityMonitor.refreshScanner(
          reason: CapabilityRefreshReason.userAction,
        );
      } catch (error) {
        _appendPlatformFailureLog(
          timestamp: DateTime.now(),
          label: 'Bluetooth capability refresh failed',
          reason: 'scannerCapabilityRefreshFailed',
          error: error,
        );
        _publish();
        return;
      }
    }
    final capabilities = _capabilityMonitor.check();
    if (!capabilities.canScan) {
      _lastActionLabel = 'Bluetooth scanning unavailable';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _capabilityFailureMessage(
          _lastActionLabel,
          platform.scanner.capability,
        ),
        reason: 'scannerUnavailable',
      );
      _publish();
      return;
    }

    if (_scanSubscription == null) {
      _scanSubscription = platform.scanner.events.listen(
        _handleScan,
        onError: (Object error) {
          _appendPlatformFailureLog(
            timestamp: DateTime.now(),
            label: 'Bluetooth scan event failed',
            reason: 'scannerEventFailed',
            error: error,
          );
          _publish();
        },
      );
    }
    try {
      await platform.scanner.startScan();
    } catch (error) {
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Bluetooth scan start failed',
        reason: 'scannerStartFailed',
        error: error,
      );
      _publish();
      return;
    }
    _isScanning = true;
    _publish();
  }

  Future<void> startMonitoring({String reason = 'userAction'}) async {
    if (_isMonitoring) {
      return;
    }

    try {
      await _capabilityMonitor.refreshScanner(
        reason: CapabilityRefreshReason.monitoring,
      );
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Bluetooth capability refresh failed',
        reason: 'scannerCapabilityRefreshFailed',
        error: error,
      );
      _publish();
      return;
    }
    final capabilities = _capabilityMonitor.check();
    if (!capabilities.canScan) {
      _lastActionLabel = 'Bluetooth scanning unavailable';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _capabilityFailureMessage(
          _lastActionLabel,
          platform.scanner.capability,
        ),
        reason: 'scannerUnavailable',
      );
      _publish();
      return;
    }

    if (!capabilities.canLock) {
      _lastActionLabel = 'Auto lock unavailable';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _capabilityFailureMessage(
          _lastActionLabel,
          platform.session.capability,
        ),
        reason: 'lockUnavailable',
      );
      _publish();
      return;
    }

    if (_selectedDeviceIds.isEmpty) {
      _lastActionLabel = 'Select a device first';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _lastActionLabel,
        reason: 'noSelectedDevice',
      );
      _publish();
      return;
    }

    _ensureSessionSubscription();
    _isMonitoring = true;
    _startTickTimer();
    await startScanning(refreshCapability: false);
    if (!_isScanning) {
      _isMonitoring = false;
      _stopTickTimer();
      _publish();
      return;
    }
    _lastActionLabel = 'Monitoring started';
    _appendLog(
      timestamp: DateTime.now(),
      category: DashboardLogCategory.action,
      message: _lastActionLabel,
      reason: reason,
    );
    _publish();
  }

  Future<void> pause({String reason = 'userAction'}) async {
    _isMonitoring = false;
    _cancelUnlockRetry(reason: 'monitoringPausedForRetry');
    _cancelWakeUnlockTimer();
    _stopTickTimer();
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    try {
      await platform.scanner.stopScan();
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Bluetooth scan stop failed',
        reason: 'scannerStopFailed',
        error: error,
      );
    }
    _isScanning = false;
    _lastActionLabel = 'Monitoring paused';
    _appendLog(
      timestamp: DateTime.now(),
      category: DashboardLogCategory.action,
      message: _lastActionLabel,
      reason: reason,
    );
    _publish();
  }

  void setDeviceSelected(String deviceId, bool isSelected) {
    final wasMonitoring = _isMonitoring;
    if (isSelected) {
      _selectedDeviceIds.add(deviceId);
    } else {
      _selectedDeviceIds.remove(deviceId);
    }

    final shouldPauseForEmptySelection =
        wasMonitoring && _selectedDeviceIds.isEmpty;
    _rebuildEngine();
    _lastActionLabel = isSelected ? 'Device selected' : 'Device unselected';
    _appendLog(
      timestamp: DateTime.now(),
      category: DashboardLogCategory.action,
      message: _lastActionLabel,
      deviceId: deviceId,
      reason: 'deviceSelectionChanged',
    );
    _saveSettings();
    if (shouldPauseForEmptySelection) {
      unawaited(pause(reason: 'deviceSelectionChanged'));
      return;
    }
    _publish(_lastDecision);
  }

  void refreshDeviceList() {
    _cancelDeviceListRefreshTimer();
    _publishDeviceList(_latestScanAt ?? DateTime.now());
  }

  void updateConfig(
    ProximityConfig config, {
    bool acknowledgeMacAutoUnlockRisk = false,
  }) {
    final isEnablingMacAutoUnlock =
        !_config.enableMacAutoUnlock && config.enableMacAutoUnlock;
    if (isEnablingMacAutoUnlock && !_isAutoUnlockSecretEditable) {
      _lastActionLabel = 'Auto unlock unavailable';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.action,
        message: _capabilityFailureMessage(
          _lastActionLabel,
          platform.unlock.capability,
        ),
        reason: 'macAutoUnlockUnavailable',
      );
      _publish(_lastDecision);
      return;
    }

    if (isEnablingMacAutoUnlock && !acknowledgeMacAutoUnlockRisk) {
      _lastActionLabel = 'Auto unlock confirmation required';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _lastActionLabel,
        reason: 'macAutoUnlockConfirmationRequired',
      );
      _publish(_lastDecision);
      return;
    }

    _config = config;
    if (!config.enableMacAutoUnlock) {
      _cancelUnlockRetry(reason: 'autoUnlockDisabledForRetry');
      _cancelWakeUnlockTimer();
    }
    _rebuildEngine();
    _lastActionLabel = 'Rules updated';
    _appendLog(
      timestamp: DateTime.now(),
      category: DashboardLogCategory.action,
      message: _lastActionLabel,
      reason: 'configChanged',
    );
    _saveSettings();
    _publish(_lastDecision);
  }

  Future<void> refreshSystemSettings() async {
    await _refreshCapabilitiesForSystem(
      reason: CapabilityRefreshReason.appStart,
    );
    _publish(_lastDecision);
  }

  Future<void> retryCapabilityCheck() async {
    final refreshed = await _refreshCapabilitiesForSystem(
      reason: CapabilityRefreshReason.userAction,
      force: true,
    );

    _lastActionLabel =
        refreshed ? 'Capabilities refreshed' : 'Capability refresh failed';
    _appendLog(
      timestamp: DateTime.now(),
      category:
          refreshed ? DashboardLogCategory.action : DashboardLogCategory.error,
      message: _lastActionLabel,
      reason: refreshed ? 'capabilityRetry' : 'capabilityRefreshFailed',
    );
    _publish(_lastDecision);
  }

  Future<bool> _refreshCapabilitiesForSystem({
    required CapabilityRefreshReason reason,
    bool force = false,
  }) async {
    _ensureTraySubscription();
    _ensureSessionSubscription();
    var success = true;
    try {
      await _capabilityMonitor.refreshSystemCapabilities(
        reason: reason,
        force: force,
      );
    } catch (error) {
      success = false;
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Capability refresh failed',
        reason: 'capabilityRefreshFailed',
        error: error,
      );
    }
    if (platform.startup.capability.isUsable) {
      try {
        _isStartupEnabled = await platform.startup.isEnabled();
      } catch (error) {
        _appendPlatformFailureLog(
          timestamp: DateTime.now(),
          label: 'Startup status unavailable',
          reason: 'startupStatusFailed',
          error: error,
        );
      }
    }
    await _refreshAutoUnlockSecretStatus();
    return success;
  }

  Future<void> setStartupEnabled(bool enabled) async {
    if (!platform.startup.capability.isUsable) {
      _lastActionLabel = 'Startup unavailable';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _lastActionLabel,
        reason: 'startupUnavailable',
      );
      _publish(_lastDecision);
      return;
    }

    try {
      await platform.startup.setEnabled(enabled);
      _isStartupEnabled = enabled;
      _lastActionLabel = enabled ? 'Startup enabled' : 'Startup disabled';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.action,
        message: _lastActionLabel,
        reason: 'startupChanged',
      );
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Startup update failed',
        reason: 'startupUpdateFailed',
        error: error,
      );
    }
    _publish(_lastDecision);
  }

  Future<void> openMacAutoUnlockPermissionSettings() async {
    if (!_isAutoUnlockPermissionSettingsAvailable) {
      _lastActionLabel = 'Accessibility settings unavailable';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.action,
        message: _lastActionLabel,
        reason: 'autoUnlockPermissionSettingsUnavailable',
      );
      _publish(_lastDecision);
      return;
    }

    try {
      await platform.unlock.openPermissionSettings();
      _lastActionLabel = 'Accessibility settings opened';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.action,
        message: _lastActionLabel,
        reason: 'autoUnlockPermissionSettingsOpened',
      );
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Accessibility settings open failed',
        reason: 'autoUnlockPermissionSettingsOpenFailed',
        error: error,
      );
    }
    _publish(_lastDecision);
  }

  Future<void> setMacAutoUnlockPassword(String password) async {
    if (password.isEmpty) {
      await clearMacAutoUnlockPassword();
      return;
    }

    if (!platform.secureStore.capability.isUsable) {
      _lastActionLabel = 'Secure store unavailable';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _lastActionLabel,
        reason: 'secureStoreUnavailable',
      );
      _publish(_lastDecision);
      return;
    }

    try {
      await platform.secureStore.writeSecret(
        macosAutomaticUnlockPasswordKey,
        password,
      );
      try {
        await _capabilityMonitor.refreshUnlock(
          reason: CapabilityRefreshReason.userAction,
          force: true,
        );
      } catch (error) {
        _appendPlatformFailureLog(
          timestamp: DateTime.now(),
          label: 'Unlock capability refresh failed',
          reason: 'unlockCapabilityRefreshFailed',
          error: error,
        );
      }
      _isAutoUnlockSecretConfigured = true;
      _lastActionLabel = 'Auto unlock password saved';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.action,
        message: _lastActionLabel,
        reason: 'autoUnlockPasswordSaved',
      );
    } catch (_) {
      _lastActionLabel = 'Auto unlock password save failed';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _lastActionLabel,
        reason: 'autoUnlockPasswordSaveFailed',
      );
    }
    _publish(_lastDecision);
  }

  Future<void> clearMacAutoUnlockPassword() async {
    if (!platform.secureStore.capability.isUsable) {
      _lastActionLabel = 'Secure store unavailable';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _lastActionLabel,
        reason: 'secureStoreUnavailable',
      );
      _publish(_lastDecision);
      return;
    }

    try {
      await platform.secureStore.deleteSecret(macosAutomaticUnlockPasswordKey);
      try {
        await _capabilityMonitor.refreshUnlock(
          reason: CapabilityRefreshReason.userAction,
          force: true,
        );
      } catch (error) {
        _appendPlatformFailureLog(
          timestamp: DateTime.now(),
          label: 'Unlock capability refresh failed',
          reason: 'unlockCapabilityRefreshFailed',
          error: error,
        );
      }
      _isAutoUnlockSecretConfigured = false;
      _lastActionLabel = 'Auto unlock password cleared';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.action,
        message: _lastActionLabel,
        reason: 'autoUnlockPasswordCleared',
      );
    } catch (_) {
      _lastActionLabel = 'Auto unlock password clear failed';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _lastActionLabel,
        reason: 'autoUnlockPasswordClearFailed',
      );
    }
    _publish(_lastDecision);
  }

  void tick(DateTime now) {
    unawaited(_syncSessionStateFromPlatform(now));
    final decision = _engine.tick(now);
    _applyDecision(decision);
  }

  Future<void> lockNow({String reason = 'userAction'}) async {
    _ensureSessionSubscription();
    if (!platform.session.capability.isUsable) {
      _lastActionLabel = 'Lock unavailable';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: _capabilityFailureMessage(
          _lastActionLabel,
          platform.session.capability,
        ),
        reason: 'lockUnavailable',
      );
      _publish();
      return;
    }

    try {
      await platform.session.lock();
      _sessionState = DashboardSessionState.locked;
      _suspendAutoUnlockUntilDeviceLeaves('manualLock');
      _lastActionLabel = 'Locked screen';
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.action,
        message: _lastActionLabel,
        reason: reason,
      );
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Lock failed',
        reason: 'lockFailed',
        error: error,
      );
    }
    _publish();
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _cancelUnlockRetry();
    _cancelWakeUnlockTimer();
    _stopTickTimer();
    _cancelDeviceListRefreshTimer();
    _isMonitoring = false;
    _isScanning = false;
    final scanSubscription = _scanSubscription;
    _scanSubscription = null;
    if (scanSubscription != null) {
      unawaited(scanSubscription.cancel());
    }
    try {
      await platform.scanner.stopScan();
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Bluetooth scan stop failed',
        reason: 'scannerStopFailed',
        error: error,
      );
    }
    final traySubscription = _traySubscription;
    _traySubscription = null;
    if (traySubscription != null) {
      unawaited(traySubscription.cancel());
    }
    final sessionSubscription = _sessionSubscription;
    _sessionSubscription = null;
    if (sessionSubscription != null) {
      unawaited(sessionSubscription.cancel());
    }
    unawaited(_states.close());
    unawaited(_commands.close());
  }

  void _handleScan(BleScanEvent event) {
    if (_latestScanAt == null || event.seenAt.isAfter(_latestScanAt!)) {
      _latestScanAt = event.seenAt;
    }
    final isNewDevice = !_visibleDevices.containsKey(event.deviceId);
    final mergedEvent = _mergeScanEvent(_visibleDevices[event.deviceId], event);
    _visibleDevices[event.deviceId] = mergedEvent;
    if (!_isMonitoring) {
      _appendScanLogIfUseful(mergedEvent);
      if (isNewDevice) {
        _publishDeviceList(mergedEvent.seenAt);
      } else {
        _scheduleDeviceListRefresh();
        _publish(_visibleDeviceListDecision);
      }
      return;
    }

    final decision = _engine.ingestScan(
      BleScanSample(
        deviceId: event.deviceId,
        rssi: event.rssi,
        seenAt: event.seenAt,
        displayName: _normalizedText(mergedEvent.displayName),
        addressHint: _normalizedText(mergedEvent.addressHint),
        manufacturerData: mergedEvent.manufacturerData,
        rawAdvertisement: mergedEvent.rawAdvertisement,
      ),
    );
    _appendScanLogIfUseful(mergedEvent);
    _applyDecision(decision, refreshDeviceListNow: isNewDevice);
  }

  BleScanEvent _mergeScanEvent(BleScanEvent? previous, BleScanEvent next) {
    if (previous == null) {
      return next;
    }

    return BleScanEvent(
      deviceId: next.deviceId,
      displayName: _normalizedText(next.displayName) ??
          _normalizedText(previous.displayName),
      addressHint: _preferredAddressHint(
          previous.addressHint, next.addressHint, next.deviceId),
      rssi: next.rssi,
      seenAt: next.seenAt,
      manufacturerData: _preferredManufacturerData(
        previous.manufacturerData,
        next.manufacturerData,
      ),
      rawAdvertisement: next.rawAdvertisement ?? previous.rawAdvertisement,
    );
  }

  String? _preferredAddressHint(
      String? previous, String? next, String deviceId) {
    final normalizedNext = _normalizedText(next);
    final normalizedPrevious = _normalizedText(previous);
    if (normalizedNext != null && normalizedNext != deviceId) {
      return normalizedNext;
    }
    return normalizedPrevious ?? normalizedNext;
  }

  List<int>? _preferredManufacturerData(List<int>? previous, List<int>? next) {
    if (next != null && next.isNotEmpty) {
      return next;
    }
    return previous;
  }

  void _publishDeviceList(DateTime timestamp) {
    _refreshPublishedDeviceList(timestamp);
    _publish(_lastDecision ?? _visibleDeviceListDecision);
  }

  void _refreshPublishedDeviceList(DateTime timestamp) {
    _pruneExpiredVisibleDevices(timestamp);
    _publishedVisibleDevices
      ..clear()
      ..addAll(_visibleDevices);
    final decision =
        _buildDiscoveryDecision(timestamp, _publishedVisibleDevices);
    _visibleDeviceListDecision = decision;
  }

  void _scheduleDeviceListRefresh() {
    if (_deviceListRefreshTimer != null || _isDisposed) {
      return;
    }
    _deviceListRefreshTimer = Timer(_deviceListRefreshInterval, () {
      _deviceListRefreshTimer = null;
      if (_isDisposed || _visibleDevices.isEmpty) {
        return;
      }
      _refreshPublishedDeviceList(_latestScanAt ?? DateTime.now());
      _publish(_lastDecision ?? _visibleDeviceListDecision);
    });
  }

  void _cancelDeviceListRefreshTimer() {
    _deviceListRefreshTimer?.cancel();
    _deviceListRefreshTimer = null;
  }

  void _pruneExpiredVisibleDevices(DateTime timestamp) {
    final staleDeviceIds = <String>[];
    for (final entry in _visibleDevices.entries) {
      if (_selectedDeviceIds.contains(entry.key)) {
        continue;
      }
      if (timestamp.difference(entry.value.seenAt) >= config.noSignalTimeout) {
        staleDeviceIds.add(entry.key);
      }
    }
    for (final deviceId in staleDeviceIds) {
      _visibleDevices.remove(deviceId);
      _publishedVisibleDevices.remove(deviceId);
      _lastLoggedScanSamples.remove(deviceId);
    }
  }

  PresenceDecision _buildDiscoveryDecision(
    DateTime timestamp,
    Map<String, BleScanEvent> source,
  ) {
    final devices = <String, BleDevice>{};
    for (final entry in source.entries) {
      final event = entry.value;
      devices[entry.key] = BleDevice(
        platformId: event.deviceId,
        displayName: _normalizedText(event.displayName),
        addressHint: _normalizedText(event.addressHint),
        lastRssi: event.rssi,
        lastSeenAt: event.seenAt,
        manufacturerData: event.manufacturerData,
        rawAdvertisement: event.rawAdvertisement,
        isSelected: _selectedDeviceIds.contains(event.deviceId),
      );
    }

    return PresenceDecision(
      shouldLock: false,
      shouldWake: false,
      shouldUnlock: false,
      reason: 'discovery',
      devices: Map.unmodifiable(devices),
      deviceStates: const {},
      timestamp: timestamp,
    );
  }

  void _rebuildEngine() {
    _engine = ProximityEngine(
      config: config,
      selectedDeviceIds: _selectedDeviceIds,
    );
    _lastLoggedPresenceSignatures.clear();
    _lastLoggedDecisionSignature = null;
    _visibleDeviceListDecision = _publishedVisibleDevices.isEmpty
        ? null
        : _buildDiscoveryDecision(DateTime.now(), _publishedVisibleDevices);
    _lastDecision = _visibleDevices.isEmpty
        ? null
        : _buildDiscoveryDecision(DateTime.now(), _visibleDevices);
  }

  void _saveSettings() {
    unawaited(
      _settingsRepository.save(
        AppSettings(
          config: config,
          selectedDeviceIds: Set.unmodifiable(_selectedDeviceIds),
        ),
      ),
    );
  }

  Future<void> _refreshAutoUnlockSecretStatus() async {
    if (!platform.secureStore.capability.isUsable) {
      _isAutoUnlockSecretConfigured = false;
      return;
    }

    try {
      final secret = await platform.secureStore.readSecret(
        macosAutomaticUnlockPasswordKey,
      );
      _isAutoUnlockSecretConfigured = secret != null && secret.isNotEmpty;
    } catch (_) {
      _isAutoUnlockSecretConfigured = false;
      _appendLog(
        timestamp: DateTime.now(),
        category: DashboardLogCategory.error,
        message: 'Auto unlock password status unavailable',
        reason: 'autoUnlockPasswordStatusFailed',
      );
    }
  }

  void _cancelUnlockRetry({String? reason}) {
    final retryTimer = _unlockRetryTimer;
    if (retryTimer == null) {
      return;
    }
    retryTimer.cancel();
    _unlockRetryTimer = null;
    if (reason == null || _isDisposed) {
      return;
    }
    _appendUnlockRetrySkipped(reason);
  }

  void _cancelWakeUnlockTimer() {
    _wakeUnlockTimer?.cancel();
    _wakeUnlockTimer = null;
  }

  bool get _isWaitingForWakeLoginUi {
    switch (_sessionState) {
      case DashboardSessionState.displaySleep:
      case DashboardSessionState.systemSleep:
        return true;
      case DashboardSessionState.unlocked:
      case DashboardSessionState.locked:
      case DashboardSessionState.displayWake:
      case DashboardSessionState.systemWake:
        return false;
    }
  }

  void _appendUnlockRetrySkipped(String reason) {
    if (_isDisposed) {
      return;
    }
    _appendLog(
      timestamp: DateTime.now(),
      category: DashboardLogCategory.action,
      message: 'Unlock retry skipped',
      reason: reason,
    );
    _publish();
  }

  void _startTickTimer() {
    _tickTimer ??= Timer.periodic(_tickInterval, (_) {
      if (!_isMonitoring || _isDisposed) {
        return;
      }
      tick(DateTime.now());
    });
  }

  void _stopTickTimer() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  void _ensureTraySubscription() {
    if (_traySubscription != null || !platform.tray.capability.isUsable) {
      return;
    }

    _traySubscription = platform.tray.onAction.listen(
      _handleTrayAction,
      onError: (Object error) {
        _appendPlatformFailureLog(
          timestamp: DateTime.now(),
          label: 'Tray action stream failed',
          reason: 'trayActionStreamFailed',
          error: error,
        );
        _publish();
      },
    );
  }

  void _ensureSessionSubscription() {
    if (_sessionSubscription != null || !platform.session.capability.isUsable) {
      return;
    }

    _sessionSubscription = platform.session.events.listen(
      (event) {
        unawaited(_handleSessionEvent(event));
      },
      onError: (Object error) {
        _appendPlatformFailureLog(
          timestamp: DateTime.now(),
          label: 'Session event stream failed',
          reason: 'sessionEventStreamFailed',
          error: error,
        );
        _publish();
      },
    );
  }

  void _handleTrayAction(TrayAction action) {
    switch (action.kind) {
      case TrayActionKind.openSettings:
        _emitCommand(AppCommandKind.openSettings, action.timestamp);
        _lastActionLabel = 'Open settings requested';
        _appendLog(
          timestamp: action.timestamp,
          category: DashboardLogCategory.action,
          message: _lastActionLabel,
          reason: 'trayAction',
        );
        _publish(_lastDecision);
        break;
      case TrayActionKind.startMonitoring:
        unawaited(startMonitoring(reason: 'trayAction'));
        break;
      case TrayActionKind.pauseMonitoring:
        unawaited(pause(reason: 'trayAction'));
        break;
      case TrayActionKind.lockNow:
        unawaited(lockNow(reason: 'trayAction'));
        break;
      case TrayActionKind.quit:
        _emitCommand(AppCommandKind.quit, action.timestamp);
        _lastActionLabel = 'Quit requested';
        _appendLog(
          timestamp: action.timestamp,
          category: DashboardLogCategory.action,
          message: _lastActionLabel,
          reason: 'trayAction',
        );
        _publish(_lastDecision);
        break;
    }
  }

  void _emitCommand(AppCommandKind kind, DateTime timestamp) {
    if (_commands.isClosed) {
      return;
    }
    _commands.add(AppCommand(kind: kind, timestamp: timestamp));
  }

  Future<void> _handleSessionEvent(SessionEvent event) async {
    final label = _sessionEventLabel(event.kind);
    final reason = _sessionEventReason(event.kind);
    _lastActionLabel = label;

    switch (event.kind) {
      case SessionEventKind.locked:
        _sessionState = DashboardSessionState.locked;
        _hasLoggedAlreadyLockedSkip = false;
        _suspendAutoUnlockUntilDeviceLeaves('manualLock');
      case SessionEventKind.displaySleep:
        _sessionState = DashboardSessionState.displaySleep;
        _hasLoggedAlreadyLockedSkip = false;
      case SessionEventKind.systemSleep:
        _sessionState = DashboardSessionState.systemSleep;
        _hasLoggedAlreadyLockedSkip = false;
      case SessionEventKind.unlocked:
        _sessionState = DashboardSessionState.unlocked;
        _hasLoggedAlreadyLockedSkip = false;
        _clearAutoUnlockSuppression();
        _cancelWakeUnlockTimer();
        _cancelUnlockRetry(reason: 'sessionNotLockedForRetry');
      case SessionEventKind.displayWake:
        _sessionState = DashboardSessionState.displayWake;
      case SessionEventKind.systemWake:
        _sessionState = DashboardSessionState.systemWake;
    }

    if (platform.startup.capability.isUsable) {
      try {
        _isStartupEnabled = await platform.startup.isEnabled();
      } catch (error) {
        _appendPlatformFailureLog(
          timestamp: event.timestamp,
          label: 'Startup status unavailable',
          reason: 'startupStatusFailed',
          error: error,
        );
      }
    }
    try {
      await _capabilityMonitor.refreshSystemCapabilities(
        reason: CapabilityRefreshReason.sessionEvent,
      );
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: event.timestamp,
        label: 'Capability refresh failed',
        reason: 'capabilityRefreshFailed',
        error: error,
      );
    }
    await _refreshAutoUnlockSecretStatus();

    _appendLog(
      timestamp: event.timestamp,
      category: DashboardLogCategory.action,
      message: label,
      reason: reason,
    );
    _publish(_lastDecision);
  }

  void _applyDecision(
    PresenceDecision decision, {
    bool refreshDeviceListNow = false,
  }) {
    _lastDecision = decision;
    _clearAutoUnlockSuppressionIfDeviceLeft(decision);
    if (_shouldLogDecision(decision)) {
      _appendLog(
        timestamp: decision.timestamp,
        category: DashboardLogCategory.decision,
        message: 'Decision ${decision.reason}',
        reason: decision.reason,
      );
    }
    _appendDeviceStateLogs(decision);

    if (decision.shouldLock) {
      unawaited(_lockFromDecision(decision.timestamp));
    }

    if (decision.shouldWake || decision.shouldUnlock) {
      unawaited(_wakeOrUnlockFromDecision(decision));
    }

    if (refreshDeviceListNow || _visibleDeviceListDecision == null) {
      _refreshPublishedDeviceList(decision.timestamp);
    }
    _scheduleDeviceListRefresh();
    _publish(decision);
  }

  bool _shouldLogDecision(PresenceDecision decision) {
    if (decision.reason == 'tick') {
      return false;
    }

    final signature = [
      decision.reason,
      decision.shouldLock,
      decision.shouldWake,
      decision.shouldUnlock,
    ].join('|');
    if (_lastLoggedDecisionSignature == signature) {
      return false;
    }

    _lastLoggedDecisionSignature = signature;
    return true;
  }

  Future<void> _wakeOrUnlockFromDecision(PresenceDecision decision) async {
    final waitForWakeLoginUi = _isWaitingForWakeLoginUi;
    if (!platform.session.capability.isUsable) {
      if (decision.shouldWake) {
        await _wakeFromDecision(decision.timestamp);
      }
      if (decision.shouldUnlock) {
        await _unlockFromDecision(decision.timestamp);
      }
      return;
    }

    bool isLocked;
    try {
      isLocked = await platform.session.isLocked();
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: decision.timestamp,
        label: 'Session lock state unavailable',
        reason: 'lockStateCheckFailed',
        error: error,
      );
      _publish();
      return;
    }

    _sessionState = isLocked
        ? DashboardSessionState.locked
        : DashboardSessionState.unlocked;
    if (!isLocked) {
      _cancelWakeUnlockTimer();
      _cancelUnlockRetry(reason: 'sessionNotLockedForRetry');
      return;
    }

    if (_isAutoUnlockSuppressed) {
      _appendAutoUnlockSuppressedLog(decision.timestamp);
      _publish();
      return;
    }

    if (decision.shouldWake) {
      await _wakeFromDecision(decision.timestamp);
    }

    if (!decision.shouldUnlock) {
      return;
    }

    if (decision.shouldWake && waitForWakeLoginUi) {
      _scheduleWakeUnlock(decision.timestamp);
    } else {
      await _unlockFromDecision(decision.timestamp);
    }
  }

  void _scheduleWakeUnlock(DateTime timestamp) {
    if (_wakeUnlockTimer != null) {
      return;
    }

    _appendLog(
      timestamp: timestamp,
      category: DashboardLogCategory.action,
      message: 'Unlock delayed for wake',
      reason: 'wakeUnlockDelay',
      sessionState: _sessionState,
    );
    _publish();

    _wakeUnlockTimer = Timer(_wakeUnlockDelay, () {
      _wakeUnlockTimer = null;
      if (_isDisposed || !_isMonitoring) {
        return;
      }
      unawaited(_unlockFromDecision(DateTime.now()));
    });
  }

  void _appendDeviceStateLogs(PresenceDecision decision) {
    for (final presence in decision.deviceStates.values) {
      final signature = '${presence.state}|${presence.reason}';
      if (_lastLoggedPresenceSignatures[presence.deviceId] == signature) {
        continue;
      }

      _lastLoggedPresenceSignatures[presence.deviceId] = signature;
      _appendLog(
        timestamp: decision.timestamp,
        category: DashboardLogCategory.decision,
        message:
            'Device ${presence.deviceId} ${_presenceStateLabel(presence.state)}',
        deviceId: presence.deviceId,
        rssi: presence.smoothedRssi,
        reason: presence.reason,
      );
    }
  }

  Future<void> _lockFromDecision(DateTime timestamp) async {
    if (await _isCurrentlyLocked(timestamp)) {
      if (!_hasLoggedAlreadyLockedSkip) {
        _hasLoggedAlreadyLockedSkip = true;
        _appendLog(
          timestamp: timestamp,
          category: DashboardLogCategory.action,
          message: 'Lock skipped',
          reason: 'sessionAlreadyLocked',
          sessionState: _sessionState,
        );
        _publish();
      }
      return;
    }

    if (_isActionThrottled(_ActionKind.lock, timestamp)) {
      _appendThrottledActionLog(timestamp, 'Lock throttled');
      _publish();
      return;
    }
    _markAction(_ActionKind.lock, timestamp);

    if (!platform.session.capability.isUsable) {
      _lastActionLabel = 'Lock unsupported';
      _appendLog(
        timestamp: timestamp,
        category: DashboardLogCategory.error,
        message: _capabilityFailureMessage(
          _lastActionLabel,
          platform.session.capability,
        ),
        reason: 'unsupported',
      );
      _publish();
      return;
    }

    try {
      await platform.session.lock();
      _sessionState = DashboardSessionState.locked;
      _hasLoggedAlreadyLockedSkip = false;
      _lastActionLabel = 'Locked screen';
      _appendLog(
        timestamp: timestamp,
        category: DashboardLogCategory.action,
        message: _lastActionLabel,
        reason: 'proximityDecision',
      );
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: timestamp,
        label: 'Lock failed',
        reason: 'lockFailed',
        error: error,
      );
    }
    _publish();
  }

  Future<bool> _isCurrentlyLocked(DateTime timestamp) async {
    if (!platform.session.capability.isUsable) {
      return _isSessionLocked;
    }

    try {
      final isLocked = await platform.session.isLocked();
      _sessionState = isLocked
          ? DashboardSessionState.locked
          : DashboardSessionState.unlocked;
      if (!isLocked) {
        _hasLoggedAlreadyLockedSkip = false;
      }
      return isLocked;
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: timestamp,
        label: 'Session lock state unavailable',
        reason: 'lockStateCheckFailed',
        error: error,
      );
      return _isSessionLocked;
    }
  }

  Future<void> _syncSessionStateFromPlatform(DateTime timestamp) async {
    if (_isPollingSessionState ||
        _isDisposed ||
        !platform.session.capability.isUsable) {
      return;
    }

    _isPollingSessionState = true;
    try {
      final isLocked = await platform.session.isLocked();
      final previousState = _sessionState;
      final nextState = isLocked
          ? DashboardSessionState.locked
          : DashboardSessionState.unlocked;

      if (previousState == nextState) {
        return;
      }

      _sessionState = nextState;
      _hasLoggedAlreadyLockedSkip = false;
      if (!isLocked) {
        _cancelUnlockRetry(reason: 'sessionNotLockedForRetry');
      }
      _lastActionLabel = isLocked ? 'Session locked' : 'Session unlocked';
      _appendLog(
        timestamp: timestamp,
        category: DashboardLogCategory.action,
        message: _lastActionLabel,
        reason: 'sessionStatePoll',
      );
      _publish(_lastDecision);
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: timestamp,
        label: 'Session lock state unavailable',
        reason: 'lockStateCheckFailed',
        error: error,
      );
      _publish(_lastDecision);
    } finally {
      _isPollingSessionState = false;
    }
  }

  Future<void> _wakeFromDecision(DateTime timestamp) async {
    if (_isActionThrottled(_ActionKind.wake, timestamp)) {
      _appendThrottledActionLog(timestamp, 'Wake throttled');
      _publish();
      return;
    }
    _markAction(_ActionKind.wake, timestamp);

    if (!platform.session.capability.isUsable) {
      _lastActionLabel = 'Wake unsupported';
      _appendLog(
        timestamp: timestamp,
        category: DashboardLogCategory.error,
        message: _capabilityFailureMessage(
          _lastActionLabel,
          platform.session.capability,
        ),
        reason: 'unsupported',
      );
      _publish();
      return;
    }

    try {
      await platform.session.wakeDisplay();
      _lastActionLabel = 'Wake requested';
      _appendLog(
        timestamp: timestamp,
        category: DashboardLogCategory.action,
        message: _lastActionLabel,
        reason: 'proximityDecision',
      );
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: timestamp,
        label: 'Wake failed',
        reason: 'wakeFailed',
        error: error,
      );
    }
    _publish();
  }

  Future<void> _unlockFromDecision(DateTime timestamp) async {
    if (_isAutoUnlockSuppressed) {
      _appendAutoUnlockSuppressedLog(timestamp);
      _publish();
      return;
    }

    if (!platform.session.capability.isUsable) {
      _lastActionLabel = 'Unlock skipped';
      _appendLog(
        timestamp: timestamp,
        category: DashboardLogCategory.error,
        message: _capabilityFailureMessage(
          _lastActionLabel,
          platform.session.capability,
        ),
        reason: 'lockStateUnavailable',
      );
      _publish();
      return;
    }

    bool isLocked;
    try {
      isLocked = await platform.session.isLocked();
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: timestamp,
        label: 'Session lock state unavailable',
        reason: 'lockStateCheckFailed',
        error: error,
      );
      _publish();
      return;
    }
    if (!isLocked) {
      _sessionState = DashboardSessionState.unlocked;
      _lastActionLabel = 'Unlock skipped';
      _appendLog(
        timestamp: timestamp,
        category: DashboardLogCategory.action,
        message: _lastActionLabel,
        reason: 'sessionNotLocked',
      );
      _publish();
      return;
    }
    _sessionState = DashboardSessionState.locked;

    if (_isActionThrottled(_ActionKind.unlock, timestamp)) {
      _appendThrottledActionLog(timestamp, 'Unlock throttled');
      _publish();
      return;
    }
    _markAction(_ActionKind.unlock, timestamp);

    if (!platform.unlock.capability.isUsable) {
      _lastActionLabel = 'Unlock unsupported';
      final isUnsupported =
          platform.unlock.capability.kind == CapabilityStatusKind.unsupported;
      _appendLog(
        timestamp: timestamp,
        category: isUnsupported
            ? DashboardLogCategory.action
            : DashboardLogCategory.error,
        message: _capabilityFailureMessage(
          _lastActionLabel,
          platform.unlock.capability,
        ),
        reason: platform.unlock.capability.kind.name,
      );
      _publish();
      return;
    }

    final result = await _attemptUnlock(
      timestamp: timestamp,
      attempt: 0,
    );
    await _scheduleUnlockRetryIfNeeded(
      result: result,
      attempt: 0,
    );
  }

  Future<UnlockResult> _attemptUnlock({
    required DateTime timestamp,
    required int attempt,
  }) async {
    try {
      final result = await platform.unlock.unlock();
      if (result.success) {
        _sessionState = DashboardSessionState.unlocked;
        _clearAutoUnlockSuppression();
      }
      _lastActionLabel = result.success ? 'Unlocked session' : 'Unlock failed';
      _appendLog(
        timestamp: timestamp,
        category: result.success
            ? DashboardLogCategory.action
            : DashboardLogCategory.error,
        message: _lastActionLabel,
        reason: result.reason,
      );
      _publish();
      return result;
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: timestamp,
        label: 'Unlock failed',
        reason: 'unlockFailed',
        error: error,
      );
      _publish();
      return const UnlockResult(success: false, reason: 'unlockFailed');
    }
  }

  Future<void> _scheduleUnlockRetryIfNeeded({
    required UnlockResult result,
    required int attempt,
  }) async {
    if (!_isMonitoring ||
        !config.enableMacAutoUnlock ||
        !platform.session.capability.isUsable) {
      return;
    }

    if (!result.success && result.reason != 'stillLocked') {
      _suspendAutoUnlockUntilDeviceLeaves('unlockFailed');
      _publish();
      return;
    }

    bool stillLocked;
    try {
      stillLocked = await platform.session.isLocked();
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Session lock state unavailable',
        reason: 'lockStateCheckFailed',
        error: error,
      );
      _publish();
      return;
    }
    if (!stillLocked) {
      _clearAutoUnlockSuppression();
      _sessionState = DashboardSessionState.unlocked;
      return;
    }

    if (attempt >= _unlockRetryLimit) {
      _suspendAutoUnlockUntilDeviceLeaves('unlockFailed');
      _publish();
      return;
    }

    _sessionState = DashboardSessionState.locked;
    _cancelUnlockRetry();
    _appendLog(
      timestamp: DateTime.now(),
      category: DashboardLogCategory.action,
      message: 'Unlock retry scheduled',
      reason: 'unlockRetryScheduled',
    );
    _publish();

    _unlockRetryTimer = Timer(_unlockRetryDelay, () {
      unawaited(_runUnlockRetry(attempt + 1));
    });
  }

  Future<void> _runUnlockRetry(int attempt) async {
    _unlockRetryTimer = null;
    if (!_isMonitoring) {
      _appendUnlockRetrySkipped('monitoringStoppedForRetry');
      return;
    }
    if (!config.enableMacAutoUnlock) {
      _appendUnlockRetrySkipped('autoUnlockDisabledForRetry');
      return;
    }
    if (!platform.unlock.capability.isUsable) {
      _appendUnlockRetrySkipped('unlockUnavailableForRetry');
      return;
    }
    if (!platform.session.capability.isUsable) {
      _appendUnlockRetrySkipped('sessionUnavailableForRetry');
      return;
    }

    bool stillLocked;
    try {
      stillLocked = await platform.session.isLocked();
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Session lock state unavailable',
        reason: 'lockStateCheckFailed',
        error: error,
      );
      _publish();
      return;
    }
    if (!stillLocked) {
      _sessionState = DashboardSessionState.unlocked;
      _appendUnlockRetrySkipped('sessionNotLockedForRetry');
      return;
    }

    final result = await _attemptUnlock(
      timestamp: DateTime.now(),
      attempt: attempt,
    );
    await _scheduleUnlockRetryIfNeeded(
      result: result,
      attempt: attempt,
    );
  }

  void _publish([PresenceDecision? decision, bool syncTray = true]) {
    if (_isDisposed) {
      return;
    }

    final currentDecision = decision ?? _lastDecision;
    if (currentDecision == null) {
      _value = DashboardState(
        snapshot: DashboardSnapshot(
          platformLabel: platform.platformLabel,
          monitoringStatus: _monitoringStatusLabel,
          stateLabel: _isSessionLocked ? 'Locked' : 'Idle',
          bestRssi: null,
          selectedDeviceCount: _selectedDeviceIds.length,
          lastActionLabel: _lastActionLabel,
          bluetoothCapabilityLabel:
              _capabilityLabel(platform.scanner.capability),
          autoLockCapabilityLabel:
              _capabilityLabel(platform.session.capability),
          wakeCapabilityLabel: _capabilityLabel(platform.session.capability),
          autoUnlockCapabilityLabel:
              _capabilityLabel(platform.unlock.capability),
          trayCapabilityLabel: _capabilityLabel(platform.tray.capability),
          startupCapabilityLabel: _capabilityLabel(platform.startup.capability),
          startupEnabled: _isStartupEnabled,
          autoUnlockSecretConfigured: _isAutoUnlockSecretConfigured,
          autoUnlockSecretEditable: _isAutoUnlockSecretEditable,
          autoUnlockPermissionSettingsAvailable:
              _isAutoUnlockPermissionSettingsAvailable,
        ),
        devices: const [],
        logs: List.unmodifiable(_logs),
        config: config,
      );
    } else {
      _value = DashboardState(
        snapshot: snapshotFromDecision(
          platformLabel: platform.platformLabel,
          decision: currentDecision,
          config: config,
          isMonitoring: _isMonitoring,
          isScanning: _isScanning,
          isSessionLocked: _isSessionLocked,
          lastActionLabel: _lastActionLabel,
          bluetoothCapability: platform.scanner.capability,
          autoLockCapability: platform.session.capability,
          wakeCapability: platform.session.capability,
          autoUnlockCapability: platform.unlock.capability,
          trayCapability: platform.tray.capability,
          startupCapability: platform.startup.capability,
          startupEnabled: _isStartupEnabled,
          autoUnlockSecretConfigured: _isAutoUnlockSecretConfigured,
          autoUnlockSecretEditable: _isAutoUnlockSecretEditable,
          autoUnlockPermissionSettingsAvailable:
              _isAutoUnlockPermissionSettingsAvailable,
        ),
        devices: _devicesFromPublishedList(currentDecision),
        logs: List.unmodifiable(_logs),
        config: config,
      );
    }

    if (!_states.isClosed) {
      _states.add(_value);
    }

    if (syncTray) {
      _syncTrayStatus();
    }
  }

  List<DashboardDeviceView> _devicesFromPublishedList(
    PresenceDecision currentDecision,
  ) {
    final publishedDecision = _visibleDeviceListDecision;
    if (publishedDecision == null) {
      return devicesFromDecision(currentDecision);
    }
    final displayDecision = PresenceDecision(
      shouldLock: currentDecision.shouldLock,
      shouldWake: currentDecision.shouldWake,
      shouldUnlock: currentDecision.shouldUnlock,
      reason: currentDecision.reason,
      devices: publishedDecision.devices,
      deviceStates: currentDecision.deviceStates,
      timestamp: currentDecision.timestamp,
    );
    return devicesFromDecision(displayDecision);
  }

  void _syncTrayStatus() {
    if (!platform.tray.capability.isUsable) {
      return;
    }

    final hasBlockingWarning = !platform.scanner.capability.isUsable ||
        !platform.session.capability.isUsable;
    final status = hasBlockingWarning
        ? TrayStatus.warning
        : _isSessionLocked || _lastActionLabel == 'Locked screen'
            ? TrayStatus.locked
            : _isMonitoring
                ? TrayStatus.monitoring
                : TrayStatus.normal;

    unawaited(
      _setTrayStatusSafely(
        status,
        recentDeviceSummary: _recentDeviceSummary(),
        isMonitoring: _isMonitoring,
      ),
    );
  }

  Future<void> _setTrayStatusSafely(
    TrayStatus status, {
    required String recentDeviceSummary,
    required bool isMonitoring,
  }) async {
    try {
      await platform.tray.setStatus(
        status,
        recentDeviceSummary: recentDeviceSummary,
        isMonitoring: isMonitoring,
      );
    } catch (error) {
      _appendPlatformFailureLog(
        timestamp: DateTime.now(),
        label: 'Tray update failed',
        reason: 'trayStatusUpdateFailed',
        error: error,
      );
      _publish(_lastDecision, false);
    }
  }

  String _recentDeviceSummary() {
    if (_visibleDevices.isEmpty) {
      return 'No recent devices';
    }

    final selectedDevices = _visibleDevices.values.where(
      (event) => _selectedDeviceIds.contains(event.deviceId),
    );
    final candidates =
        selectedDevices.isEmpty ? _visibleDevices.values : selectedDevices;
    final event = candidates.reduce(_betterRecentDevice);
    return '${_trayDeviceName(event)} ${event.rssi} dBm';
  }

  BleScanEvent _betterRecentDevice(BleScanEvent left, BleScanEvent right) {
    if (right.rssi != left.rssi) {
      return right.rssi > left.rssi ? right : left;
    }
    return right.seenAt.isAfter(left.seenAt) ? right : left;
  }

  String _trayDeviceName(BleScanEvent event) {
    final displayName = event.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final addressHint = event.addressHint?.trim();
    if (addressHint != null && addressHint.isNotEmpty) {
      return addressHint;
    }

    return _shortDeviceId(event.deviceId);
  }

  String _shortDeviceId(String deviceId) {
    if (deviceId.length <= 12) {
      return deviceId;
    }
    return '${deviceId.substring(0, 8)}...'
        '${deviceId.substring(deviceId.length - 4)}';
  }

  void _appendScanLogIfUseful(BleScanEvent event) {
    if (!_shouldLogScan(event)) {
      return;
    }
    _appendScanLog(event);
  }

  bool _shouldLogScan(BleScanEvent event) {
    final lastSample = _lastLoggedScanSamples[event.deviceId];
    if (lastSample == null) {
      _lastLoggedScanSamples[event.deviceId] = _LoggedScanSample(event);
      return true;
    }

    final elapsed = event.seenAt.difference(lastSample.seenAt);
    final rssiChanged =
        (event.rssi - lastSample.rssi).abs() >= _scanLogRssiChangeThreshold;
    if (elapsed >= _scanLogSampleInterval || rssiChanged) {
      _lastLoggedScanSamples[event.deviceId] = _LoggedScanSample(event);
      return true;
    }

    return false;
  }

  void _appendScanLog(BleScanEvent event) {
    _appendLog(
      timestamp: event.seenAt,
      category: DashboardLogCategory.scan,
      message: 'Scan ${event.deviceId} ${event.rssi} dBm',
      displayName: event.displayName,
      addressHint: event.addressHint,
      deviceId: event.deviceId,
      rssi: event.rssi,
      reason: 'bleAdvertisement',
      manufacturerData: event.manufacturerData,
      rawAdvertisement: event.rawAdvertisement,
      sessionState: _sessionState,
    );
  }

  bool _isActionThrottled(_ActionKind kind, DateTime timestamp) {
    final lastActionAt = _lastActionAt[kind];
    if (lastActionAt == null) {
      return false;
    }
    return timestamp.difference(lastActionAt) < _actionThrottleWindow;
  }

  void _markAction(_ActionKind kind, DateTime timestamp) {
    _lastActionAt[kind] = timestamp;
  }

  void _appendThrottledActionLog(DateTime timestamp, String message) {
    _lastActionLabel = message;
    _appendLog(
      timestamp: timestamp,
      category: DashboardLogCategory.action,
      message: message,
      reason: 'actionThrottled',
    );
  }

  void _appendPlatformFailureLog({
    required DateTime timestamp,
    required String label,
    required String reason,
    required Object error,
  }) {
    _lastActionLabel = label;
    _appendLog(
      timestamp: timestamp,
      category: DashboardLogCategory.error,
      message: '$label: $error',
      reason: reason,
    );
  }

  void _appendLog({
    required DateTime timestamp,
    required DashboardLogCategory category,
    required String message,
    String? displayName,
    String? addressHint,
    String? deviceId,
    int? rssi,
    String? reason,
    List<int>? manufacturerData,
    Map<String, Object?>? rawAdvertisement,
    DashboardSessionState? sessionState,
  }) {
    _logs.insert(
      0,
      DashboardLogEntry(
        timestamp: timestamp,
        category: category,
        message: message,
        platform: platform.platformLabel,
        displayName: displayName,
        addressHint: addressHint,
        deviceId: deviceId,
        rssi: rssi,
        reason: reason,
        manufacturerData: manufacturerData,
        rawAdvertisement: rawAdvertisement,
        sessionState: sessionState ?? _sessionState,
      ),
    );
    if (_logs.length > 100) {
      _logs.removeLast();
    }
  }

  String get _monitoringStatusLabel {
    if (_isMonitoring) {
      return 'Monitoring';
    }
    if (_isScanning) {
      return 'Scanning';
    }
    return 'Monitoring paused';
  }

  bool get _isAutoUnlockSecretEditable {
    return _isMacPlatform &&
        platform.secureStore.capability.isUsable &&
        platform.unlock.capability.kind != CapabilityStatusKind.unsupported;
  }

  bool get _isMacPlatform {
    return platform.platformLabel.trim().toLowerCase() == 'macos';
  }

  bool get _isAutoUnlockPermissionSettingsAvailable {
    return _isMacPlatform &&
        platform.unlock.capability.kind ==
            CapabilityStatusKind.permissionDenied;
  }

  bool get _isSessionLocked => _sessionState.isLockedLike;

  bool get _isAutoUnlockSuppressed => _autoUnlockSuppressionReason != null;

  void _suspendAutoUnlockUntilDeviceLeaves(String reason) {
    _autoUnlockSuppressionReason = reason;
    _hasLoggedAutoUnlockSuppression = false;
    _cancelWakeUnlockTimer();
    _cancelUnlockRetry(reason: 'autoUnlockSuppressedForRetry');
  }

  void _clearAutoUnlockSuppression() {
    _autoUnlockSuppressionReason = null;
    _hasLoggedAutoUnlockSuppression = false;
  }

  void _clearAutoUnlockSuppressionIfDeviceLeft(PresenceDecision decision) {
    if (!_isAutoUnlockSuppressed || _hasCloseTrackedDevice(decision)) {
      return;
    }
    _clearAutoUnlockSuppression();
  }

  bool _hasCloseTrackedDevice(PresenceDecision decision) {
    return decision.deviceStates.values.any(
      (presence) => presence.state == DevicePresenceState.close,
    );
  }

  void _appendAutoUnlockSuppressedLog(DateTime timestamp) {
    if (_hasLoggedAutoUnlockSuppression) {
      return;
    }
    _hasLoggedAutoUnlockSuppression = true;
    _lastActionLabel = 'Auto unlock suspended';
    _appendLog(
      timestamp: timestamp,
      category: DashboardLogCategory.action,
      message: _lastActionLabel,
      reason: _autoUnlockSuppressionReason,
      sessionState: _sessionState,
    );
  }
}

enum _ActionKind {
  lock,
  wake,
  unlock,
}

enum AppCommandKind {
  openSettings,
  quit,
}

class AppCommand {
  const AppCommand({
    required this.kind,
    required this.timestamp,
  });

  final AppCommandKind kind;
  final DateTime timestamp;
}

class _LoggedScanSample {
  _LoggedScanSample(BleScanEvent event)
      : seenAt = event.seenAt,
        rssi = event.rssi;

  final DateTime seenAt;
  final int rssi;
}

String _sessionEventLabel(SessionEventKind kind) {
  switch (kind) {
    case SessionEventKind.locked:
      return 'Session locked';
    case SessionEventKind.unlocked:
      return 'Session unlocked';
    case SessionEventKind.displaySleep:
      return 'Display sleep';
    case SessionEventKind.displayWake:
      return 'Display wake';
    case SessionEventKind.systemSleep:
      return 'System sleep';
    case SessionEventKind.systemWake:
      return 'System wake';
  }
}

String _sessionEventReason(SessionEventKind kind) {
  switch (kind) {
    case SessionEventKind.locked:
      return 'locked';
    case SessionEventKind.unlocked:
      return 'unlocked';
    case SessionEventKind.displaySleep:
      return 'displaySleep';
    case SessionEventKind.displayWake:
      return 'displayWake';
    case SessionEventKind.systemSleep:
      return 'systemSleep';
    case SessionEventKind.systemWake:
      return 'systemWake';
  }
}

String? _normalizedText(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

String _presenceStateLabel(DevicePresenceState state) {
  switch (state) {
    case DevicePresenceState.close:
      return 'close';
    case DevicePresenceState.away:
      return 'away';
    case DevicePresenceState.lost:
      return 'lost';
  }
}

String _capabilityLabel(CapabilityStatus capability) {
  switch (capability.kind) {
    case CapabilityStatusKind.supported:
      return 'supported';
    case CapabilityStatusKind.unsupported:
      return 'unsupported';
    case CapabilityStatusKind.permissionDenied:
      return capability.description ?? 'permission denied';
    case CapabilityStatusKind.temporarilyUnavailable:
      return capability.description ?? 'temporarily unavailable';
    case CapabilityStatusKind.poweredOff:
      return capability.description ?? 'powered off';
    case CapabilityStatusKind.missingSecret:
      return capability.description ?? 'missing secret';
    case CapabilityStatusKind.failedWithReason:
      return capability.description ?? 'failed';
    case CapabilityStatusKind.unknown:
      return capability.description ?? 'unknown';
  }
}

String _capabilityFailureMessage(String label, CapabilityStatus capability) {
  return '$label: ${_capabilityLabel(capability)}';
}

void unawaited(Future<void> future) {}
