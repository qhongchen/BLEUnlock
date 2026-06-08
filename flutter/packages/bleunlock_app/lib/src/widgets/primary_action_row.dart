import 'package:flutter/material.dart';

class PrimaryActionRow extends StatelessWidget {
  const PrimaryActionRow({
    required this.isMonitoring,
    required this.onStartScanning,
    required this.onStartMonitoring,
    required this.onPauseScanning,
    required this.onRefreshDevices,
    required this.canStartMonitoring,
    this.monitoringHint,
    super.key,
  });

  final bool isMonitoring;
  final VoidCallback onStartScanning;
  final VoidCallback onStartMonitoring;
  final VoidCallback onPauseScanning;
  final VoidCallback onRefreshDevices;
  final bool canStartMonitoring;
  final String? monitoringHint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: isMonitoring ? onPauseScanning : onStartScanning,
              icon:
                  Icon(isMonitoring ? Icons.stop_circle_outlined : Icons.radar),
              label: Text(isMonitoring ? '停止监听' : '开始扫描'),
            ),
            FilledButton.tonalIcon(
              onPressed: isMonitoring || !canStartMonitoring
                  ? null
                  : onStartMonitoring,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始监听'),
            ),
            OutlinedButton.icon(
              onPressed: onRefreshDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新设备'),
            ),
          ],
        ),
        if (monitoringHint != null) ...[
          const SizedBox(height: 8),
          Text(
            monitoringHint!,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
