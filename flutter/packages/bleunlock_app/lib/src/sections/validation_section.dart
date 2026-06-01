import 'dart:convert';
import 'dart:io';

import 'package:bleunlock_app/src/localization/zh_labels.dart';
import 'package:bleunlock_app/src/validation/validation_evidence_export.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';
import 'package:bleunlock_app/src/widgets/section_card.dart';
import 'package:bleunlock_app/src/widgets/status_pill.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ValidationSection extends StatefulWidget {
  ValidationSection({
    required this.state,
    this.exportDirectory,
    String? validationSessionId,
    super.key,
  }) : validationSessionId =
            validationSessionId ?? _createValidationSessionId();

  final DashboardState state;
  final Directory? exportDirectory;
  final String validationSessionId;

  @override
  State<ValidationSection> createState() => _ValidationSectionState();
}

class _ValidationSectionState extends State<ValidationSection> {
  final Map<String, ExternalValidationGateStatus> _externalGateStatuses =
      defaultExternalValidationGates.defaultStatuses();
  final Map<String, ExternalValidationGateRecord> _externalGateRecords = {
    for (final gate in defaultExternalValidationGates.gates)
      gate.id: ExternalValidationGateRecord(status: gate.defaultStatus),
  };

  @override
  Widget build(BuildContext context) {
    final summary = AcceptanceSummary.fromState(
      state: widget.state,
      visibleLogs: widget.state.logs,
    );
    final checklistJsonLines =
        summary.sessionChecklistJsonLines(widget.validationSessionId);
    final runbookJsonLines = summary.sessionRunbookJsonLines(
      widget.validationSessionId,
    );
    final missingActionList = summary.missingActionList;
    final activeExportDirectory =
        widget.exportDirectory ?? _defaultExportDirectory;
    final activeGateSet = _activeExternalValidationGates;
    final latestGateIndexEntries = latestExternalValidationGateIndexEntries(
      directory: activeExportDirectory,
      validationSessionId: widget.validationSessionId,
    );

    return SectionCard(
      title: '验收',
      icon: Icons.verified_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '从全部运行日志生成验收证据',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              StatusPill(
                label: '会话 ${widget.validationSessionId}',
                icon: Icons.fingerprint,
              ),
              _ExportPathLabel(path: activeExportDirectory.path),
              OutlinedButton.icon(
                onPressed: () => _copyText(
                  context,
                  widget.validationSessionId,
                  '验证 ID 已复制',
                ),
                icon: const Icon(Icons.copy_outlined),
                label: const Text('复制验证 ID'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyText(
                  context,
                  activeExportDirectory.path,
                  '导出路径已复制',
                ),
                icon: const Icon(Icons.folder_copy_outlined),
                label: const Text('复制导出路径'),
              ),
              OutlinedButton.icon(
                onPressed: checklistJsonLines.isEmpty
                    ? null
                    : () => _copyText(
                          context,
                          checklistJsonLines,
                          '验收清单已复制',
                        ),
                icon: const Icon(Icons.checklist_outlined),
                label: const Text('复制验收清单'),
              ),
              OutlinedButton.icon(
                onPressed: runbookJsonLines.isEmpty
                    ? null
                    : () => _copyText(
                          context,
                          runbookJsonLines,
                          '验收手册已复制',
                        ),
                icon: const Icon(Icons.route_outlined),
                label: const Text('复制验收手册'),
              ),
              OutlinedButton.icon(
                onPressed: missingActionList.isEmpty
                    ? null
                    : () => _copyText(
                          context,
                          missingActionList,
                          '缺失动作已复制',
                        ),
                icon: const Icon(Icons.format_list_numbered_outlined),
                label: const Text('复制缺失动作'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copyText(
                  context,
                  _externalGateJsonLines,
                  '外部门禁已复制',
                ),
                icon: const Icon(Icons.rule_folder_outlined),
                label: const Text('复制外部门禁'),
              ),
              OutlinedButton.icon(
                onPressed: latestGateIndexEntries.isEmpty
                    ? null
                    : () => _copyText(
                          context,
                          _externalGateIndexJson(latestGateIndexEntries),
                          '外部门禁索引已复制',
                        ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('复制最新门禁索引'),
              ),
              OutlinedButton.icon(
                onPressed: latestGateIndexEntries.isEmpty
                    ? null
                    : () => _exportExternalGateIndex(
                          context,
                          latestGateIndexEntries,
                        ),
                icon: const Icon(Icons.drive_folder_upload_outlined),
                label: const Text('导出最新门禁索引'),
              ),
              OutlinedButton.icon(
                onPressed: missingActionList.isEmpty
                    ? null
                    : () => _exportMissingActions(
                          context,
                          missingActionList,
                        ),
                icon: const Icon(Icons.download_for_offline_outlined),
                label: const Text('导出缺失动作'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('export-validation-evidence'),
                onPressed: () => _exportValidationEvidence(
                  context,
                  missingActionList,
                ),
                icon: const Icon(Icons.folder_zip_outlined),
                label: const Text('导出验收证据'),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportAcceptanceBundle(context),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('导出验收包'),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportRunbookBundle(context),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('导出验收手册'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AcceptanceReadinessSummary(
            summary: summary,
            externalGateStatuses: _externalGateStatuses,
            externalGateRecords: _externalGateRecords,
            externalGateSet: activeGateSet,
            onExternalGateStatusChanged: _setExternalGateStatus,
            onExternalGateRecordChanged: _setExternalGateRecordField,
            onExternalGateCopied: (gate, status, record) {
              _copyText(
                context,
                _externalGateJson(gate, status, record),
                'External gate copied',
              );
            },
            onExternalGateExported: (gate, status, record) {
              _exportExternalGate(context, gate, status, record);
            },
          ),
        ],
      ),
    );
  }

  void _setExternalGateStatus(String gateId, String status) {
    final parsed = ExternalValidationGateStatus.fromValue(status);
    setState(() {
      _externalGateStatuses[gateId] = parsed;
      _externalGateRecords[gateId] = (_externalGateRecords[gateId] ??
              ExternalValidationGateRecord(status: parsed))
          .copyWith(status: parsed);
    });
  }

  void _setExternalGateRecordField(
    String gateId,
    _ExternalGateRecordField field,
    String value,
  ) {
    setState(() {
      final status = _externalGateStatuses[gateId] ??
          ExternalValidationGateStatus.manualRequired;
      final current = _externalGateRecords[gateId] ??
          ExternalValidationGateRecord(status: status);
      _externalGateRecords[gateId] = switch (field) {
        _ExternalGateRecordField.result => current.copyWith(result: value),
        _ExternalGateRecordField.evidence => current.copyWith(evidence: value),
        _ExternalGateRecordField.notes => current.copyWith(notes: value),
      };
    });
  }

  Future<void> _exportValidationEvidence(
    BuildContext context,
    String missingActionList,
  ) async {
    final directory = widget.exportDirectory ?? _defaultExportDirectory;
    final summary = AcceptanceSummary.fromState(
      state: widget.state,
      visibleLogs: widget.state.logs,
    );
    final result = const ValidationEvidenceExporter().export(
      directory: directory,
      validationSessionId: widget.validationSessionId,
      diagnosticsJsonLines: _sessionDiagnosticJsonLines,
      acceptanceBundleJson: widget.state.toAcceptanceBundleJson(
        visibleLogs: widget.state.logs,
        externalValidationGates: _validationGateJson(),
        environment: _currentAcceptanceBundleEnvironment,
        validationSessionId: widget.validationSessionId,
      ),
      runbookBundleJson: widget.state.toRunbookBundleJson(
        visibleLogs: widget.state.logs,
        externalValidationGates: _validationGateJson(),
        environment: _currentAcceptanceBundleEnvironment,
        validationSessionId: widget.validationSessionId,
      ),
      missingActionsDocument: buildMissingActionsDocument(
        validationSessionId: widget.validationSessionId,
        missingActionList: missingActionList,
        exportDirectoryPath: directory.path,
        environment: _currentAcceptanceBundleEnvironment,
        externalGateStatuses: _externalGateStatuses,
        externalGateRecords: _externalGateRecords,
        gateSet: _activeExternalValidationGates,
      ),
      manifestJson: (files) => buildValidationManifestJson(
        validationSessionId: widget.validationSessionId,
        exportDirectoryPath: directory.path,
        readyForAcceptance: summary.readyForAcceptance,
        missingRequiredEvidenceCount: summary.missingRequiredEvidenceCount,
        missingRequiredChecklistLabels: summary.missingRequiredChecklistLabels,
        missingActionList: summary.missingActionList,
        environment: _currentAcceptanceBundleEnvironment,
        externalGateStatuses: _externalGateStatuses,
        externalGateRecords: _externalGateRecords,
        gateSet: _activeExternalValidationGates,
        files: files,
      ),
    );
    if (!context.mounted) {
      return;
    }
    final exportedCount = result.files.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '验收证据已导出：$exportedCount 个文件，目录：'
          '${directory.path}',
        ),
      ),
    );
  }

  Future<void> _exportAcceptanceBundle(BuildContext context) async {
    final file = const ValidationEvidenceExporter().writeJson(
      directory: widget.exportDirectory ?? _defaultExportDirectory,
      prefix: 'bleunlock-acceptance-${widget.validationSessionId}',
      json: widget.state.toAcceptanceBundleJson(
        visibleLogs: widget.state.logs,
        externalValidationGates: _validationGateJson(),
        environment: _currentAcceptanceBundleEnvironment,
        validationSessionId: widget.validationSessionId,
      ),
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('验收包已导出：${file.path}')),
    );
  }

