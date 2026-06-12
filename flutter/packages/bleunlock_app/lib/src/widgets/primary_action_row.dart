import 'package:flutter/material.dart';

class PrimaryActionRow extends StatelessWidget {
  const PrimaryActionRow({
    required this.isScanning,
    required this.isMonitoring,
    required this.onStartScanning,
    required this.onStartMonitoring,
    required this.onPauseScanning,
    required this.canStartMonitoring,
    this.monitoringHint,
    super.key,
  });

  final bool isScanning;
  final bool isMonitoring;
  final VoidCallback onStartScanning;
  final VoidCallback onStartMonitoring;
  final VoidCallback onPauseScanning;
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
            _buildScanButton(),
            _buildMonitoringButton(),
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

  Widget _buildScanButton() {
    if (isMonitoring) {
      return FilledButton.tonalIcon(
        onPressed: null,
        icon: const Icon(Icons.radar),
        label: const Text('扫描中'),
      );
    }
    return FilledButton.icon(
      onPressed: isScanning ? onPauseScanning : onStartScanning,
      icon: Icon(
        isScanning ? Icons.stop_circle_outlined : Icons.radar,
      ),
      label: Text(isScanning ? '停止扫描' : '开始扫描'),
    );
  }

  Widget _buildMonitoringButton() {
    if (isMonitoring) {
      return FilledButton.icon(
        onPressed: onPauseScanning,
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('停止监听'),
      );
    }
    return FilledButton.tonalIcon(
      onPressed: canStartMonitoring ? onStartMonitoring : null,
      icon: const Icon(Icons.play_arrow),
      label: const Text('开始监听'),
    );
  }
}
