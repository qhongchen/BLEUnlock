import 'package:bleunlock_app/src/localization/zh_labels.dart';
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
    super.key,
  });

  final DashboardSnapshot snapshot;
  final bool showMacAutoUnlockPassword;
  final Future<void> Function() onCapabilitiesRefreshed;
  final ValueChanged<bool> onStartupChanged;
  final Future<void> Function(String password) onMacAutoUnlockPasswordSaved;
  final Future<void> Function() onMacAutoUnlockPasswordCleared;
  final Future<void> Function() onMacAutoUnlockPermissionSettingsOpened;

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
        ],
      ),
    );
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