  Future<void> _exportRunbookBundle(BuildContext context) async {
    final file = const ValidationEvidenceExporter().writeJson(
      directory: widget.exportDirectory ?? _defaultExportDirectory,
      prefix: 'bleunlock-runbook-${widget.validationSessionId}',
      json: widget.state.toRunbookBundleJson(
        visibleLogs: widget.state.logs,
        externalValidationGates: _validationGateJson(),
        environment: _currentAcceptanceBundleEnvironment,
        validationSessionId: widget.validationSessionId,
      ),
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('验收手册已导出：${file.path}')),
    );
  }

  Future<void> _exportMissingActions(
    BuildContext context,
    String missingActionList,
  ) async {
    final directory = widget.exportDirectory ?? _defaultExportDirectory;
    final file = const ValidationEvidenceExporter().writeText(
      directory: directory,
      prefix: 'bleunlock-missing-actions-${widget.validationSessionId}',
      text: buildMissingActionsDocument(
        validationSessionId: widget.validationSessionId,
        missingActionList: missingActionList,
        exportDirectoryPath: directory.path,
        environment: _currentAcceptanceBundleEnvironment,
        externalGateStatuses: _externalGateStatuses,
        externalGateRecords: _externalGateRecords,
        gateSet: _activeExternalValidationGates,
      ),
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('缺失动作已导出：${file.path}')),
    );
  }

  Future<void> _exportExternalGate(
    BuildContext context,
    ExternalValidationGate gate,
    ExternalValidationGateStatus status,
    ExternalValidationGateRecord record,
  ) async {
    final directory = widget.exportDirectory ?? _defaultExportDirectory;
    final file = const ValidationEvidenceExporter().writeJson(
      directory: directory,
      prefix:
          'bleunlock-external-gate-${widget.validationSessionId}-${gate.id}',
      json: _externalGateExportMap(gate, status, record),
    );
    final indexEntry = ValidationEvidenceFileIndexEntry(
      type: 'externalValidationGate',
      path: file.path,
      gateId: gate.id,
      gateLabel: gate.label,
      status: record.status.value,
    );
    final indexEntries = _mergedExternalGateIndexEntries(
      directory,
      indexEntry,
    );
    const ValidationEvidenceExporter().writeJson(
      directory: directory,
      prefix: 'bleunlock-external-gate-index-${widget.validationSessionId}',
      json: buildExternalValidationGateIndexJson(
        validationSessionId: widget.validationSessionId,
        environment: _currentAcceptanceBundleEnvironment,
        files: indexEntries,
      ),
    );
    setState(() {});
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('外部门禁已导出：${file.path}')),
    );
  }

  Future<void> _exportExternalGateIndex(
    BuildContext context,
    List<ValidationEvidenceFileIndexEntry> entries,
  ) async {
    final file = const ValidationEvidenceExporter().writeJson(
      directory: widget.exportDirectory ?? _defaultExportDirectory,
      prefix: 'bleunlock-external-gate-index-${widget.validationSessionId}',
      json: buildExternalValidationGateIndexJson(
        validationSessionId: widget.validationSessionId,
        environment: _currentAcceptanceBundleEnvironment,
        files: entries,
      ),
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('外部门禁索引已导出：${file.path}')),
    );
  }

  String get _sessionDiagnosticJsonLines {
    return widget.state.logs
        .map(
          (entry) => jsonEncode({
            'validationSessionId': widget.validationSessionId,
            ...entry.toDiagnosticJson(),
          }),
        )
        .join('\n');
  }

  List<ValidationEvidenceFileIndexEntry> _mergedExternalGateIndexEntries(
    Directory directory,
    ValidationEvidenceFileIndexEntry current,
  ) {
    return mergeExternalValidationGateIndexEntries(
      existing: latestExternalValidationGateIndexEntries(
        directory: directory,
        validationSessionId: widget.validationSessionId,
      ),
      current: current,
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

  List<Map<String, Object?>> _validationGateJson() {
    return _activeExternalValidationGates.toDiagnosticJson(
      statuses: _externalGateStatuses,
      records: _externalGateRecords,
    );
  }

  String get _externalGateJsonLines {
    return _validationGateJson()
        .map(
          (gate) => jsonEncode({
            'validationSessionId': widget.validationSessionId,
            ...gate,
          }),
        )
        .join('\n');
  }

  String _externalGateJson(
    ExternalValidationGate gate,
    ExternalValidationGateStatus status,
    ExternalValidationGateRecord record,
  ) {
    return jsonEncode(_externalGateMap(gate, status, record));
  }

  ExternalValidationGateSet get _activeExternalValidationGates {
    if (widget.state.snapshot.isWindowsV1AutoUnlockUnsupported) {
      return defaultExternalValidationGates.withoutGate(
        'macAccessibilityUnlock',
      );
    }
    return defaultExternalValidationGates;
  }

  String _externalGateIndexJson(
    List<ValidationEvidenceFileIndexEntry> entries,
  ) {
    return jsonEncode(
      buildExternalValidationGateIndexJson(
        validationSessionId: widget.validationSessionId,
        environment: _currentAcceptanceBundleEnvironment,
        files: entries,
      ),
    );
  }

  Map<String, Object?> _externalGateMap(
    ExternalValidationGate gate,
    ExternalValidationGateStatus status,
    ExternalValidationGateRecord record,
  ) {
    return {
      'validationSessionId': widget.validationSessionId,
      ...gate.toDiagnosticJson(status: status, record: record),
    };
  }

  Map<String, Object?> _externalGateExportMap(
    ExternalValidationGate gate,
    ExternalValidationGateStatus status,
    ExternalValidationGateRecord record,
  ) {
    return buildExternalValidationGateEvidenceJson(
      validationSessionId: widget.validationSessionId,
      environment: _currentAcceptanceBundleEnvironment,
      gate: gate,
      status: status,
      record: record,
    );
  }
}

enum _ExternalGateRecordField {
  result,
  evidence,
  notes,
}

class _ExportPathLabel extends StatelessWidget {
  const _ExportPathLabel({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.folder_outlined, size: 16),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            '导出路径 $path',
            style: labelStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _AcceptanceReadinessSummary extends StatelessWidget {
  const _AcceptanceReadinessSummary({
    required this.summary,
    required this.externalGateStatuses,
    required this.externalGateRecords,
    required this.externalGateSet,
    required this.onExternalGateStatusChanged,
    required this.onExternalGateRecordChanged,
    required this.onExternalGateCopied,
    required this.onExternalGateExported,
  });

  final AcceptanceSummary summary;
  final Map<String, ExternalValidationGateStatus> externalGateStatuses;
  final Map<String, ExternalValidationGateRecord> externalGateRecords;
  final ExternalValidationGateSet externalGateSet;
  final void Function(String gateId, String status) onExternalGateStatusChanged;
  final void Function(
    String gateId,
    _ExternalGateRecordField field,
    String value,
  ) onExternalGateRecordChanged;
  final void Function(
    ExternalValidationGate gate,
    ExternalValidationGateStatus status,
    ExternalValidationGateRecord record,
  ) onExternalGateCopied;
  final void Function(
    ExternalValidationGate gate,
    ExternalValidationGateStatus status,
    ExternalValidationGateRecord record,
  ) onExternalGateExported;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final externalGateSummary = externalGateSet.summaryJson(
      statuses: externalGateStatuses,
      records: externalGateRecords,
    );
    final externalGatePendingCount =
        externalGateSummary['incompleteCount'] as int;
    final externalGateFailedCount = externalGateSummary['failedCount'] as int;
    final externalGatesResolved = externalGateSummary['allResolved'] == true &&
        externalGateSummary['hasFailures'] == false;
    final overallBlockers = summary.missingRequiredEvidenceCount +
        externalGatePendingCount +
        externalGateFailedCount;
    final overallReady = summary.readyForAcceptance && externalGatesResolved;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('验收就绪度', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Text(
          '日志 ${summary.visibleLogCount} · '
          '设备 ${summary.deviceCount} · '
          '已选 ${summary.selectedDeviceCount}',
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: overallReady ? '整体验收已就绪' : '整体验收阻塞 · $overallBlockers 项',
              icon: overallReady
                  ? Icons.verified_outlined
                  : Icons.assignment_late_outlined,
            ),
            StatusPill(
              label: externalGatesResolved ? '外部验收已完成' : '外部验收未完成',
              icon: externalGatesResolved
                  ? Icons.fact_check_outlined
                  : Icons.pending_actions_outlined,
            ),
            StatusPill(
              label: summary.readyForAcceptance
                  ? '运行验收已就绪'
                  : '运行验收未完成 · '
                      '缺少 ${summary.missingRequiredEvidenceCount} 项',
              icon: summary.readyForAcceptance
                  ? Icons.verified_outlined
                  : Icons.pending_actions_outlined,
            ),
            StatusPill(
              label: '必需证据已捕获 ${summary.completedRequiredChecklistCount}/'
                  '${summary.requiredChecklistCount}',
              icon: summary.readyForAcceptance
                  ? Icons.verified_outlined
                  : Icons.pending_actions_outlined,
            ),
            if (summary.windowsV1ReadinessLabel != null)
              StatusPill(
                label: zhDisplayText(summary.windowsV1ReadinessLabel!),
                icon: summary.isWindowsV1AutoUnlockUnsupported
                    ? Icons.block
                    : Icons.warning_amber_outlined,
              ),
          ],
        ),
        if (summary.missingRequiredChecklistLabels.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('缺少的必需证据', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in summary.missingRequiredChecklistLabels)
                StatusPill(
                  label: zhDisplayText(label),
                  icon: Icons.assignment_late_outlined,
                ),
            ],
          ),
        ],
        if (summary.missingRunbookSteps.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('下一步验收动作', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final step in summary.missingRunbookSteps)
                if (step.nextActionHint != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${zhDisplayText(step.label)}: '
                      '${zhDisplayText(step.nextActionHint!)}',
                      style: textTheme.bodySmall,
                    ),
                  ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Text('外部验证门禁', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        _ExternalGateSummaryPills(summary: externalGateSummary),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final gate in externalGateSet.gates)
              _ExternalGateControl(
                gate: gate,
                status: externalGateStatuses[gate.id] ?? gate.defaultStatus,
                record: externalGateRecords[gate.id] ??
                    ExternalValidationGateRecord(status: gate.defaultStatus),
                onStatusChanged: (status) {
                  onExternalGateStatusChanged(gate.id, status);
                },
                onRecordChanged: (field, value) {
                  onExternalGateRecordChanged(gate.id, field, value);
                },
                onCopy: () {
                  final status =
                      externalGateStatuses[gate.id] ?? gate.defaultStatus;
                  final record = externalGateRecords[gate.id] ??
                      ExternalValidationGateRecord(status: status);
                  onExternalGateCopied(gate, status, record);
                },
                onExport: () {
                  final status =
                      externalGateStatuses[gate.id] ?? gate.defaultStatus;
                  final record = externalGateRecords[gate.id] ??
                      ExternalValidationGateRecord(status: status);
                  onExternalGateExported(gate, status, record);
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('验收步骤', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Column(
          children: [
            for (final step in summary.validationSteps)
              _ValidationStepRow(step: step),
          ],
        ),
        const SizedBox(height: 12),
        if (summary.missingRunbookSteps.isNotEmpty) ...[
          Text('缺失验收步骤', style: textTheme.titleSmall),
          const SizedBox(height: 8),
          Column(
            children: [
              for (final step in summary.missingRunbookSteps)
                _RunbookStepRow(step: step),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text('验收手册', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Column(
          children: [
            for (final step in summary.runbookSteps)
              _RunbookStepRow(step: step),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(
              label: summary.hasScanEvidence ? '扫描已捕获' : '扫描缺失',
              icon: summary.hasScanEvidence
                  ? Icons.bluetooth_searching
                  : Icons.visibility_off_outlined,
            ),
            StatusPill(
              label:
                  summary.hasLockedSessionScanEvidence ? '锁屏扫描已捕获' : '锁屏扫描缺失',
              icon: summary.hasLockedSessionScanEvidence
                  ? Icons.lock_outline
                  : Icons.lock_open_outlined,
            ),
            StatusPill(
              label: summary.hasDecisionEvidence ? '判定已捕获' : '判定缺失',
              icon: summary.hasDecisionEvidence
                  ? Icons.rule
                  : Icons.rule_folder_outlined,
            ),
            StatusPill(
              label: summary.hasActionEvidence ? '动作已捕获' : '动作缺失',
              icon: summary.hasActionEvidence
                  ? Icons.play_circle_outline
                  : Icons.pause_circle_outline,
            ),
            StatusPill(
              label: summary.hasErrorEvidence ? '错误已捕获' : '无错误',
              icon: summary.hasErrorEvidence
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
            ),
            StatusPill(
              label: summary.hasAutoLockEvidence ? '自动锁屏已捕获' : '自动锁屏缺失',
              icon: summary.hasAutoLockEvidence
                  ? Icons.lock_outline
                  : Icons.lock_open_outlined,
            ),
            StatusPill(
              label: summary.hasWakeEvidence ? '唤醒已捕获' : '唤醒缺失',
              icon: summary.hasWakeEvidence
                  ? Icons.wb_sunny_outlined
                  : Icons.nights_stay_outlined,
            ),
            StatusPill(
              label: '自动解锁 ${_checklistStatusLabel(
                summary.checklistStatus('macAutoUnlockAction'),
              )}',
              icon: summary.checklistStatus('macAutoUnlockAction') == 'observed'
                  ? Icons.key_outlined
                  : summary.checklistStatus('macAutoUnlockAction') ==
                          'unsupported'
                      ? Icons.block
                      : Icons.key_off_outlined,
            ),
            StatusPill(
              label: summary.hasTrayActionEvidence ? '托盘已捕获' : '托盘缺失',
              icon: summary.hasTrayActionEvidence
                  ? Icons.space_dashboard_outlined
                  : Icons.dashboard_customize_outlined,
            ),
            _ChecklistStatusPill(
              labelPrefix: '托盘打开',
              status: summary.checklistStatus('trayOpenSettingsAction'),
              capturedIcon: Icons.open_in_new,
              missingIcon: Icons.open_in_new_off,
            ),
            _ChecklistStatusPill(
              labelPrefix: '托盘开始',
              status: summary.checklistStatus('trayStartMonitoringAction'),
              capturedIcon: Icons.play_arrow,
              missingIcon: Icons.play_disabled,
            ),
            _ChecklistStatusPill(
              labelPrefix: '托盘暂停',
              status: summary.checklistStatus('trayPauseMonitoringAction'),
              capturedIcon: Icons.pause,
              missingIcon: Icons.pause_circle_outline,
            ),
            _ChecklistStatusPill(
              labelPrefix: '托盘锁屏',
              status: summary.checklistStatus('trayLockNowAction'),
              capturedIcon: Icons.lock_outline,
              missingIcon: Icons.lock_open_outlined,
            ),
            _ChecklistStatusPill(
              labelPrefix: '托盘退出',
              status: summary.checklistStatus('trayQuitAction'),
              capturedIcon: Icons.exit_to_app,
              missingIcon: Icons.disabled_by_default_outlined,
            ),
            StatusPill(
              label: summary.hasStartupActionEvidence ? '开机启动已捕获' : '开机启动缺失',
              icon: summary.hasStartupActionEvidence
                  ? Icons.rocket_launch_outlined
                  : Icons.power_settings_new,
            ),
            _ChecklistStatusPill(
              labelPrefix: '开启开机启动',
              status: summary.checklistStatus('startupEnableAction'),
              capturedIcon: Icons.toggle_on,
              missingIcon: Icons.toggle_off,
            ),
            _ChecklistStatusPill(
              labelPrefix: '关闭开机启动',
              status: summary.checklistStatus('startupDisableAction'),
              capturedIcon: Icons.toggle_off,
              missingIcon: Icons.toggle_on,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('证据详情', style: textTheme.titleSmall),
        const SizedBox(height: 8),
        Column(
          children: [
            for (final item in summary.checklistItems)
              _ChecklistEvidenceRow(item: item),
          ],
        ),
      ],
    );
  }
}

class _ExternalGateSummaryPills extends StatelessWidget {
  const _ExternalGateSummaryPills({required this.summary});

  final Map<String, Object?> summary;

  @override
  Widget build(BuildContext context) {
    final totalCount = summary['totalCount'] as int;
    final completedCount = summary['completedCount'] as int;
    final incompleteCount = summary['incompleteCount'] as int;
    final failedCount = summary['failedCount'] as int;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusPill(
          label: '外部门禁已解决 $completedCount/$totalCount',
          icon: completedCount == totalCount
              ? Icons.fact_check_outlined
              : Icons.pending_actions_outlined,
        ),
        StatusPill(
          label: '外部门禁待处理 $incompleteCount',
          icon: incompleteCount == 0
              ? Icons.check_circle_outline
              : Icons.assignment_late_outlined,
        ),
        StatusPill(
          label: '外部门禁失败 $failedCount',
          icon: failedCount == 0 ? Icons.check_circle_outline : Icons.error,
        ),
      ],
    );
  }
}

class _ValidationStepRow extends StatelessWidget {
  const _ValidationStepRow({required this.step});

  final AcceptanceValidationStep step;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(_statusIcon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              zhDisplayText(step.label),
              style: textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(_progressLabel, style: textTheme.bodySmall),
        ],
      ),
    );
  }

  IconData get _statusIcon {
    switch (step.status) {
      case 'ready':
        return Icons.check_circle_outline;
      case 'unsupported':
        return Icons.block;
      default:
        return Icons.pending_actions_outlined;
    }
  }

  String get _progressLabel {
    final base = '已捕获 ${step.completedRequiredCount}/${step.requiredCount}';
    if (step.latestEvidenceAt == null) {
      return base;
    }
    return '$base · 最新 ${_timeLabel(step.latestEvidenceAt!)}';
  }
}

class _ExternalGateControl extends StatelessWidget {
  const _ExternalGateControl({
    required this.gate,
    required this.status,
    required this.record,
    required this.onStatusChanged,
    required this.onRecordChanged,
    required this.onCopy,
    required this.onExport,
  });

  final ExternalValidationGate gate;
  final ExternalValidationGateStatus status;
  final ExternalValidationGateRecord record;
  final ValueChanged<String> onStatusChanged;
  final void Function(_ExternalGateRecordField field, String value)
      onRecordChanged;
  final VoidCallback onCopy;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 360,
      child: ExpansionTile(
        key: ValueKey('gate-${gate.id}-panel'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(zhDisplayText(gate.label), style: textTheme.bodySmall),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _gateSubtitle,
            style: textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: StatusPill(
              label: '${zhDisplayText(gate.label)} ${_gateStatusLabel(status)}',
              icon: _gateStatusIcon(status),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment<String>(
                  value: 'manualRequired',
                  label: Text(
                    '待验证',
                    key: ValueKey('gate-${gate.id}-pending'),
                  ),
                  icon: const Icon(Icons.pending_actions_outlined),
                ),
                ButtonSegment<String>(
                  value: 'passed',
                  label: Text(
                    '通过',
                    key: ValueKey('gate-${gate.id}-pass'),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  enabled: true,
                ),
                ButtonSegment<String>(
                  value: 'failed',
                  label: Text(
                    '失败',
                    key: ValueKey('gate-${gate.id}-fail'),
                  ),
                  icon: const Icon(Icons.error_outline),
                  enabled: true,
                ),
              ],
              selected: {status.value},
              onSelectionChanged: (selection) {
                onStatusChanged(selection.single);
              },
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              zhDisplayText(gate.action),
              style: textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: ValueKey('gate-${gate.id}-copy'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('复制门禁'),
                ),
                OutlinedButton.icon(
                  key: ValueKey('gate-${gate.id}-export'),
                  onPressed: onExport,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('导出门禁'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _ExternalGateTextField(
            key: ValueKey('gate-${gate.id}-result'),
            initialValue: record.result,
            label: '结果',
            onChanged: (value) {
              onRecordChanged(_ExternalGateRecordField.result, value);
            },
          ),
          const SizedBox(height: 6),
          _ExternalGateTextField(
            key: ValueKey('gate-${gate.id}-evidence'),
            initialValue: record.evidence,
            label: '证据',
            onChanged: (value) {
              onRecordChanged(_ExternalGateRecordField.evidence, value);
            },
          ),
          const SizedBox(height: 6),
          _ExternalGateTextField(
            key: ValueKey('gate-${gate.id}-notes'),
            initialValue: record.notes,
            label: '备注',
            onChanged: (value) {
              onRecordChanged(_ExternalGateRecordField.notes, value);
            },
          ),
        ],
      ),
    );
  }

  String get _gateSubtitle {
    final summary = [
      _gateStatusLabel(status),
      if (record.result.trim().isNotEmpty) record.result.trim(),
    ];
    return summary.join(' · ');
  }
}

class _ExternalGateTextField extends StatelessWidget {
  const _ExternalGateTextField({
    required this.initialValue,
    required this.label,
    required this.onChanged,
    super.key,
  });

  final String initialValue;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      minLines: 1,
      maxLines: 2,
      onChanged: onChanged,
    );
  }
}

