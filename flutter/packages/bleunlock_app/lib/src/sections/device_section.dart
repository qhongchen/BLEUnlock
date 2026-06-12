import 'package:bleunlock_app/src/localization/zh_labels.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_app/src/widgets/empty_state.dart';
import 'package:bleunlock_app/src/widgets/section_card.dart';
import 'package:flutter/material.dart';

class DeviceSection extends StatefulWidget {
  const DeviceSection({
    required this.devices,
    required this.isMonitoring,
    required this.onStartScanning,
    required this.onStartMonitoring,
    required this.onPauseScanning,
    required this.onDeviceSelectionChanged,
    super.key,
  });

  final List<DashboardDeviceView> devices;
  final bool isMonitoring;
  final VoidCallback onStartScanning;
  final VoidCallback onStartMonitoring;
  final VoidCallback onPauseScanning;
  final void Function(String deviceId, bool isSelected)
      onDeviceSelectionChanged;

  @override
  State<DeviceSection> createState() => _DeviceSectionState();
}

class _DeviceSectionState extends State<DeviceSection> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = _normalizeSearchText(value);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _handleSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final devices = widget.devices;
    final filteredDevices = _filteredDevices(devices, _searchQuery);
    return SectionCard(
      title: '设备',
      icon: Icons.bluetooth_searching,
      showHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (devices.isEmpty)
            const EmptyState(
              title: '暂无监听设备',
              message: '先开始扫描，选择一个或多个 BLE 设备，然后开启监听。',
            )
          else
            Column(
              children: [
                _DeviceSearchField(
                  controller: _searchController,
                  visibleCount: filteredDevices.length,
                  totalCount: devices.length,
                  onChanged: _handleSearchChanged,
                  onClear: _clearSearch,
                ),
                const SizedBox(height: 12),
                if (filteredDevices.isEmpty)
                  const EmptyState(
                    title: '没有匹配设备',
                    message: '换一个关键词，或清空搜索后查看全部设备。',
                  )
                else
                  _DeviceList(
                    devices: filteredDevices,
                    onDeviceSelectionChanged: widget.onDeviceSelectionChanged,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DeviceSearchField extends StatelessWidget {
  const _DeviceSearchField({
    required this.controller,
    required this.visibleCount,
    required this.totalCount,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final int visibleCount;
  final int totalCount;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasQuery = controller.text.trim().isNotEmpty;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$visibleCount/$totalCount',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasQuery)
              IconButton(
                tooltip: '清空搜索',
                icon: const Icon(Icons.close),
                onPressed: onClear,
              )
            else
              const SizedBox(width: 16),
          ],
        ),
        hintText: '搜索设备、ID、广播地址',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
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
                Text(zhDisplayText(device.rssiLabel),
                    style: textTheme.titleSmall),
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

List<DashboardDeviceView> _filteredDevices(
  List<DashboardDeviceView> devices,
  String query,
) {
  if (query.isEmpty) {
    return devices;
  }
  return [
    for (final device in devices)
      if (_deviceMatchesSearch(device, query)) device,
  ];
}

bool _deviceMatchesSearch(DashboardDeviceView device, String query) {
  final haystack = _normalizeSearchText([
    device.name,
    device.id,
    device.idLabel,
    zhDisplayText(device.rssiLabel),
    zhDisplayText(device.lastSeenLabel),
    zhDisplayText(device.presenceLabel),
  ].join(' '));
  if (haystack.contains(query)) {
    return true;
  }
  final compactQuery = _compactSearchText(query);
  if (compactQuery.isEmpty || compactQuery == query) {
    return false;
  }
  return _compactSearchText(haystack).contains(compactQuery);
}

String _normalizeSearchText(String value) {
  return value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _compactSearchText(String value) {
  return value.replaceAll(RegExp(r'[\s:._-]+'), '');
}

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-',
  ).hasMatch(value);
}
