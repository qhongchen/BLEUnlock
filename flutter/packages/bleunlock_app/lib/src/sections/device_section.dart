import 'package:bleunlock_app/src/localization/zh_labels.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_app/src/widgets/empty_state.dart';
import 'package:bleunlock_app/src/widgets/primary_action_row.dart';
import 'package:bleunlock_app/src/widgets/section_card.dart';
import 'package:flutter/material.dart';

class DeviceSection extends StatelessWidget {
  const DeviceSection({
    required this.devices,
    required this.isMonitoring,
    required this.onStartScanning,
    required this.onStartMonitoring,
    required this.onPauseScanning,
    required this.onLockNow,
    required this.onRefreshDevices,
    required this.onDeviceSelectionChanged,
    super.key,
  });

  final List<DashboardDeviceView> devices;
  final bool isMonitoring;
  final VoidCallback onStartScanning;
  final VoidCallback onStartMonitoring;
  final VoidCallback onPauseScanning;
  final VoidCallback onLockNow;
  final VoidCallback onRefreshDevices;
  final void Function(String deviceId, bool isSelected)
      onDeviceSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final hasSelectedDevice = devices.any((device) => device.isSelected);
    return SectionCard(
      title: '设备',
      icon: Icons.bluetooth_searching,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (devices.isEmpty)
            const EmptyState(
              title: '暂无监听设备',
              message: '先开始扫描，选择一个或多个 BLE 设备，然后开启监听。',
            )
          else
            _DeviceList(
              devices: devices,
              onDeviceSelectionChanged: onDeviceSelectionChanged,
            ),
          const SizedBox(height: 12),
          PrimaryActionRow(
            isMonitoring: isMonitoring,
            onStartScanning: onStartScanning,
            onStartMonitoring: onStartMonitoring,
            onPauseScanning: onPauseScanning,
            onLockNow: onLockNow,
            onRefreshDevices: onRefreshDevices,
            canStartMonitoring: hasSelectedDevice,
            monitoringHint:
                !isMonitoring && devices.isNotEmpty && !hasSelectedDevice
                    ? '请先选择一个或多个设备，再开始监听。'
                    : null,
          ),
        ],
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.devices,
    required this.onDeviceSelectionChanged,
  });

  final List<DashboardDeviceView> devices;
  final void Function(String deviceId, bool isSelected)
      onDeviceSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final columnCount = _deviceGridColumnCount(constraints.maxWidth);
          final itemWidth =
              (constraints.maxWidth - spacing * (columnCount - 1)) /
                  columnCount;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final device in devices)
                SizedBox(
                  width: itemWidth,
                  child: _DeviceTile(
                    device: device,
                    onDeviceSelectionChanged: onDeviceSelectionChanged,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.onDeviceSelectionChanged,
  });

  final DashboardDeviceView device;
  final void Function(String deviceId, bool isSelected)
      onDeviceSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final borderColor =
        device.isSelected ? colorScheme.primary : Colors.transparent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Checkbox(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              value: device.isSelected,
              onChanged: (value) {
                onDeviceSelectionChanged(device.id, value ?? false);
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Tooltip(
                message:
                    '${device.idLabel} · ${zhDisplayText(device.lastSeenLabel)}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _deviceLineLabel(device),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      zhDisplayText(device.lastSeenLabel),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(device.rssiLabel, style: textTheme.titleSmall),
                const SizedBox(height: 4),
                Tooltip(
                  message: zhDisplayText(device.presenceLabel),
                  child: Icon(
                    Icons.sensors,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

int _deviceGridColumnCount(double width) {
  if (width >= 960) {
    return 3;
  }
  if (width >= 620) {
    return 2;
  }
  return 1;
}

String _deviceLineLabel(DashboardDeviceView device) {
  if (_looksLikeUuid(device.name)) {
    return device.name;
  }
  return '${device.name} · ${device.idLabel}';
}

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-',
  ).hasMatch(value);
}