String _gateStatusLabel(ExternalValidationGateStatus status) {
  switch (status) {
    case ExternalValidationGateStatus.passed:
      return '已通过';
    case ExternalValidationGateStatus.failed:
      return '失败';
    case ExternalValidationGateStatus.manualRequired:
      return '待验证';
  }
}

IconData _gateStatusIcon(ExternalValidationGateStatus status) {
  switch (status) {
    case ExternalValidationGateStatus.passed:
      return Icons.check_circle_outline;
    case ExternalValidationGateStatus.failed:
      return Icons.error_outline;
    case ExternalValidationGateStatus.manualRequired:
      return Icons.fact_check_outlined;
  }
}

class _RunbookStepRow extends StatelessWidget {
  const _RunbookStepRow({required this.step});

  final AcceptanceRunbookStep step;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final detail = [
      zhDisplayText(step.progressLabel),
      '证据 ${zhDisplayText(step.expectedEvidence)}',
      if (step.latestEvidenceAt != null)
        '最新 ${_timeLabel(step.latestEvidenceAt!)}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(_statusIcon, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  zhDisplayText(step.action),
                  style: textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(_runbookStatusLabel(step.status),
                  style: textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: Text(detail, style: textTheme.bodySmall),
          ),
          if (step.missingRequiredLabels.isNotEmpty) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '缺少 ${step.missingRequiredLabels.map(zhDisplayText).join('、')}',
                style: textTheme.bodySmall,
              ),
            ),
          ],
          if (step.nextActionHint != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                '下一步 ${zhDisplayText(step.nextActionHint!)}',
                style: textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData get _statusIcon {
    switch (step.status) {
      case 'ready':
        return Icons.check_circle_outline;
      case 'unsupported':
        return Icons.block;
      default:
        return Icons.pending_actions_outlined;
    }
  }
}

