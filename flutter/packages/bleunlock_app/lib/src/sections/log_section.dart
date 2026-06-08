import 'dart:io';

import 'package:bleunlock_app/src/localization/zh_labels.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_app/src/widgets/empty_state.dart';
import 'package:bleunlock_app/src/widgets/section_card.dart';
import 'package:bleunlock_app/src/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogSection extends StatefulWidget {
  const LogSection({
    required this.logs,
    this.state,
    this.exportDirectory,
    super.key,
  });

  final List<DashboardLogEntry> logs;
  final DashboardState? state;
  final Directory? exportDirectory;

  @override
  State<LogSection> createState() => _LogSectionState();
}

class _LogSectionState extends State<LogSection> {
  DashboardLogCategory? _category;
  DashboardLogLevel? _level;
  DashboardSessionState? _sessionState;
  bool _showDetailedDiagnostics = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filter = DashboardLogFilter(
      category: _category,
      level: _level,
      sessionState: _sessionState,
      includeLowValueDiagnostics: _showDetailedDiagnostics,
      query: _query,
    );
    final visibleLogs = filter.apply(widget.logs);
    final sessionDiagnostics = DashboardSessionDiagnostic.fromLogs(visibleLogs);
    final deviceDiagnostics = DashboardDeviceDiagnostic.fromLogs(visibleLogs);
    final diagnosticLogJsonLines =
        visibleLogs.map(_diagnosticJsonLine).join('\n');
    final sessionDiagnosticJsonLines =
        sessionDiagnostics.map((entry) => entry.diagnosticJsonLine).join('\n');

    return SectionCard(
      title: '日志',
      icon: Icons.article_outlined,
      showHeader: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '显示 ${visibleLogs.length} / ${widget.logs.length} 条',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              OutlinedButton.icon(
                onPressed: sessionDiagnosticJsonLines.isEmpty
                    ? null
                    : () => _copyText(
                          context,
                          sessionDiagnosticJsonLines,
                          '会话摘要已复制',
                        ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('复制会话摘要'),
              ),
              OutlinedButton.icon(
                onPressed: diagnosticLogJsonLines.isEmpty
                    ? null
                    : () => _copyText(
                          context,
                          diagnosticLogJsonLines,
                          '诊断日志已复制',
                        ),
                icon: const Icon(Icons.copy_all),
                label: const Text('复制诊断日志'),
              ),
              OutlinedButton.icon(
                onPressed: diagnosticLogJsonLines.isEmpty
                    ? null
                    : () => _exportDiagnostics(
                          context,
                          diagnosticLogJsonLines,
                        ),
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('导出诊断日志'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _LogFilters(
            category: _category,
            level: _level,
            sessionState: _sessionState,
            showDetailedDiagnostics: _showDetailedDiagnostics,
            onCategoryChanged: (category) {
              setState(() => _category = category);
            },
            onLevelChanged: (level) {
              setState(() => _level = level);
            },
            onSessionStateChanged: (sessionState) {
              setState(() => _sessionState = sessionState);
            },
            onDetailedDiagnosticsChanged: (value) {
              setState(() => _showDetailedDiagnostics = value);
            },
            onQueryChanged: (query) {
              setState(() => _query = query);
            },
          ),
          const SizedBox(height: 12),
          _SessionDiagnosticsSummary(diagnostics: sessionDiagnostics),
          if (sessionDiagnostics.isNotEmpty) const SizedBox(height: 12),
          _DeviceDiagnosticsSummary(diagnostics: deviceDiagnostics),
          if (deviceDiagnostics.isNotEmpty) const SizedBox(height: 12),
          if (widget.logs.isEmpty)
            const EmptyState(
              title: '暂无事件',
              message: '扫描、判定、动作和错误事件会显示在这里。',
            )
          else if (visibleLogs.isEmpty)
            const EmptyState(
              title: '没有匹配日志',
              message: '调整筛选条件以查看更多事件。',
            )
          else
            for (final entry in visibleLogs.take(20))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(
                        entry.timeLabel,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    StatusPill(
                      label: zhDisplayText(entry.category.label),
                      icon: Icons.label_outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(zhDisplayText(entry.message)),
                          const SizedBox(height: 2),
                          Text(
                            zhDetailLabel(entry.detailLabel),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _exportDiagnostics(BuildContext context, String text) async {
    final file = await _writeJsonLines(
      widget.exportDirectory ?? _defaultExportDirectory,
      _diagnosticExportPrefix,
      text,
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('诊断日志已导出：${file.path}')),
    );
  }

  Future<void> _copyText(
    BuildContext context,
    String text,
    String message,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String get _diagnosticExportPrefix => 'bleunlock-diagnostics';

  String _diagnosticJsonLine(DashboardLogEntry entry) =>
      entry.diagnosticJsonLine;
}

final Directory _defaultExportDirectory = Directory(
  '${Directory.systemTemp.path}/BLEUnlock/diagnostics',
);

Future<File> _writeJsonLines(
  Directory directory,
  String prefix,
  String text,
) async {
  directory.createSync(recursive: true);
  final timestamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  final file = File('${directory.path}/$prefix-$timestamp.jsonl');
  file.writeAsStringSync('$text\n', flush: true);
  return file;
}

class _SessionDiagnosticsSummary extends StatelessWidget {
  const _SessionDiagnosticsSummary({required this.diagnostics});

  final List<DashboardSessionDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context) {
    if (diagnostics.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('会话诊断', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final diagnostic in diagnostics)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zhDisplayText(diagnostic.sessionLabel),
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${zhDisplayText(diagnostic.logCountLabel)} · '
                        '${zhDisplayText(diagnostic.scanCountLabel)} · '
                        '${zhDisplayText(diagnostic.latestEventLabel)}',
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${zhDisplayText(diagnostic.latestScanLabel)} · '
                        '${zhDisplayText(diagnostic.latestScanDeviceLabel)}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: diagnostic.scanEvidenceLabel,
                  icon: diagnostic.scanCount == 0
                      ? Icons.visibility_off_outlined
                      : Icons.bluetooth_searching,
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: diagnostic.latestScanRssiLabel,
                  icon: Icons.show_chart,
                ),
              ],
            ),
          ),
        const Divider(height: 16),
      ],
    );
  }
}

class _DeviceDiagnosticsSummary extends StatelessWidget {
  const _DeviceDiagnosticsSummary({required this.diagnostics});

