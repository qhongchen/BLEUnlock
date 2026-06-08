import 'package:bleunlock_app/src/localization/zh_labels.dart';
import 'package:bleunlock_app/src/lock_sync/lock_sync_models.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_app/src/widgets/capability_row.dart';
import 'package:bleunlock_app/src/widgets/section_card.dart';
import 'package:flutter/material.dart';

class SystemSection extends StatelessWidget {
  const SystemSection({
    required this.snapshot,
    required this.wakeOnProximity,
    required this.macAutoUnlockEnabled,
    required this.canConfigureMacAutoUnlock,
    required this.macAutoUnlockStatusLabel,
    required this.onCapabilitiesRefreshed,
    required this.onStartupChanged,
    required this.onWakeOnProximityChanged,
    required this.onMacAutoUnlockChanged,
    this.lockSync = const LockSyncSnapshot.initial(),
    this.onLockSyncConfigChanged,
    this.onLockSyncSharedSecretGenerated,
    this.onLockSyncRestarted,
    this.showLockSyncSettings = false,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final LockSyncSnapshot lockSync;
  final bool wakeOnProximity;
  final bool macAutoUnlockEnabled;
  final bool canConfigureMacAutoUnlock;
  final String macAutoUnlockStatusLabel;
  final Future<void> Function() onCapabilitiesRefreshed;
  final ValueChanged<bool> onStartupChanged;
  final ValueChanged<bool> onWakeOnProximityChanged;
  final ValueChanged<bool> onMacAutoUnlockChanged;
  final Future<void> Function(LockSyncConfig config)? onLockSyncConfigChanged;
  final Future<void> Function()? onLockSyncSharedSecretGenerated;
  final Future<void> Function()? onLockSyncRestarted;
  final bool showLockSyncSettings;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '系统',
      icon: Icons.computer,
      showHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SystemActionTile(
                label: '能力刷新',
                icon: Icons.refresh,
                buttonLabel: '刷新能力',
                onPressed: onCapabilitiesRefreshed,
              ),
              _SystemSwitchTile(
                label: '靠近时唤醒',
                icon: Icons.wb_twilight,
                value: wakeOnProximity,
                enabled: _isSupportedCapability(snapshot.wakeCapabilityLabel),
                statusLabel: snapshot.wakeCapabilityLabel,
                onChanged: onWakeOnProximityChanged,
              ),
              _SystemSwitchTile(
                label: 'macOS 自动解锁',
                icon: Icons.password,
                value: macAutoUnlockEnabled,
                enabled: canConfigureMacAutoUnlock,
                statusLabel: _macAutoUnlockStatusLabel,
                onChanged: onMacAutoUnlockChanged,
              ),
              _SystemSwitchTile(
                label: '开机启动',
                icon: Icons.power_settings_new,
                value: snapshot.startupEnabled,
                enabled:
                    _isSupportedCapability(snapshot.startupCapabilityLabel),
                statusLabel: snapshot.startupEnabled ? 'enabled' : 'disabled',
                onChanged: onStartupChanged,
              ),
            ],
          ),
          if (showLockSyncSettings) ...[
            const SizedBox(height: 20),
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

  String? get _macAutoUnlockStatusLabel {
    if (macAutoUnlockStatusLabel == 'supported') {
      return snapshot.autoUnlockSecretConfigured ? 'configured' : null;
    }
    return macAutoUnlockStatusLabel;
  }
}

Future<void> _ignoreLockSyncConfig(LockSyncConfig config) async {}

Future<void> _noopFuture() async {}

bool _isSupportedCapability(String label) => label == 'supported';

class _SystemSurface extends StatelessWidget {
  const _SystemSurface({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemActionTile extends StatelessWidget {
  const _SystemActionTile({
    required this.label,
    required this.icon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final String buttonLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return _SystemSurface(
      label: label,
      icon: icon,
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(buttonLabel),
        ),
      ),
    );
  }
}

class _SystemSwitchTile extends StatelessWidget {
  const _SystemSwitchTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.statusLabel,
  });

  final String label;
  final IconData icon;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    return _SystemSurface(
      label: label,
      icon: icon,
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
          if (statusLabel != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                zhDisplayText(statusLabel!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
