import 'package:bleunlock_app/src/localization/zh_labels.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_app/src/widgets/metric_tile.dart';
import 'package:bleunlock_app/src/widgets/section_card.dart';
import 'package:flutter/material.dart';

class OverviewSection extends StatelessWidget {
  const OverviewSection({
    required this.snapshot,
    required this.isMonitoring,
    required this.canStartMonitoring,
    required this.onStartMonitoring,
    required this.onPauseMonitoring,
    required this.onLockNow,
    this.monitoringHint,
    super.key,
  });

  final DashboardSnapshot snapshot;
  final bool isMonitoring;
  final bool canStartMonitoring;
  final VoidCallback onStartMonitoring;
  final VoidCallback onPauseMonitoring;
  final VoidCallback onLockNow;
  final String? monitoringHint;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '总览',
      icon: Icons.dashboard_outlined,
      showHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MetricTile(
                  label: '状态', value: zhDisplayText(snapshot.stateLabel)),
              MetricTile(label: '最佳 RSSI', value: snapshot.bestRssiLabel),
              MetricTile(
                label: '已选设备',
                value: snapshot.selectedDevicesLabel,
              ),
              MetricTile(
                label: '最近动作',
                value: zhDisplayText(snapshot.lastActionLabel),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _OverviewActions(
            isMonitoring: isMonitoring,
            canStartMonitoring: canStartMonitoring,
            onStartMonitoring: onStartMonitoring,
            onPauseMonitoring: onPauseMonitoring,
            onLockNow: onLockNow,
          ),
          if (monitoringHint != null) ...[
            const SizedBox(height: 8),
            Text(
              zhDisplayText(monitoringHint!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewActions extends StatelessWidget {
  const _OverviewActions({
    required this.isMonitoring,
    required this.canStartMonitoring,
    required this.onStartMonitoring,
    required this.onPauseMonitoring,
    required this.onLockNow,
  });

  final bool isMonitoring;
  final bool canStartMonitoring;
  final VoidCallback onStartMonitoring;
  final VoidCallback onPauseMonitoring;
  final VoidCallback onLockNow;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        IconButton.filledTonal(
          onPressed: isMonitoring
              ? onPauseMonitoring
              : canStartMonitoring
                  ? onStartMonitoring
                  : null,
          icon: Icon(isMonitoring ? Icons.pause : Icons.play_arrow),
          tooltip: isMonitoring ? '暂停监听' : '开始监听',
        ),
        IconButton.outlined(
          onPressed: onLockNow,
          icon: const Icon(Icons.lock_outline),
          tooltip: '立即锁屏',
        ),
      ],
    );
  }
}
