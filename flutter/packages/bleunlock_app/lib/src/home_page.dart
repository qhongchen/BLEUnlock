import 'package:bleunlock_app/src/controllers/app_coordinator.dart';
import 'package:bleunlock_app/src/localization/zh_labels.dart';
import 'package:bleunlock_app/src/lock_sync/lock_sync_models.dart';
import 'package:bleunlock_app/src/sections/device_section.dart';
import 'package:bleunlock_app/src/sections/log_section.dart';
import 'package:bleunlock_app/src/sections/overview_section.dart';
import 'package:bleunlock_app/src/sections/rules_section.dart';
import 'package:bleunlock_app/src/sections/system_section.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:flutter/material.dart';

class BLEUnlockHomePage extends StatefulWidget {
  const BLEUnlockHomePage({required this.coordinator, super.key});

  final AppCoordinator coordinator;

  @override
  State<BLEUnlockHomePage> createState() => _BLEUnlockHomePageState();
}

class _BLEUnlockHomePageState extends State<BLEUnlockHomePage> {
  late final TextEditingController _serverPortController;
  late final TextEditingController _serverSharedSecretController;
  late final TextEditingController _clientHostController;
  late final TextEditingController _clientPortController;
  late final TextEditingController _clientSharedSecretController;

  _AppNavItem _selectedItem = _AppNavItem.role;
  bool _syncProximityLocks = true;
  bool _syncManualLocks = false;
  String _editorSignature = '';

  @override
  void initState() {
    super.initState();
    final config = widget.coordinator.value.lockSync.config;
    _serverPortController = TextEditingController();
    _serverSharedSecretController = TextEditingController();
    _clientHostController = TextEditingController();
    _clientPortController = TextEditingController();
    _clientSharedSecretController = TextEditingController();
    _syncRoleEditors(config);
  }

