import 'package:bleunlock_app/src/localization/zh_labels.dart';
import 'package:bleunlock_app/src/lock_sync/lock_sync_models.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_app/src/widgets/capability_row.dart';
import 'package:bleunlock_app/src/widgets/section_card.dart';
import 'package:flutter/material.dart';

class SystemSection extends StatelessWidget {
  const SystemSection({
    required this.snapshot,
    required this.showMacAutoUnlockPassword,
    required this.onCapabilitiesRefreshed,
    required this.onStartupChanged,
    required this.onMacAutoUnlockPasswordSaved,
    required this.onMacAutoUnlockPasswordCleared,
    required this.onMacAutoUnlockPermissionSettingsOpened,
    this.lockSync = const LockSyncSnapshot.initial(),
    this.onLockSyncConfigChanged,
    this.onLockSyncSharedSecretGenerated,
    this.onLockSyncRestarted,
    this.showLockSyncSettings = false,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final LockSyncSnapshot lockSync;
  final bool showMacAutoUnlockPassword;
  final Future<void> Function() onCapabilitiesRefreshed;
  final ValueChanged<bool> onStartupChanged;
  final Future<void> Function(String password) onMacAutoUnlockPasswordSaved;
  final Future<void> Function() onMacAutoUnlockPasswordCleared;
  final Future<void> Function() onMacAutoUnlockPermissionSettingsOpened;
  final Future<void> Function(LockSyncConfig config)? onLockSyncConfigChanged;
  final Future<void> Function()? onLockSyncSharedSecretGenerated;
  final Future<void> Function()? onLockSyncRestarted;
  final bool showLockSyncSettings;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '系统',
      icon: Icons.computer,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onCapabilitiesRefreshed,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新能力'),
            ),
          ),
          const SizedBox(height: 8),
          CapabilityRow(
            label: '平台',
            value: snapshot.platformLabel,
          ),
          CapabilityRow(
            label: '蓝牙扫描',
            value: snapshot.bluetoothCapabilityLabel,
          ),
          CapabilityRow(
            label: '自动锁屏',
            value: snapshot.autoLockCapabilityLabel,
          ),
          CapabilityRow(
            label: '靠近唤醒',
            value: snapshot.wakeCapabilityLabel,
          ),
          CapabilityRow(
            label: '自动解锁',
            value: snapshot.autoUnlockCapabilityLabel,
          ),
          if (snapshot.windowsV1ReadinessLabel != null)
            _WindowsV1ReadinessRow(label: snapshot.windowsV1ReadinessLabel!),
          if (snapshot.autoUnlockPermissionSettingsAvailable)
            _AutoUnlockPermissionRow(
              onOpened: onMacAutoUnlockPermissionSettingsOpened,
            ),
          if (showMacAutoUnlockPassword && snapshot.autoUnlockSecretEditable)
            _AutoUnlockPasswordRow(
              canEdit: snapshot.autoUnlockSecretEditable,
              secretLabel: snapshot.autoUnlockSecretLabel,
              isConfigured: snapshot.autoUnlockSecretConfigured,
              onSaved: onMacAutoUnlockPasswordSaved,
              onCleared: onMacAutoUnlockPasswordCleared,
            ),
          CapabilityRow(
            label: '托盘/菜单栏',
            value: snapshot.trayCapabilityLabel,
          ),
          _StartupRow(
            isEnabled: snapshot.startupEnabled,
            capabilityLabel: snapshot.startupCapabilityLabel,
            onChanged: onStartupChanged,
          ),
          if (showLockSyncSettings) ...[
            const Divider(height: 32),
            _LockSyncRow(
              snapshot: lockSync,
              onConfigChanged: onLockSyncConfigChanged ?? _ignoreLockSyncConfig,
              onSharedSecretGenerated:
                  onLockSyncSharedSecretGenerated ?? _noopFuture,
              onRestarted: onLockSyncRestarted ?? _noopFuture,
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _ignoreLockSyncConfig(LockSyncConfig config) async {}

Future<void> _noopFuture() async {}

class _LockSyncRow extends StatefulWidget {
  const _LockSyncRow({
    required this.snapshot,
    required this.onConfigChanged,
    required this.onSharedSecretGenerated,
    required this.onRestarted,
  });

  final LockSyncSnapshot snapshot;
  final Future<void> Function(LockSyncConfig config) onConfigChanged;
  final Future<void> Function() onSharedSecretGenerated;
  final Future<void> Function() onRestarted;

  @override
  State<_LockSyncRow> createState() => _LockSyncRowState();
}

class _LockSyncRowState extends State<_LockSyncRow> {
  late LockSyncRole _role;
  late bool _syncProximityLocks;
  late bool _syncManualLocks;
  late final TextEditingController _serverHostController;
  late final TextEditingController _portController;
  late final TextEditingController _sharedSecretController;

  @override
  void initState() {
    super.initState();
    final config = widget.snapshot.config;
    _role = config.role;
    _syncProximityLocks = config.syncProximityLocks;
    _syncManualLocks = config.syncManualLocks;
    _serverHostController = TextEditingController(text: config.serverHost);
    _portController = TextEditingController(text: config.port.toString());
    _sharedSecretController = TextEditingController(text: config.sharedSecret);
  }

  @override
  void didUpdateWidget(covariant _LockSyncRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = oldWidget.snapshot.config;
    final current = widget.snapshot.config;
    if (previous == current) {
      return;
    }
    _role = current.role;
    _syncProximityLocks = current.syncProximityLocks;
    _syncManualLocks = current.syncManualLocks;
    _serverHostController.text = current.serverHost;
    _portController.text = current.port.toString();
    _sharedSecretController.text = current.sharedSecret;
  }

  @override
  void dispose() {
    _serverHostController.dispose();
    _portController.dispose();
    _sharedSecretController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = widget.snapshot.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '主从锁屏同步',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        CapabilityRow(
          label: '角色',
          value: zhDisplayText(widget.snapshot.roleLabel),
        ),
        CapabilityRow(
          label: '同步状态',
          value: zhDisplayText(widget.snapshot.statusLabel),
        ),
        CapabilityRow(
          label: '同步端点',
          value: widget.snapshot.endpointLabel,
        ),
        if (config.role == LockSyncRole.server)
          CapabilityRow(
            label: '已连接客户端',
            value: widget.snapshot.connectedClientCount.toString(),
          ),
        if (widget.snapshot.lastEventLabel != null)
          CapabilityRow(
            label: '最近事件',
            value: widget.snapshot.lastEventLabel!,
          ),
        if (widget.snapshot.lastError != null)
          CapabilityRow(
            label: '最近错误',
            value: widget.snapshot.lastError!,
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<LockSyncRole>(
          value: _role,
          decoration: const InputDecoration(
            isDense: true,
            labelText: '角色',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: LockSyncRole.disabled,
              child: Text('关闭'),
            ),
            DropdownMenuItem(
              value: LockSyncRole.server,
              child: Text('Server'),
            ),
            DropdownMenuItem(
              value: LockSyncRole.client,
              child: Text('Client'),
            ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            setState(() {
              _role = value;
            });
          },
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final serverHostField = TextField(
              controller: _serverHostController,
              enabled: _role == LockSyncRole.client,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Server 地址',
                prefixIcon: Icon(Icons.dns_outlined),
                border: OutlineInputBorder(),
              ),
            );
            final portField = TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                labelText: '端口',
                prefixIcon: Icon(Icons.settings_ethernet),
                border: OutlineInputBorder(),
              ),
            );
            if (constraints.maxWidth < 560) {
              return Column(
                children: [
                  serverHostField,
                  const SizedBox(height: 8),
                  portField,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: serverHostField),
                const SizedBox(width: 8),
                SizedBox(width: 160, child: portField),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sharedSecretController,
          decoration: const InputDecoration(
            isDense: true,
            labelText: '共享密钥',
            prefixIcon: Icon(Icons.key_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('同步 BLEUnlock 自动锁屏'),
          subtitle: const Text('macOS 因距离规则锁屏后，通知 client 同步锁屏'),
          value: _syncProximityLocks,
          onChanged: (value) {
            setState(() {
              _syncProximityLocks = value;
            });
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('同步手动锁屏'),
          subtitle: const Text('点击立即锁屏时也通知 client，默认建议关闭'),
          value: _syncManualLocks,
          onChanged: (value) {
            setState(() {
              _syncManualLocks = value;
            });
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: widget.onSharedSecretGenerated,
              icon: const Icon(Icons.password),
              label: const Text('生成密钥'),
            ),
            OutlinedButton.icon(
              onPressed: widget.onRestarted,
              icon: const Icon(Icons.restart_alt),
              label: const Text('重启同步'),
            ),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('保存同步设置'),
            ),
          ],
        ),
      ],
    );
  }

  void _save() {
    final parsedPort = int.tryParse(_portController.text.trim());
    final config = LockSyncConfig(
      role: _role,
      serverHost: _serverHostController.text.trim(),
      port: parsedPort ?? LockSyncConfig.defaultPort,
      sharedSecret: _sharedSecretController.text.trim(),
      syncProximityLocks: _syncProximityLocks,
      syncManualLocks: _syncManualLocks,
    );
    widget.onConfigChanged(config);
  }
}

class _WindowsV1ReadinessRow extends StatelessWidget {
  const _WindowsV1ReadinessRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              zhDisplayText(label),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoUnlockPermissionRow extends StatelessWidget {
  const _AutoUnlockPermissionRow({required this.onOpened});

  final Future<void> Function() onOpened;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: OutlinedButton.icon(
          onPressed: onOpened,
          icon: const Icon(Icons.settings_accessibility),
          label: const Text('打开辅助功能设置'),
        ),
      ),
    );
  }
}

