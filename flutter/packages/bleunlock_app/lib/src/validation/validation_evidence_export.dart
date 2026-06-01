import 'dart:convert';
import 'dart:io';

import 'package:bleunlock_app/src/view_models/dashboard_state.dart';

enum ExternalValidationGateStatus {
  manualRequired('manualRequired'),
  passed('passed'),
  failed('failed');

  const ExternalValidationGateStatus(this.value);

  final String value;

  static ExternalValidationGateStatus fromValue(String? value) {
    switch (value) {
      case 'passed':
        return ExternalValidationGateStatus.passed;
      case 'failed':
        return ExternalValidationGateStatus.failed;
      default:
        return ExternalValidationGateStatus.manualRequired;
    }
  }
}

class ExternalValidationGateRecord {
  const ExternalValidationGateRecord({
    required this.status,
    this.result = '',
    this.evidence = '',
    this.notes = '',
  });

  final ExternalValidationGateStatus status;
  final String result;
  final String evidence;
  final String notes;

  ExternalValidationGateRecord copyWith({
    ExternalValidationGateStatus? status,
    String? result,
    String? evidence,
    String? notes,
  }) {
    return ExternalValidationGateRecord(
      status: status ?? this.status,
      result: result ?? this.result,
      evidence: evidence ?? this.evidence,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toDiagnosticJson() {
    return {
      'status': status.value,
      'result': result,
      'evidence': evidence,
      'notes': notes,
    };
  }
}

class ExternalValidationGate {
  const ExternalValidationGate({
    required this.id,
    required this.label,
    required this.action,
  });

  final String id;
  final String label;
  final String action;

  ExternalValidationGateStatus get defaultStatus =>
      ExternalValidationGateStatus.manualRequired;

  Map<String, Object?> toDiagnosticJson({
    ExternalValidationGateStatus? status,
    ExternalValidationGateRecord? record,
  }) {
    return {
      'id': id,
      'label': label,
      if (record == null) 'status': (status ?? defaultStatus).value,
      if (record != null) ...record.toDiagnosticJson(),
      'action': action,
    };
  }
}

class ExternalValidationGateSet {
  const ExternalValidationGateSet(this.gates);

  final List<ExternalValidationGate> gates;

  ExternalValidationGateSet withoutGate(String gateId) {
    return ExternalValidationGateSet([
      for (final gate in gates)
        if (gate.id != gateId) gate,
    ]);
  }

  Map<String, ExternalValidationGateStatus> defaultStatuses() {
    return {
      for (final gate in gates) gate.id: gate.defaultStatus,
    };
  }

  List<Map<String, Object?>> toDiagnosticJson({
    Map<String, ExternalValidationGateStatus> statuses = const {},
    Map<String, ExternalValidationGateRecord> records = const {},
  }) {
    return [
      for (final gate in gates)
        gate.toDiagnosticJson(
          status: statuses[gate.id] ?? gate.defaultStatus,
          record: records[gate.id],
        ),
    ];
  }

  Map<String, Object?> summaryJson({
    Map<String, ExternalValidationGateStatus> statuses = const {},
    Map<String, ExternalValidationGateRecord> records = const {},
  }) {
    final pendingLabels = <String>[];
    final failedLabels = <String>[];
    var passedCount = 0;
    var failedCount = 0;
    var manualRequiredCount = 0;

    for (final gate in gates) {
      final status =
          records[gate.id]?.status ?? statuses[gate.id] ?? gate.defaultStatus;
      switch (status) {
        case ExternalValidationGateStatus.passed:
          passedCount += 1;
        case ExternalValidationGateStatus.failed:
          failedCount += 1;
          failedLabels.add(gate.label);
        case ExternalValidationGateStatus.manualRequired:
          manualRequiredCount += 1;
          pendingLabels.add(gate.label);
      }
    }

    return {
      'totalCount': gates.length,
      'passedCount': passedCount,
      'failedCount': failedCount,
      'manualRequiredCount': manualRequiredCount,
      'completedCount': passedCount + failedCount,
      'incompleteCount': manualRequiredCount,
      'hasFailures': failedCount > 0,
      'allResolved': manualRequiredCount == 0,
      'pendingGateLabels': pendingLabels,
      'failedGateLabels': failedLabels,
    };
  }

  String toNumberedText({
    Map<String, ExternalValidationGateStatus> statuses = const {},
    Map<String, ExternalValidationGateRecord> records = const {},
  }) {
    return [
      for (var index = 0; index < gates.length; index += 1)
        _gateText(
          index: index,
          gate: gates[index],
          record: records[gates[index].id],
          status: statuses[gates[index].id] ?? gates[index].defaultStatus,
        ),
    ].join('\n');
  }

  String _gateText({
    required int index,
    required ExternalValidationGate gate,
    required ExternalValidationGateStatus status,
    ExternalValidationGateRecord? record,
  }) {
    final exportedStatus = record?.status ?? status;
    return [
      '${index + 1}. ${gate.label}',
      '   status: ${exportedStatus.value}',
      '   action: ${gate.action}',
      '   result: ${record?.result ?? ''}',
      '   evidence: ${record?.evidence ?? ''}',
      '   notes: ${record?.notes ?? ''}',
    ].join('\n');
  }
}

const defaultExternalValidationGates = ExternalValidationGateSet([
  ExternalValidationGate(
    id: 'windowsBuild',
    label: 'Windows build verification',
    action: 'Run flutter build windows on a Windows host.',
  ),
  ExternalValidationGate(
    id: 'realBleScan',
    label: 'Real BLE scan',
    action: 'Run the desktop app with a real BLE device and capture scan logs.',
  ),
  ExternalValidationGate(
    id: 'lockScreenScan',
    label: 'Lock-screen scan continuity',
    action: 'Lock the desktop session and confirm scan evidence continues.',
  ),
  ExternalValidationGate(
    id: 'macAccessibilityUnlock',
    label: 'macOS Accessibility unlock',
    action: 'Grant Accessibility permission and validate automatic unlock.',
  ),
  ExternalValidationGate(
    id: 'trayActions',
    label: 'Tray actions',
    action: 'Use every tray/menu action and confirm action logs.',
  ),
  ExternalValidationGate(
    id: 'startupActions',
    label: 'Startup at login actions',
    action: 'Toggle startup at login on and off and confirm action logs.',
  ),
]);

Map<String, Object?> buildExternalValidationGateEvidenceJson({
  required String validationSessionId,
  required AcceptanceBundleEnvironment environment,
  required ExternalValidationGate gate,
  required ExternalValidationGateStatus status,
  required ExternalValidationGateRecord record,
  DateTime? exportedAt,
}) {
  return {
    'schemaVersion': 1,
    'bundleType': 'externalValidationGate',
    'validationSessionId': validationSessionId,
    'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'environment': environment.toDiagnosticJson(),
    ...gate.toDiagnosticJson(status: status, record: record),
  };
}

String buildMissingActionsDocument({
  required String validationSessionId,
  required String missingActionList,
  required String exportDirectoryPath,
  required AcceptanceBundleEnvironment environment,
  required Map<String, ExternalValidationGateStatus> externalGateStatuses,
  Map<String, ExternalValidationGateRecord> externalGateRecords = const {},
  DateTime? exportedAt,
  ExternalValidationGateSet gateSet = defaultExternalValidationGates,
}) {
  return [
    'validationSessionId: $validationSessionId',
    'exportedAt: ${(exportedAt ?? DateTime.now()).toUtc().toIso8601String()}',
    'platform: ${environment.platform}',
    'operatingSystemVersion: ${environment.operatingSystemVersion}',
    'buildMode: ${environment.buildMode}',
    '',
    'relatedFiles:',
    '  exportDirectory: $exportDirectoryPath',
    '  diagnostics: bleunlock-diagnostics-$validationSessionId-*.jsonl',
    '  acceptance: bleunlock-acceptance-$validationSessionId-*.json',
    '  runbook: bleunlock-runbook-$validationSessionId-*.json',
    '',
    'missingActions:',
    numberedActionList(missingActionList),
    '',
    'externalValidationGates:',
    gateSet.toNumberedText(
      statuses: externalGateStatuses,
      records: externalGateRecords,
    ),
  ].join('\n');
}

class ValidationEvidenceFileIndexEntry {
  const ValidationEvidenceFileIndexEntry({
    required this.type,
    required this.path,
    this.gateId,
    this.gateLabel,
    this.status,
  });

  final String type;
  final String path;
  final String? gateId;
  final String? gateLabel;
  final String? status;

  Map<String, Object?> toDiagnosticJson(String validationSessionId) {
    return {
      'type': type,
      'path': path,
      'filename': _basename(path),
      'validationSessionId': validationSessionId,
      if (gateId != null) 'gateId': gateId,
      if (gateLabel != null) 'gateLabel': gateLabel,
      if (status != null) 'status': status,
    };
  }
}

Map<String, Object?> buildExternalValidationGateIndexJson({
  required String validationSessionId,
  required AcceptanceBundleEnvironment environment,
  required List<ValidationEvidenceFileIndexEntry> files,
  DateTime? exportedAt,
}) {
  return {
    'schemaVersion': 1,
    'bundleType': 'externalValidationGateIndex',
    'validationSessionId': validationSessionId,
    'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'environment': environment.toDiagnosticJson(),
    'fileCount': files.length,
    'files': [
      for (final file in files) file.toDiagnosticJson(validationSessionId),
    ],
  };
}

List<ValidationEvidenceFileIndexEntry> mergeExternalValidationGateIndexEntries({
  required Iterable<ValidationEvidenceFileIndexEntry> existing,
  required ValidationEvidenceFileIndexEntry current,
}) {
  final entriesByGateId = <String, ValidationEvidenceFileIndexEntry>{};
  for (final entry in existing) {
    entriesByGateId[entry.gateId ?? entry.path] = entry;
  }
  entriesByGateId[current.gateId ?? current.path] = current;
  return entriesByGateId.values.toList(growable: false);
}

List<ValidationEvidenceFileIndexEntry>
    externalValidationGateIndexEntriesFromJson(
  Map<String, Object?> json,
) {
  final files = json['files'];
  if (files is! List<Object?>) {
    return const [];
  }
  return [
    for (final file in files)
      if (file is Map<String, Object?>)
        ValidationEvidenceFileIndexEntry(
          type: file['type'] as String? ?? 'externalValidationGate',
          path: file['path'] as String? ?? '',
          gateId: file['gateId'] as String?,
          gateLabel: file['gateLabel'] as String?,
          status: file['status'] as String?,
        ),
  ];
}

List<ValidationEvidenceFileIndexEntry>
    latestExternalValidationGateIndexEntries({
  required Directory directory,
  required String validationSessionId,
}) {
  if (!directory.existsSync()) {
    return const [];
  }
  final prefix = 'bleunlock-external-gate-index-$validationSessionId-';
  final indexFiles = directory
      .listSync()
      .whereType<File>()
      .where((file) => file.uri.pathSegments.last.startsWith(prefix))
      .toList(growable: false);
  if (indexFiles.isEmpty) {
    return const [];
  }
  indexFiles.sort((left, right) => left.path.compareTo(right.path));
  try {
    final decoded = jsonDecode(indexFiles.last.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      return const [];
    }
    return externalValidationGateIndexEntriesFromJson(decoded);
  } on FormatException {
    return const [];
  } on IOException {
    return const [];
  }
}

class ValidationEvidenceExportResult {
  const ValidationEvidenceExportResult({
    required this.diagnostics,
    required this.acceptance,
    required this.runbook,
    required this.missingActions,
    required this.manifest,
    required this.evidenceFiles,
  });

  final File diagnostics;
  final File acceptance;
  final File runbook;
  final File missingActions;
  final File manifest;
  final List<ValidationEvidenceFileIndexEntry> evidenceFiles;

  List<File> get files {
    return [
      diagnostics,
      acceptance,
      runbook,
      missingActions,
      manifest,
    ];
  }
}

class ValidationEvidenceExporter {
  const ValidationEvidenceExporter({
    DateTime Function()? clock,
  }) : _clock = clock;

  final DateTime Function()? _clock;

  ValidationEvidenceExportResult export({
    required Directory directory,
    required String validationSessionId,
    required String diagnosticsJsonLines,
    required Map<String, Object?> acceptanceBundleJson,
    required Map<String, Object?> runbookBundleJson,
    required String missingActionsDocument,
    required Map<String, Object?> Function(
      List<ValidationEvidenceFileIndexEntry> files,
    ) manifestJson,
  }) {
    final diagnostics = _writeJsonLines(
      directory,
      'bleunlock-diagnostics-$validationSessionId',
      diagnosticsJsonLines,
    );
    final acceptance = writeJson(
      directory: directory,
      prefix: 'bleunlock-acceptance-$validationSessionId',
      json: acceptanceBundleJson,
    );
    final runbook = writeJson(
      directory: directory,
      prefix: 'bleunlock-runbook-$validationSessionId',
      json: runbookBundleJson,
    );
    final missingActions = writeText(
      directory: directory,
      prefix: 'bleunlock-missing-actions-$validationSessionId',
      text: missingActionsDocument,
    );
    final evidenceFiles = [
      ValidationEvidenceFileIndexEntry(
        type: 'diagnostics',
        path: diagnostics.path,
      ),
      ValidationEvidenceFileIndexEntry(
        type: 'acceptance',
        path: acceptance.path,
      ),
      ValidationEvidenceFileIndexEntry(
        type: 'runbook',
        path: runbook.path,
      ),
      ValidationEvidenceFileIndexEntry(
        type: 'missingActions',
        path: missingActions.path,
      ),
    ];
    final manifest = writeJson(
      directory: directory,
      prefix: 'bleunlock-manifest-$validationSessionId',
      json: manifestJson(evidenceFiles),
    );
    return ValidationEvidenceExportResult(
      diagnostics: diagnostics,
      acceptance: acceptance,
      runbook: runbook,
      missingActions: missingActions,
      manifest: manifest,
      evidenceFiles: evidenceFiles,
    );
  }

  File writeJson({
    required Directory directory,
    required String prefix,
    required Map<String, Object?> json,
  }) {
    directory.createSync(recursive: true);
    final file = File('${directory.path}/$prefix-$_timestamp.json');
    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync('${encoder.convert(json)}\n', flush: true);
    return file;
  }

  File writeText({
    required Directory directory,
    required String prefix,
    required String text,
  }) {
    directory.createSync(recursive: true);
    final file = File('${directory.path}/$prefix-$_timestamp.txt');
    file.writeAsStringSync('$text\n', flush: true);
    return file;
  }

  File _writeJsonLines(
    Directory directory,
    String prefix,
    String text,
  ) {
    directory.createSync(recursive: true);
    final file = File('${directory.path}/$prefix-$_timestamp.jsonl');
    file.writeAsStringSync('$text\n', flush: true);
    return file;
  }

  String get _timestamp {
    return (_clock ?? DateTime.now)
        .call()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  }
}

Map<String, Object?> buildValidationManifestJson({
  required String validationSessionId,
  required String exportDirectoryPath,
  required bool readyForAcceptance,
  required int missingRequiredEvidenceCount,
  required List<String> missingRequiredChecklistLabels,
  required String missingActionList,
  required AcceptanceBundleEnvironment environment,
  required Map<String, ExternalValidationGateStatus> externalGateStatuses,
  Map<String, ExternalValidationGateRecord> externalGateRecords = const {},
  required List<ValidationEvidenceFileIndexEntry> files,
  DateTime? exportedAt,
  ExternalValidationGateSet gateSet = defaultExternalValidationGates,
}) {
  final externalGateSummary = gateSet.summaryJson(
    statuses: externalGateStatuses,
    records: externalGateRecords,
  );
  final overallBlockerLabels = [
    for (final label in missingRequiredChecklistLabels)
      'Runtime evidence missing: $label',
    for (final label
        in externalGateSummary['pendingGateLabels'] as List<Object?>)
      'External gate pending: $label',
    for (final label
        in externalGateSummary['failedGateLabels'] as List<Object?>)
      'External gate failed: $label',
  ];
  final externalGatesResolved = externalGateSummary['allResolved'] == true &&
      externalGateSummary['hasFailures'] == false;
  final overallReadyForAcceptance = readyForAcceptance && externalGatesResolved;
  return {
    'schemaVersion': 1,
    'bundleType': 'validationManifest',
    'validationSessionId': validationSessionId,
    'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'exportDirectory': exportDirectoryPath,
    'fileCount': files.length,
    'readyForAcceptance': readyForAcceptance,
    'missingRequiredEvidenceCount': missingRequiredEvidenceCount,
    'missingRequiredChecklistLabels': missingRequiredChecklistLabels,
    'missingActionList': missingActionList,
    'externalValidationGateSummary': externalGateSummary,
    'overallReadyForAcceptance': overallReadyForAcceptance,
    'overallAcceptanceBlockers': overallBlockerLabels.length,
    'overallAcceptanceBlockerLabels': overallBlockerLabels,
    'externalValidationGates': gateSet.toDiagnosticJson(
      statuses: externalGateStatuses,
      records: externalGateRecords,
    ),
    'environment': environment.toDiagnosticJson(),
    'files': [
      for (final file in files) file.toDiagnosticJson(validationSessionId),
    ],
  };
}

String numberedActionList(String actionList) {
  final actions = actionList
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  return [
    for (var index = 0; index < actions.length; index += 1)
      [
        '${index + 1}. ${actions[index]}',
        '   result: ',
        '   evidence: ',
        '   notes: ',
      ].join('\n'),
  ].join('\n');
}

String _basename(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').last;
}
