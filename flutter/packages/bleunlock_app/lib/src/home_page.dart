import 'package:bleunlock_app/src/controllers/app_coordinator.dart';
import 'package:bleunlock_app/src/sections/device_section.dart';
import 'package:bleunlock_app/src/sections/log_section.dart';
import 'package:bleunlock_app/src/sections/overview_section.dart';
import 'package:bleunlock_app/src/sections/rules_section.dart';
import 'package:bleunlock_app/src/sections/system_section.dart';
import 'package:bleunlock_app/src/sections/validation_section.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_app/src/widgets/status_pill.dart';
import 'package:flutter/material.dart';

class BLEUnlockHomePage extends StatefulWidget {
  const BLEUnlockHomePage({required this.coordinator, super.key});

  final AppCoordinator coordinator;

  @override
  State<BLEUnlockHomePage> createState() => _BLEUnlockHomePageState();
}

class _BLEUnlockHomePageState extends State<BLEUnlockHomePage> {
  late final String _validationSessionId = _createValidationSessionId();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardState>(
      stream: widget.coordinator.states,
      initialData: widget.coordinator.value,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.coordinator.value;
        final isMonitoring = state.snapshot.monitoringStatus == 'Monitoring';
        final canStartMonitoring = state.devices.any(
          (device) => device.isSelected,
        );

        return DefaultTabController(
          length: _homeTabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('BLEUnlock'),
              actions: [
                StatusPill(
                  label: state.snapshot.monitoringStatus,
                  icon: isMonitoring ? Icons.radar : Icons.pause_circle,
                ),
                const SizedBox(width: 16),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final tab in _homeTabs)
                    Tab(icon: Icon(tab.icon), text: tab.label),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _TabPage(
                  child: OverviewSection(
                    snapshot: state.snapshot,
                    isMonitoring: isMonitoring,
                    canStartMonitoring: canStartMonitoring,
                    onStartMonitoring: widget.coordinator.startMonitoring,
                    onPauseMonitoring: widget.coordinator.pause,
                    onLockNow: widget.coordinator.lockNow,
                    monitoringHint: !isMonitoring &&
                            state.devices.isNotEmpty &&
                            !canStartMonitoring
                        ? '请先在设备列表中选择一个或多个设备，再开始监听。'
                        : null,
                  ),
                ),
                _TabPage(
                  child: DeviceSection(
                    devices: state.devices,
                    isMonitoring: isMonitoring,
                    onStartScanning: widget.coordinator.startScanning,
                    onStartMonitoring: widget.coordinator.startMonitoring,
                    onPauseScanning: widget.coordinator.pause,
                    onLockNow: widget.coordinator.lockNow,
                    onRefreshDevices: widget.coordinator.refreshDeviceList,
                    onDeviceSelectionChanged:
                        widget.coordinator.setDeviceSelected,
                  ),
                ),
                _TabPage(
                  child: RulesSection(
                    config: state.config,
                    canConfigureMacAutoUnlock:
                        state.snapshot.autoUnlockSecretEditable,
                    macAutoUnlockStatusLabel:
                        state.snapshot.autoUnlockCapabilityLabel,
                    onConfigChanged: widget.coordinator.updateConfig,
                    onMacAutoUnlockChanged: (enabled) {
                      _handleMacAutoUnlockChanged(context, state, enabled);
                    },
                    onResetRulesAndDevices:
                        widget.coordinator.resetRulesAndSelectedDevices,
                  ),
                ),
                _TabPage(
                  child: SystemSection(
                    snapshot: state.snapshot,
                    lockSync: state.lockSync,
                    showMacAutoUnlockPassword:
                        state.snapshot.autoUnlockSecretEditable,
                    onCapabilitiesRefreshed:
                        widget.coordinator.retryCapabilityCheck,
                    onStartupChanged: widget.coordinator.setStartupEnabled,
                    onMacAutoUnlockPasswordSaved:
                        widget.coordinator.setMacAutoUnlockPassword,
                    onMacAutoUnlockPasswordCleared:
                        widget.coordinator.clearMacAutoUnlockPassword,
                    onMacAutoUnlockPermissionSettingsOpened:
                        widget.coordinator.openMacAutoUnlockPermissionSettings,
                    onLockSyncConfigChanged:
                        widget.coordinator.updateLockSyncConfig,
                    onLockSyncSharedSecretGenerated:
                        widget.coordinator.generateLockSyncSharedSecret,
                    onLockSyncRestarted: widget.coordinator.restartLockSync,
                  ),
                ),
                _TabPage(
                  child: ValidationSection(
                    state: state,
                    validationSessionId: _validationSessionId,
                  ),
                ),
                _TabPage(
                  child: LogSection(
                    state: state,
                    logs: state.logs,
                    validationSessionId: _validationSessionId,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleMacAutoUnlockChanged(
    BuildContext context,
    DashboardState state,
    bool enabled,
  ) async {
    final nextConfig = state.config.copyWith(enableMacAutoUnlock: enabled);
    if (!enabled) {
      widget.coordinator.updateConfig(nextConfig);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('要开启 macOS 自动解锁吗？'),
        content: const Text(
          'BLE 信号无法证明是谁正拿着设备。\n\n'
          '如果设备丢失，或信号被伪造，自动解锁仍可能被触发。\n\n'
          '请只在可信环境中开启此功能。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.verified_user),
            label: const Text('开启'),
          ),
        ],
      ),
    );

    if (!context.mounted || confirmed != true) {
      return;
    }

    widget.coordinator.updateConfig(
      nextConfig,
      acknowledgeMacAutoUnlockRisk: true,
    );
  }
}

class _HomeTab {
  const _HomeTab({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

const List<_HomeTab> _homeTabs = [
  _HomeTab(label: '总览', icon: Icons.dashboard_outlined),
  _HomeTab(label: '设备', icon: Icons.bluetooth_searching),
  _HomeTab(label: '规则', icon: Icons.tune),
  _HomeTab(label: '系统', icon: Icons.settings_outlined),
  _HomeTab(label: '验收', icon: Icons.verified_outlined),
  _HomeTab(label: '日志', icon: Icons.article_outlined),
];

class _TabPage extends StatelessWidget {
  const _TabPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [child],
    );
  }
}

String _createValidationSessionId() {
  final timestamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  return 'validation-$timestamp';
}