  @override
  void dispose() {
    _serverPortController.dispose();
    _serverSharedSecretController.dispose();
    _clientHostController.dispose();
    _clientPortController.dispose();
    _clientSharedSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DashboardState>(
      stream: widget.coordinator.states,
      initialData: widget.coordinator.value,
      builder: (context, snapshot) {
        final state = snapshot.data ?? widget.coordinator.value;
        _syncRoleEditors(state.lockSync.config);

        final isMonitoring = state.snapshot.monitoringStatus == 'Monitoring';
        final canStartMonitoring = state.devices.any(
          (device) => device.isSelected,
        );
        final navItems = _navItemsForRole(state.lockSync.config.role);
        final activeItem =
            navItems.contains(_selectedItem) ? _selectedItem : _AppNavItem.role;

        return Scaffold(
          body: Row(
            children: [
              _AppSidebar(
                selectedItem: activeItem,
                items: navItems,
                lockSync: state.lockSync,
                monitoringStatus: state.snapshot.monitoringStatus,
                selectedDeviceCount: state.snapshot.selectedDeviceCount,
                onItemSelected: (item) {
                  setState(() {
                    _selectedItem = item;
                  });
                },
                onLockNow: widget.coordinator.lockNow,
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: _MainWorkspace(
                  title: _titleForItem(activeItem, state.lockSync.config.role),
                  subtitle:
                      _subtitleForItem(activeItem, state.lockSync.config.role),
                  child: _buildContent(
                    item: activeItem,
                    state: state,
                    isMonitoring: isMonitoring,
                    canStartMonitoring: canStartMonitoring,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent({
    required _AppNavItem item,
    required DashboardState state,
    required bool isMonitoring,
    required bool canStartMonitoring,
  }) {
    switch (item) {
      case _AppNavItem.role:
        return _RoleModeWorkspace(
          lockSync: state.lockSync,
          serverPortController: _serverPortController,
          serverSharedSecretController: _serverSharedSecretController,
          clientHostController: _clientHostController,
          clientPortController: _clientPortController,
          clientSharedSecretController: _clientSharedSecretController,
          syncProximityLocks: _syncProximityLocks,
          syncManualLocks: _syncManualLocks,
          onSyncProximityLocksChanged: (value) {
            setState(() {
              _syncProximityLocks = value;
            });
          },
          onSyncManualLocksChanged: (value) {
            setState(() {
              _syncManualLocks = value;
            });
          },
          onServerSaved: _saveServerConfig,
          onClientSaved: _saveClientConfig,
          onDisabled: _disableLockSync,
          onSharedSecretGenerated:
              widget.coordinator.generateLockSyncSharedSecret,
          onRestarted: widget.coordinator.restartLockSync,
        );
      case _AppNavItem.overview:
        if (state.lockSync.config.role == LockSyncRole.client) {
          return _ClientOverviewWorkspace(
            state: state,
          );
        }
        if (state.lockSync.config.role == LockSyncRole.server) {
          return _ServerOverviewWorkspace(
            state: state,
          );
        }
        return _WorkspaceScroll(
          child: OverviewSection(
            snapshot: state.snapshot,
            isMonitoring: isMonitoring,
            canStartMonitoring: canStartMonitoring,
            onStartMonitoring: widget.coordinator.startMonitoring,
            onPauseMonitoring: widget.coordinator.pause,
            onLockNow: widget.coordinator.lockNow,
            monitoringHint:
                !isMonitoring && state.devices.isNotEmpty && !canStartMonitoring
                    ? '请先在设备列表中选择一个或多个设备，再开始监听。'
                    : null,
          ),
        );
      case _AppNavItem.devices:
        return _WorkspaceScroll(
          child: DeviceSection(
            devices: state.devices,
            isMonitoring: isMonitoring,
            onStartScanning: widget.coordinator.startScanning,
            onStartMonitoring: widget.coordinator.startMonitoring,
            onPauseScanning: widget.coordinator.pause,
            onRefreshDevices: widget.coordinator.refreshDeviceList,
            onDeviceSelectionChanged: widget.coordinator.setDeviceSelected,
          ),
        );
      case _AppNavItem.rules:
        return _WorkspaceScroll(
          child: RulesSection(
            config: state.config,
            onConfigChanged: widget.coordinator.updateConfig,
            onResetRulesAndDevices:
                widget.coordinator.resetRulesAndSelectedDevices,
          ),
        );
      case _AppNavItem.system:
        return _WorkspaceScroll(
          child: SystemSection(
            snapshot: state.snapshot,
            lockSync: state.lockSync,
            wakeOnProximity: state.config.wakeOnProximity,
            macAutoUnlockEnabled: state.config.enableMacAutoUnlock,
            canConfigureMacAutoUnlock: state.snapshot.autoUnlockSecretEditable,
            macAutoUnlockStatusLabel: state.snapshot.autoUnlockCapabilityLabel,
            onCapabilitiesRefreshed: widget.coordinator.retryCapabilityCheck,
            onStartupChanged: widget.coordinator.setStartupEnabled,
            onWakeOnProximityChanged: (enabled) {
              widget.coordinator.updateConfig(
                state.config.copyWith(wakeOnProximity: enabled),
              );
            },
            onMacAutoUnlockChanged: (enabled) {
              _handleMacAutoUnlockChanged(context, state, enabled);
            },
            onLockSyncConfigChanged: widget.coordinator.updateLockSyncConfig,
            onLockSyncSharedSecretGenerated:
                widget.coordinator.generateLockSyncSharedSecret,
            onLockSyncRestarted: widget.coordinator.restartLockSync,
          ),
        );
      case _AppNavItem.logs:
        if (state.lockSync.config.role == LockSyncRole.client) {
          return _WorkspaceScroll(
            child: _ClientLogPanel(logs: _lockSyncLogs(state)),
          );
        }
        return _WorkspaceScroll(
          child: LogSection(
            state: state,
            logs: state.logs,
          ),
        );
    }
  }

  Future<void> _saveServerConfig() async {
    final parsedPort = int.tryParse(_serverPortController.text.trim());
    await widget.coordinator.updateLockSyncConfig(
      LockSyncConfig(
        role: LockSyncRole.server,
        port: parsedPort ?? LockSyncConfig.defaultPort,
        sharedSecret: _serverSharedSecretController.text.trim(),
        syncProximityLocks: _syncProximityLocks,
        syncManualLocks: _syncManualLocks,
      ),
    );
  }

  Future<void> _saveClientConfig() async {
    final parsedPort = int.tryParse(_clientPortController.text.trim());
    await widget.coordinator.updateLockSyncConfig(
      LockSyncConfig(
        role: LockSyncRole.client,
        serverHost: _clientHostController.text.trim(),
        port: parsedPort ?? LockSyncConfig.defaultPort,
        sharedSecret: _clientSharedSecretController.text.trim(),
      ),
    );
  }

  Future<void> _disableLockSync() async {
    await widget.coordinator.updateLockSyncConfig(const LockSyncConfig());
  }

  void _syncRoleEditors(LockSyncConfig config) {
    final signature = _lockSyncConfigSignature(config);
    if (_editorSignature == signature) {
      return;
    }
    _editorSignature = signature;
    _serverPortController.text = config.port.toString();
    _serverSharedSecretController.text = config.sharedSecret;
    _clientHostController.text = config.serverHost;
    _clientPortController.text = config.port.toString();
    _clientSharedSecretController.text = config.sharedSecret;
    _syncProximityLocks = config.syncProximityLocks;
    _syncManualLocks = config.syncManualLocks;
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

    if (state.snapshot.autoUnlockPermissionSettingsAvailable) {
      final openSettings =
          await _promptMacAutoUnlockPermissionSettings(context);
      if (!context.mounted || openSettings != true) {
        return;
      }
      await widget.coordinator.openMacAutoUnlockPermissionSettings();
      return;
    }

    final confirmed = await _confirmMacAutoUnlockRisk(context);
    if (!context.mounted || confirmed != true) {
      return;
    }

    if (!state.snapshot.autoUnlockSecretConfigured) {
      final password = await _promptMacAutoUnlockPassword(context);
      if (!context.mounted || password == null || password.isEmpty) {
        return;
      }
      await widget.coordinator.setMacAutoUnlockPassword(password);
      if (!widget.coordinator.value.snapshot.autoUnlockSecretConfigured) {
        return;
      }
    }

    widget.coordinator.updateConfig(
      nextConfig,
      acknowledgeMacAutoUnlockRisk: true,
    );
  }

  Future<bool?> _confirmMacAutoUnlockRisk(BuildContext context) {
    return showDialog<bool>(
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
  }

  Future<bool?> _promptMacAutoUnlockPermissionSettings(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要开启辅助功能权限'),
        content: const Text(
          'macOS 自动解锁需要辅助功能权限。\n\n'
          '打开系统设置后，请允许 BLEUnlock 控制这台电脑，再回到应用重新开启自动解锁。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.settings),
            label: const Text('打开设置'),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptMacAutoUnlockPassword(BuildContext context) async {
    final controller = TextEditingController();
    var hasInput = false;
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              void handleChanged(String value) {
                final nextHasInput = value.isNotEmpty;
                if (nextHasInput == hasInput) {
                  return;
                }
                setDialogState(() {
                  hasInput = nextHasInput;
                });
              }

              void submit() {
                if (!hasInput) {
                  return;
                }
                Navigator.of(context).pop(controller.text);
              }

              return AlertDialog(
                title: const Text('输入 macOS 解锁密码'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '密码',
                    prefixIcon: Icon(Icons.key),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: handleChanged,
                  onSubmitted: (_) => submit(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  FilledButton.icon(
                    onPressed: hasInput ? submit : null,
                    icon: const Icon(Icons.save),
                    label: const Text('保存并开启'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }
}

class _MainWorkspace extends StatelessWidget {
  const _MainWorkspace({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(32, 26, 32, 22),
          decoration: const BoxDecoration(
            color: Color(0xFFFAFCFC),
            border: Border(
              bottom: BorderSide(color: Color(0xFFE2E8E7)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF62716E),
                    ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _AppSidebar extends StatelessWidget {
  const _AppSidebar({
    required this.selectedItem,
    required this.items,
    required this.lockSync,
    required this.monitoringStatus,
    required this.selectedDeviceCount,
    required this.onItemSelected,
    required this.onLockNow,
  });

  final _AppNavItem selectedItem;
  final List<_AppNavItem> items;
  final LockSyncSnapshot lockSync;
  final String monitoringStatus;
  final int selectedDeviceCount;
  final ValueChanged<_AppNavItem> onItemSelected;
  final Future<void> Function({String reason}) onLockNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 288,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
      color: const Color(0xFFF5F8F8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF006A62),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock_outline, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BLEUnlock',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _roleDescription(lockSync.config.role),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF687672),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SidebarStatusCard(
            role: lockSync.config.role,
            lockSync: lockSync,
            monitoringStatus: monitoringStatus,
            selectedDeviceCount: selectedDeviceCount,
          ),
          const SizedBox(height: 18),
          for (final item in items)
            _SidebarButton(
              item: item,
              selected: selectedItem == item,
              onPressed: () => onItemSelected(item),
            ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () => onLockNow(reason: 'sidebarAction'),
            icon: const Icon(Icons.lock_outline),
            label: const Text('立即锁屏'),
          ),
        ],
      ),
    );
  }
}

class _SidebarStatusCard extends StatelessWidget {
  const _SidebarStatusCard({
    required this.role,
    required this.lockSync,
    required this.monitoringStatus,
    required this.selectedDeviceCount,
  });

  final LockSyncRole role;
  final LockSyncSnapshot lockSync;
  final String monitoringStatus;
  final int selectedDeviceCount;

  @override
  Widget build(BuildContext context) {
    final roleLabel = zhDisplayText(role.label);
    final bleStatus =
        'BLE ${zhDisplayText(monitoringStatus)} · 已选 $selectedDeviceCount';
    final syncStatus = '$roleLabel ${zhDisplayText(lockSync.statusLabel)}';
    final detail = role == LockSyncRole.disabled
        ? null
        : lockSync.endpointLabel == '--'
            ? null
            : lockSync.endpointLabel;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE6E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(roleLabel),
          const SizedBox(height: 2),
          _SidebarStatusLine(text: bleStatus),
          if (role != LockSyncRole.disabled) ...[
            const SizedBox(height: 2),
            _SidebarStatusLine(
              text: detail == null ? syncStatus : '$syncStatus · $detail',
            ),
          ],
        ],
      ),
    );
  }
}

class _SidebarStatusLine extends StatelessWidget {
  const _SidebarStatusLine({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF687672),
          ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final _AppNavItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE2F0EE) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                _iconForItem(item),
                color: selected
                    ? const Color(0xFF006A62)
                    : const Color(0xFF697572),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _labelForItem(item),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: selected
                            ? const Color(0xFF006A62)
                            : const Color(0xFF3F4A47),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleModeWorkspace extends StatelessWidget {
  const _RoleModeWorkspace({
    required this.lockSync,
    required this.serverPortController,
    required this.serverSharedSecretController,
    required this.clientHostController,
    required this.clientPortController,
    required this.clientSharedSecretController,
    required this.syncProximityLocks,
    required this.syncManualLocks,
    required this.onSyncProximityLocksChanged,
    required this.onSyncManualLocksChanged,
    required this.onServerSaved,
    required this.onClientSaved,
    required this.onDisabled,
    required this.onSharedSecretGenerated,
    required this.onRestarted,
  });

  final LockSyncSnapshot lockSync;
  final TextEditingController serverPortController;
  final TextEditingController serverSharedSecretController;
  final TextEditingController clientHostController;
  final TextEditingController clientPortController;
  final TextEditingController clientSharedSecretController;
  final bool syncProximityLocks;
  final bool syncManualLocks;
  final ValueChanged<bool> onSyncProximityLocksChanged;
  final ValueChanged<bool> onSyncManualLocksChanged;
  final Future<void> Function() onServerSaved;
  final Future<void> Function() onClientSaved;
  final Future<void> Function() onDisabled;
  final Future<void> Function() onSharedSecretGenerated;
  final Future<void> Function() onRestarted;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final serverEnabled = lockSync.config.role != LockSyncRole.client;
              final clientEnabled = lockSync.config.role != LockSyncRole.server;
              final serverPanel = _ServerModePanel(
                active: lockSync.config.role == LockSyncRole.server,
                enabled: serverEnabled,
                portController: serverPortController,
                sharedSecretController: serverSharedSecretController,
                syncProximityLocks: syncProximityLocks,
                syncManualLocks: syncManualLocks,
                onSyncProximityLocksChanged: onSyncProximityLocksChanged,
                onSyncManualLocksChanged: onSyncManualLocksChanged,
                onSaved: onServerSaved,
                onDisabled: onDisabled,
                onSharedSecretGenerated: onSharedSecretGenerated,
                onRestarted: onRestarted,
              );
              final clientPanel = _ClientModePanel(
                active: lockSync.config.role == LockSyncRole.client,
                enabled: clientEnabled,
                hostController: clientHostController,
                portController: clientPortController,
                sharedSecretController: clientSharedSecretController,
                onSaved: onClientSaved,
                onDisabled: onDisabled,
                onRestarted: onRestarted,
              );
              if (constraints.maxWidth < 860) {
                return Column(
                  children: [
                    serverPanel,
                    const SizedBox(height: 14),
                    clientPanel,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: serverPanel),
                  const SizedBox(width: 14),
                  Expanded(child: clientPanel),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServerModePanel extends StatelessWidget {
  const _ServerModePanel({
    required this.active,
    required this.enabled,
    required this.portController,
    required this.sharedSecretController,
    required this.syncProximityLocks,
    required this.syncManualLocks,
    required this.onSyncProximityLocksChanged,
    required this.onSyncManualLocksChanged,
    required this.onSaved,
    required this.onDisabled,
    required this.onSharedSecretGenerated,
    required this.onRestarted,
  });

  final bool active;
  final bool enabled;
  final TextEditingController portController;
  final TextEditingController sharedSecretController;
  final bool syncProximityLocks;
  final bool syncManualLocks;
  final ValueChanged<bool> onSyncProximityLocksChanged;
  final ValueChanged<bool> onSyncManualLocksChanged;
  final Future<void> Function() onSaved;
  final Future<void> Function() onDisabled;
  final Future<void> Function() onSharedSecretGenerated;
  final Future<void> Function() onRestarted;

  @override
  Widget build(BuildContext context) {
    return _ModePanel(
      active: active,
      enabled: enabled,
      icon: Icons.cast_connected,
      title: 'Server',
      subtitle: '作为主控端，依据本机 BLE 距离规则通知 Client 锁屏。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: portController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              labelText: '监听端口',
              prefixIcon: Icon(Icons.settings_ethernet),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: sharedSecretController,
            enabled: enabled,
            decoration: const InputDecoration(
              isDense: true,
              labelText: '共享密钥',
              prefixIcon: Icon(Icons.key_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('同步 BLEUnlock 自动锁屏'),
            subtitle: const Text('距离规则触发锁屏时通知 Client'),
            value: syncProximityLocks,
            onChanged: enabled ? onSyncProximityLocksChanged : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('同步手动锁屏'),
            subtitle: const Text('包含快捷键和系统菜单锁屏，默认建议关闭'),
            value: syncManualLocks,
            onChanged: enabled ? onSyncManualLocksChanged : null,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: enabled ? onSharedSecretGenerated : null,
                icon: const Icon(Icons.password),
                label: const Text('生成密钥'),
              ),
              OutlinedButton.icon(
                onPressed: enabled && active ? onRestarted : null,
                icon: const Icon(Icons.restart_alt),
                label: const Text('重启'),
              ),
              OutlinedButton.icon(
                onPressed: enabled && active ? onDisabled : null,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('停用'),
              ),
              FilledButton.icon(
                onPressed: enabled ? onSaved : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('启用 Server'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientModePanel extends StatelessWidget {
  const _ClientModePanel({
    required this.active,
    required this.enabled,
    required this.hostController,
    required this.portController,
    required this.sharedSecretController,
    required this.onSaved,
    required this.onDisabled,
    required this.onRestarted,
  });

  final bool active;
  final bool enabled;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController sharedSecretController;
  final Future<void> Function() onSaved;
  final Future<void> Function() onDisabled;
  final Future<void> Function() onRestarted;

  @override
  Widget build(BuildContext context) {
    return _ModePanel(
      active: active,
      enabled: enabled,
      icon: Icons.desktop_windows_outlined,
      title: 'Client',
      subtitle: '作为受控端，只接收可信 Server 的锁屏事件。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: hostController,
            enabled: enabled,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Server 地址',
              prefixIcon: Icon(Icons.dns_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: portController,
            enabled: enabled,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Server 端口',
              prefixIcon: Icon(Icons.settings_ethernet),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: sharedSecretController,
            enabled: enabled,
            decoration: const InputDecoration(
              isDense: true,
              labelText: '共享密钥',
              prefixIcon: Icon(Icons.key_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: enabled && active ? onRestarted : null,
                icon: const Icon(Icons.restart_alt),
                label: const Text('重连'),
              ),
              OutlinedButton.icon(
                onPressed: enabled && active ? onDisabled : null,
                icon: const Icon(Icons.link_off),
                label: const Text('停用'),
              ),
              FilledButton.icon(
                onPressed: enabled ? onSaved : null,
                icon: const Icon(Icons.link),
                label: const Text('启用 Client'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModePanel extends StatelessWidget {
  const _ModePanel({
    required this.active,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final bool active;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final accentColor =
        enabled ? const Color(0xFF006A62) : const Color(0xFF7A8582);
    final borderColor = !enabled
        ? const Color(0xFFD5DDDA)
        : active
            ? const Color(0xFF5BA99F)
            : const Color(0xFFD6E2DF);
    final textColor =
        enabled ? const Color(0xFF1E2926) : const Color(0xFF737F7B);
    final mutedTextColor =
        enabled ? const Color(0xFF5F6D69) : const Color(0xFF87918E);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: !enabled
            ? const Color(0xFFF4F7F6)
            : active
                ? const Color(0xFFEAF4F2)
                : const Color(0xFFFAFCFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: active && enabled ? accentColor : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFD6E2DF)),
                ),
                child: Icon(
                  icon,
                  color: active && enabled ? Colors.white : accentColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: textColor),
                          ),
                        ),
                        if (active)
                          const Icon(
                            Icons.check_circle,
                            color: Color(0xFF006A62),
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: mutedTextColor,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ServerOverviewWorkspace extends StatelessWidget {
  const _ServerOverviewWorkspace({
    required this.state,
  });

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ServerHeroPanel(
            lockSync: state.lockSync,
          ),
        ],
      ),
    );
  }
}

class _ServerHeroPanel extends StatelessWidget {
  const _ServerHeroPanel({
    required this.lockSync,
  });

  final LockSyncSnapshot lockSync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF006A62),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cast_connected, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '主控端',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '依据本机 BLE 距离规则通知 Client 锁屏。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4A5D59),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _RoleOverviewMetricGrid(
            items: [
              _RoleOverviewMetric(
                label: 'Client',
                value: lockSync.connectedClientCount.toString(),
                icon: Icons.devices_outlined,
              ),
              _RoleOverviewMetric(
                label: '最近事件',
                value: lockSync.lastEventLabel ?? '无',
                icon: Icons.bolt_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientOverviewWorkspace extends StatelessWidget {
  const _ClientOverviewWorkspace({
    required this.state,
  });

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceScroll(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ClientHeroPanel(
            lockSync: state.lockSync,
            snapshot: state.snapshot,
          ),
        ],
      ),
    );
  }
}

class _ClientHeroPanel extends StatelessWidget {
  const _ClientHeroPanel({
    required this.lockSync,
    required this.snapshot,
  });

  final LockSyncSnapshot lockSync;
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF006A62),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.link, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '受控端',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '只接收 Server 下发的锁屏事件，不参与 BLE 判断。',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF4A5D59),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _RoleOverviewMetricGrid(
            items: [
              _RoleOverviewMetric(
                label: '连接状态',
                value: zhDisplayText(lockSync.statusLabel),
                icon: _lockSyncStatusIcon(lockSync),
              ),
              _RoleOverviewMetric(
                label: 'Server',
                value: lockSync.endpointLabel,
                icon: Icons.dns_outlined,
              ),
              _RoleOverviewMetric(
                label: '最近事件',
                value: lockSync.lastEventLabel ?? '无',
                icon: Icons.bolt_outlined,
              ),
              _RoleOverviewMetric(
                label: '最近动作',
                value: zhDisplayText(snapshot.lastActionLabel),
                icon: Icons.lock_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClientLogPanel extends StatelessWidget {
  const _ClientLogPanel({required this.logs});

  final List<DashboardLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return _PlainPanel(
      title: '最近同步日志',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (logs.isEmpty)
            const Text('暂无同步日志')
          else
            for (final log in logs) _ClientLogTile(log: log),
        ],
      ),
    );
  }
}

class _ClientLogTile extends StatelessWidget {
  const _ClientLogTile({required this.log});

  final DashboardLogEntry log;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            log.category == DashboardLogCategory.error
                ? Icons.warning_amber
                : Icons.check_circle_outline,
            size: 18,
            color: log.category == DashboardLogCategory.error
                ? const Color(0xFF9A5B00)
                : const Color(0xFF006A62),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zhDisplayText(log.message)),
                const SizedBox(height: 2),
                Text(
                  zhDetailLabel(log.detailLabel),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF65736F),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            zhTimeLabel(log.timestamp),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _RoleOverviewMetricGrid extends StatelessWidget {
  const _RoleOverviewMetricGrid({required this.items});

  final List<_RoleOverviewMetric> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = constraints.maxWidth < 640 ? 2 : 4;
        final spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columnCount - 1)) / columnCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: _RoleOverviewMetricTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _RoleOverviewMetricTile extends StatelessWidget {
  const _RoleOverviewMetricTile({required this.item});

  final _RoleOverviewMetric item;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD7E5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 17, color: const Color(0xFF006A62)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _RoleOverviewMetric {
  const _RoleOverviewMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class _PlainPanel extends StatelessWidget {
  const _PlainPanel({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _WorkspaceScroll extends StatelessWidget {
  const _WorkspaceScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [child],
    );
  }
}

enum _AppNavItem {
  role,
  overview,
  devices,
  rules,
  system,
  logs,
}

List<_AppNavItem> _navItemsForRole(LockSyncRole role) {
  switch (role) {
    case LockSyncRole.disabled:
      return const [_AppNavItem.role, _AppNavItem.system, _AppNavItem.logs];
    case LockSyncRole.client:
      return const [_AppNavItem.role, _AppNavItem.overview, _AppNavItem.logs];
    case LockSyncRole.server:
      return const [
        _AppNavItem.role,
        _AppNavItem.overview,
        _AppNavItem.devices,
        _AppNavItem.rules,
        _AppNavItem.system,
        _AppNavItem.logs,
      ];
  }
}

String _labelForItem(_AppNavItem item) {
  switch (item) {
    case _AppNavItem.role:
      return '运行模式';
    case _AppNavItem.overview:
      return '总览';
    case _AppNavItem.devices:
      return '设备';
    case _AppNavItem.rules:
      return '规则';
    case _AppNavItem.system:
      return '系统';
    case _AppNavItem.logs:
      return '日志';
  }
}

IconData _iconForItem(_AppNavItem item) {
  switch (item) {
    case _AppNavItem.role:
      return Icons.hub_outlined;
    case _AppNavItem.overview:
      return Icons.dashboard_outlined;
    case _AppNavItem.devices:
      return Icons.bluetooth_searching;
    case _AppNavItem.rules:
      return Icons.tune;
    case _AppNavItem.system:
      return Icons.settings_outlined;
    case _AppNavItem.logs:
      return Icons.article_outlined;
  }
}

String _titleForItem(_AppNavItem item, LockSyncRole _) {
  return _labelForItem(item);
}

String _subtitleForItem(_AppNavItem item, LockSyncRole role) {
  switch (item) {
    case _AppNavItem.role:
      return '选择这台电脑在 BLEUnlock 网络中的角色。';
    case _AppNavItem.overview:
      switch (role) {
        case LockSyncRole.server:
          return '查看 Client 数量和最近事件。';
        case LockSyncRole.client:
          return '查看 Client 连接状态和最近事件。';
        case LockSyncRole.disabled:
          return '查看当前监听状态、最近动作和本机锁屏入口。';
      }
    case _AppNavItem.devices:
      return '扫描并选择用于距离判断的 BLE 设备。';
    case _AppNavItem.rules:
      return '配置距离阈值、锁屏延迟和判定策略。';
    case _AppNavItem.system:
      return '配置可操作的系统集成项。';
    case _AppNavItem.logs:
      return role == LockSyncRole.client
          ? '只显示 Client 与 Server 的同步事件。'
          : '查看扫描、判定、动作和错误日志。';
  }
}

IconData _lockSyncStatusIcon(LockSyncSnapshot snapshot) {
  if (!snapshot.config.isEnabled) {
    return Icons.link_off;
  }
  if (snapshot.lastError != null) {
    return Icons.warning_amber;
  }
  switch (snapshot.runtimeState) {
    case LockSyncRuntimeState.connected:
      return Icons.link;
    case LockSyncRuntimeState.connecting:
    case LockSyncRuntimeState.starting:
      return Icons.sync;
    case LockSyncRuntimeState.listening:
      return Icons.lan_outlined;
    case LockSyncRuntimeState.failed:
      return Icons.warning_amber;
    case LockSyncRuntimeState.stopped:
      return Icons.pause_circle_outline;
  }
}

String _roleDescription(LockSyncRole role) {
  switch (role) {
    case LockSyncRole.disabled:
      return '单机模式';
    case LockSyncRole.server:
      return '主控端';
    case LockSyncRole.client:
      return '受控端';
  }
}

List<DashboardLogEntry> _lockSyncLogs(DashboardState state) {
  return state.logs
      .where((entry) => entry.platform == 'lockSync')
      .take(8)
      .toList(growable: false);
}

String _lockSyncConfigSignature(LockSyncConfig config) {
  return [
    config.role.name,
    config.serverHost,
    config.port,
    config.sharedSecret,
    config.syncProximityLocks,
    config.syncManualLocks,
  ].join('|');
}