class _ChecklistEvidenceRow extends StatelessWidget {
  const _ChecklistEvidenceRow({required this.item});

  final AcceptanceChecklistItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(_statusIcon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              zhDisplayText(item.label),
              style: textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _evidenceLabel,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  IconData get _statusIcon {
    switch (item.status) {
      case 'observed':
        return Icons.check_circle_outline;
      case 'unsupported':
        return Icons.block;
      case 'none':
        return Icons.check_circle_outline;
      default:
        return Icons.radio_button_unchecked;
    }
  }

  String get _evidenceLabel {
    if (item.latestEvidenceAt == null) {
      return '${item.evidenceCount} 条证据';
    }
    return '${item.evidenceCount} 条证据 · 最新 '
        '${_timeLabel(item.latestEvidenceAt!)}';
  }
}

class _ChecklistStatusPill extends StatelessWidget {
  const _ChecklistStatusPill({
    required this.labelPrefix,
    required this.status,
    required this.capturedIcon,
    required this.missingIcon,
  });

  final String labelPrefix;
  final String status;
  final IconData capturedIcon;
  final IconData missingIcon;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: '$labelPrefix ${_checklistStatusLabel(status)}',
      icon: status == 'observed' ? capturedIcon : missingIcon,
    );
  }
}

String _checklistStatusLabel(String status) {
  switch (status) {
    case 'observed':
      return '已捕获';
    case 'unsupported':
      return '不支持';
    case 'none':
      return '无错误';
    default:
      return zhChecklistStatus(status);
  }
}

String _runbookStatusLabel(String status) {
  switch (status) {
    case 'ready':
      return '就绪';
    case 'unsupported':
      return '不支持';
    case 'incomplete':
      return '未完成';
    default:
      return zhDisplayText(status);
  }
}

String _timeLabel(DateTime timestamp) {
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  final second = timestamp.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _createValidationSessionId() {
  final timestamp = DateTime.now()
      .toUtc()
      .toIso8601String()
      .replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  return 'validation-$timestamp';
}

AcceptanceBundleEnvironment get _currentAcceptanceBundleEnvironment {
  return AcceptanceBundleEnvironment(
    exportSource: 'validationSection',
    platform: Platform.operatingSystem,
    operatingSystemVersion: Platform.operatingSystemVersion,
    dartVersion: Platform.version,
    buildMode: _buildModeLabel,
  );
}

String get _buildModeLabel {
  if (kReleaseMode) {
    return 'release';
  }
  if (kProfileMode) {
    return 'profile';
  }
  return 'debug';
}

final Directory _defaultExportDirectory = Directory(
  '${Directory.systemTemp.path}/BLEUnlock/diagnostics',
);
