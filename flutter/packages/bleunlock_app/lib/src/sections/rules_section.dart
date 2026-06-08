import 'package:bleunlock_app/src/localization/zh_labels.dart';
import 'package:bleunlock_app/src/widgets/section_card.dart';
import 'package:bleunlock_core/bleunlock_core.dart';
import 'package:flutter/material.dart';

class RulesSection extends StatelessWidget {
  const RulesSection({
    required this.config,
    required this.canConfigureMacAutoUnlock,
    required this.macAutoUnlockStatusLabel,
    required this.onConfigChanged,
    required this.onMacAutoUnlockChanged,
    this.onResetRulesAndDevices,
    super.key,
  });

  final ProximityConfig config;
  final bool canConfigureMacAutoUnlock;
  final String macAutoUnlockStatusLabel;
  final ValueChanged<ProximityConfig> onConfigChanged;
  final ValueChanged<bool> onMacAutoUnlockChanged;
  final VoidCallback? onResetRulesAndDevices;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '规则',
      icon: Icons.tune,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _IntSliderRule(
            label: '靠近阈值',
            icon: Icons.sensors,
            value: config.unlockRssi,
            min: _unlockRssiMin,
            max: _unlockRssiMax,
            unit: 'dBm',
            onChanged: (value) {
              onConfigChanged(config.copyWith(unlockRssi: value));
            },
          ),
          _IntSliderRule(
            label: '远离阈值',
            icon: Icons.sensors_off,
            value: config.lockRssi,
            min: _lockRssiMin,
            max: _lockRssiMax,
            unit: 'dBm',
            onChanged: (value) {
              onConfigChanged(config.copyWith(lockRssi: value));
            },
          ),
          _IntSliderRule(
            label: '无信号超时',
            icon: Icons.timer_off,
            value: config.noSignalTimeout.inSeconds,
            min: 10,
            max: 180,
            divisions: 17,
            unit: 's',
            onChanged: (value) {
              onConfigChanged(
                config.copyWith(noSignalTimeout: Duration(seconds: value)),
              );
            },
          ),
          _IntSliderRule(
            label: '锁屏延迟',
            icon: Icons.lock_clock,
            value: config.lockDelay.inSeconds,
            min: 0,
            max: 30,
            unit: 's',
            onChanged: (value) {
              onConfigChanged(
                config.copyWith(lockDelay: Duration(seconds: value)),
              );
            },
          ),
          _IntSliderRule(
            label: '可见信号下限',
            icon: Icons.visibility,
            value: config.minimumVisibleRssi,
            min: -110,
            max: -50,
            unit: 'dBm',
            onChanged: (value) {
              onConfigChanged(config.copyWith(minimumVisibleRssi: value));
            },
          ),
          _IntSliderRule(
            label: 'RSSI 平滑窗口',
            icon: Icons.timeline,
            value: config.rssiWindowSize,
            min: 1,
            max: 10,
            unit: '',
            onChanged: (value) {
              onConfigChanged(config.copyWith(rssiWindowSize: value));
            },
          ),
          _SegmentedRule<UnlockDeviceLogic>(
            label: '靠近逻辑',
            icon: Icons.compare_arrows,
            selected: config.unlockDeviceLogic,
            segments: const {
              UnlockDeviceLogic.anyClose: '任一',
              UnlockDeviceLogic.allClose: '全部',
            },
            onChanged: (value) {
              onConfigChanged(config.copyWith(unlockDeviceLogic: value));
            },
          ),
          _SegmentedRule<LockDeviceLogic>(
            label: '远离逻辑',
            icon: Icons.call_split,
            selected: config.lockDeviceLogic,
            segments: const {
              LockDeviceLogic.allAway: '全部',
              LockDeviceLogic.anyAway: '任一',
            },
            onChanged: (value) {
              onConfigChanged(config.copyWith(lockDeviceLogic: value));
            },
          ),
          _SwitchRule(
            label: '靠近时唤醒',
            icon: Icons.wb_twilight,
            value: config.wakeOnProximity,
            onChanged: (value) {
              onConfigChanged(config.copyWith(wakeOnProximity: value));
            },
          ),
          _SwitchRule(
            label: 'macOS 自动解锁',
            icon: Icons.password,
            value: config.enableMacAutoUnlock,
            enabled: canConfigureMacAutoUnlock,
            statusLabel: _macAutoUnlockStatusLabel,
            onChanged: onMacAutoUnlockChanged,
          ),
          if (onResetRulesAndDevices != null)
            SizedBox(
              width: 300,
              child: OutlinedButton.icon(
                onPressed: onResetRulesAndDevices,
                icon: const Icon(Icons.restart_alt),
                label: const Text('重置规则和设备'),
              ),
            ),
        ],
      ),
    );
  }

  String? get _macAutoUnlockStatusLabel {
    if (macAutoUnlockStatusLabel == 'supported') {
      return null;
    }
    return macAutoUnlockStatusLabel;
  }
}

const int _unlockRssiMin = -90;
const int _unlockRssiMax = -30;
const int _lockRssiMin = -110;
const int _lockRssiMax = -40;

class _RuleSurface extends StatelessWidget {
  const _RuleSurface({
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
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _IntSliderRule extends StatelessWidget {
  const _IntSliderRule({
    required this.label,
    required this.icon,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final IconData icon;
  final int value;
  final int min;
  final int max;
  final String unit;
  final int? divisions;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final labelText = unit.isEmpty ? '$value' : '$value $unit';

    return _RuleSurface(
      label: label,
      icon: icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(labelText, style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: divisions ?? (max - min),
            label: labelText,
            onChanged: (nextValue) {
              final rounded = nextValue.round();
              if (rounded != value) {
                onChanged(rounded);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SegmentedRule<T> extends StatelessWidget {
  const _SegmentedRule({
    required this.label,
    required this.icon,
    required this.selected,
    required this.segments,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final T selected;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return _RuleSurface(
      label: label,
      icon: icon,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<T>(
          selected: {selected},
          segments: [
            for (final entry in segments.entries)
              ButtonSegment<T>(
                value: entry.key,
                label: Text(entry.value),
              ),
          ],
          onSelectionChanged: (values) {
            onChanged(values.single);
          },
        ),
      ),
    );
  }
}

class _SwitchRule extends StatelessWidget {
  const _SwitchRule({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.statusLabel,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    return _RuleSurface(
      label: label,
      icon: icon,
      child: Align(
        alignment: Alignment.centerLeft,
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
                  style: Theme.of(context).textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