  final List<DashboardDeviceDiagnostic> diagnostics;

  @override
  Widget build(BuildContext context) {
    if (diagnostics.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('设备诊断', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final diagnostic in diagnostics.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diagnostic.displayNameLabel,
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID ${_shortDeviceId(diagnostic.deviceId)} · '
                        '${zhDisplayText(diagnostic.lastSeenLabel)} · '
                        '出现 ${diagnostic.seenCount} 次',
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '地址=${zhDisplayText(diagnostic.addressHintLabel)} · '
                        '厂商数据=${zhDisplayText(diagnostic.manufacturerDataHexLabel)}',
                        style: textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${zhDisplayText(diagnostic.averageIntervalLabel)} · '
                        '${zhDisplayText(diagnostic.longestSilenceLabel)}',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: zhDisplayText(diagnostic.averageRssiLabel),
                  icon: Icons.show_chart,
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: zhDisplayText(diagnostic.rssiRangeLabel),
                  icon: Icons.speed,
                ),
                const SizedBox(width: 8),
                StatusPill(
                  label: zhDisplayText(diagnostic.identityStatusLabel),
                  icon: diagnostic.identityStatus == DeviceIdentityStatus.stable
                      ? Icons.verified
                      : Icons.warning_amber,
                ),
              ],
            ),
          ),
        const Divider(height: 16),
      ],
    );
  }
}

class _LogFilters extends StatelessWidget {
  const _LogFilters({
    required this.category,
    required this.level,
    required this.sessionState,
    required this.showDetailedDiagnostics,
    required this.onCategoryChanged,
    required this.onLevelChanged,
    required this.onSessionStateChanged,
    required this.onDetailedDiagnosticsChanged,
    required this.onQueryChanged,
  });

  final DashboardLogCategory? category;
  final DashboardLogLevel? level;
  final DashboardSessionState? sessionState;
  final bool showDetailedDiagnostics;
  final ValueChanged<DashboardLogCategory?> onCategoryChanged;
  final ValueChanged<DashboardLogLevel?> onLevelChanged;
  final ValueChanged<DashboardSessionState?> onSessionStateChanged;
  final ValueChanged<bool> onDetailedDiagnosticsChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilterChip(
          label: const Text('全部'),
          selected: category == null,
          onSelected: (_) => onCategoryChanged(null),
        ),
        for (final value in DashboardLogCategory.values)
          FilterChip(
            label: Text(value.label),
            selected: category == value,
            onSelected: (_) => onCategoryChanged(value),
          ),
        FilterChip(
          avatar: const Icon(Icons.bug_report_outlined, size: 18),
          label: const Text('详细诊断'),
          selected: showDetailedDiagnostics,
          onSelected: onDetailedDiagnosticsChanged,
        ),
        SizedBox(
          width: 168,
          child: DropdownButtonFormField<DashboardLogLevel?>(
            isExpanded: true,
            value: level,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: '级别',
            ),
            items: [
              const DropdownMenuItem<DashboardLogLevel?>(
                value: null,
                child: Text('全部级别'),
              ),
              for (final value in DashboardLogLevel.values)
                DropdownMenuItem<DashboardLogLevel?>(
                  value: value,
                  child: Text(zhDisplayText(value.label)),
                ),
            ],
            onChanged: onLevelChanged,
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<DashboardSessionState?>(
            isExpanded: true,
            value: sessionState,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: '会话',
            ),
            items: [
              const DropdownMenuItem<DashboardSessionState?>(
                value: null,
                child: Text('全部会话'),
              ),
              for (final value in DashboardSessionState.values)
                DropdownMenuItem<DashboardSessionState?>(
                  value: value,
                  child: Text(zhDisplayText(value.label)),
                ),
            ],
            onChanged: onSessionStateChanged,
          ),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              labelText: '搜索日志',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: onQueryChanged,
          ),
        ),
      ],
    );
  }
}

String _shortDeviceId(String deviceId) {
  if (deviceId.length <= 12) {
    return deviceId;
  }
  return '${deviceId.substring(0, 8)}...'
      '${deviceId.substring(deviceId.length - 4)}';
}