class _AutoUnlockPasswordRow extends StatefulWidget {
  const _AutoUnlockPasswordRow({
    required this.canEdit,
    required this.secretLabel,
    required this.isConfigured,
    required this.onSaved,
    required this.onCleared,
  });

  final bool canEdit;
  final String secretLabel;
  final bool isConfigured;
  final Future<void> Function(String password) onSaved;
  final Future<void> Function() onCleared;

  @override
  State<_AutoUnlockPasswordRow> createState() => _AutoUnlockPasswordRowState();
}

class _AutoUnlockPasswordRowState extends State<_AutoUnlockPasswordRow> {
  final TextEditingController _controller = TextEditingController();
  bool _hasInput = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleInputChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleInputChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('macOS 解锁密码')),
              Text(
                zhDisplayText(widget.secretLabel),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final input = TextField(
                controller: _controller,
                enabled: widget.canEdit,
                obscureText: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: '密码',
                  prefixIcon: Icon(Icons.key),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: widget.canEdit && _hasInput ? _save : null,
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: widget.canEdit && _hasInput
                        ? () => _save(_controller.text)
                        : null,
                    icon: const Icon(Icons.save),
                    label: const Text('保存'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed:
                        widget.canEdit && widget.isConfigured ? _clear : null,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: '清除密码',
                  ),
                ],
              );

              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: actions,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: input),
                  const SizedBox(width: 8),
                  actions,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _handleInputChanged() {
    final hasInput = _controller.text.isNotEmpty;
    if (hasInput == _hasInput) {
      return;
    }
    setState(() {
      _hasInput = hasInput;
    });
  }

  Future<void> _save(String password) async {
    if (password.isEmpty) {
      return;
    }
    await widget.onSaved(password);
    _controller.clear();
  }

  Future<void> _clear() async {
    await widget.onCleared();
    _controller.clear();
  }
}

class _StartupRow extends StatelessWidget {
  const _StartupRow({
    required this.isEnabled,
    required this.capabilityLabel,
    required this.onChanged,
  });

  final bool isEnabled;
  final String capabilityLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isSupported = capabilityLabel == 'supported';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Text('开机启动')),
          Text(
            isEnabled ? '已开启' : '已关闭',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(width: 12),
          Switch(
            value: isEnabled,
            onChanged: isSupported ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
