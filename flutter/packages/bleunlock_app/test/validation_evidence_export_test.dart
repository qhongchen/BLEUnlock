import 'dart:convert';
import 'dart:io';

import 'package:bleunlock_app/src/validation/validation_evidence_export.dart';
import 'package:bleunlock_app/src/view_models/dashboard_state.dart';

void main() {
  testExternalValidationGatesExportStructuredJson();
  testExternalValidationGateSetCanExcludePlatformIrrelevantGates();
  testExternalValidationGateRecordsExportManualDetails();
  testExternalValidationGateSummaryCountsStatusesAndPendingLabels();
  testExternalValidationGateEvidenceJsonIncludesMetadata();
  testExternalValidationGateIndexJsonListsEvidenceFiles();
  testExternalValidationGateIndexMergeKeepsLatestGateEntry();
  testExternalValidationGateIndexEntriesParseAndIgnoreMalformedJson();
  testLatestExternalValidationGateIndexEntriesReadNewestFile();
  testLatestExternalValidationGateIndexEntriesIgnoreMissingAndMalformedInput();
  testMissingActionsDocumentIncludesRelatedFilesAndGateStatuses();
  testValidationManifestExportsFileIndexAndGateStatuses();
  testValidationEvidenceExporterWritesCompleteBundle();
  testValidationEvidenceExporterWritesSingleJsonAndTextFiles();
}

void testExternalValidationGateSetCanExcludePlatformIrrelevantGates() {
  final windowsV1Gates =
      defaultExternalValidationGates.withoutGate('macAccessibilityUnlock');
  final gates = windowsV1Gates.toDiagnosticJson();
  final summary = windowsV1Gates.summaryJson(
    statuses: const {
      'windowsBuild': ExternalValidationGateStatus.passed,
    },
  );

  assert(gates.length == 5);
  assert(!gates.any((gate) => gate['id'] == 'macAccessibilityUnlock'));
  assert(summary['totalCount'] == 5);
  assert(summary['passedCount'] == 1);
  assert(summary['manualRequiredCount'] == 4);
  assert(
    !(summary['pendingGateLabels'] as List<Object?>)
        .contains('macOS Accessibility unlock'),
  );
}

void testExternalValidationGatesExportStructuredJson() {
  final gates = defaultExternalValidationGates.toDiagnosticJson(
    statuses: const {
      'windowsBuild': ExternalValidationGateStatus.passed,
      'realBleScan': ExternalValidationGateStatus.failed,
    },
  );

  assert(gates.length == 6);

  final windowsBuild = gates.singleWhere(
    (gate) => gate['id'] == 'windowsBuild',
  );
  assert(windowsBuild['label'] == 'Windows build verification');
  assert(windowsBuild['status'] == 'passed');

  final realBleScan = gates.singleWhere(
    (gate) => gate['id'] == 'realBleScan',
  );
  assert(realBleScan['status'] == 'failed');

  final trayActions = gates.singleWhere(
    (gate) => gate['id'] == 'trayActions',
  );
  assert(trayActions['status'] == 'manualRequired');

  final encoded = jsonEncode(gates);
  assert(encoded.contains('"status":"passed"'));
  assert(encoded.contains('"status":"failed"'));
}

void testExternalValidationGateRecordsExportManualDetails() {
  final gates = defaultExternalValidationGates.toDiagnosticJson(
    records: const {
      'windowsBuild': ExternalValidationGateRecord(
        status: ExternalValidationGateStatus.passed,
        result: 'Built on Windows 11 ARM64',
        evidence: 'bleunlock-windows-build.log',
        notes: 'WinRT linkage verified',
      ),
    },
  );

  final windowsBuild = gates.singleWhere(
    (gate) => gate['id'] == 'windowsBuild',
  );
  assert(windowsBuild['status'] == 'passed');
  assert(windowsBuild['result'] == 'Built on Windows 11 ARM64');
  assert(windowsBuild['evidence'] == 'bleunlock-windows-build.log');
  assert(windowsBuild['notes'] == 'WinRT linkage verified');

  final text = defaultExternalValidationGates.toNumberedText(
    records: const {
      'windowsBuild': ExternalValidationGateRecord(
        status: ExternalValidationGateStatus.passed,
        result: 'Built on Windows 11 ARM64',
        evidence: 'bleunlock-windows-build.log',
        notes: 'WinRT linkage verified',
      ),
    },
  );
  assert(text.contains('1. Windows build verification'));
  assert(text.contains('   status: passed'));
  assert(text.contains('   result: Built on Windows 11 ARM64'));
  assert(text.contains('   evidence: bleunlock-windows-build.log'));
  assert(text.contains('   notes: WinRT linkage verified'));
  assert(text.contains('2. Real BLE scan\n   status: manualRequired'));
}

void testExternalValidationGateSummaryCountsStatusesAndPendingLabels() {
  final summary = defaultExternalValidationGates.summaryJson(
    statuses: const {
      'windowsBuild': ExternalValidationGateStatus.passed,
      'realBleScan': ExternalValidationGateStatus.failed,
    },
    records: const {
      'macAccessibilityUnlock': ExternalValidationGateRecord(
        status: ExternalValidationGateStatus.passed,
        result: 'Unlocked from lock screen',
        evidence: 'mac-accessibility-unlock.json',
      ),
    },
  );

  assert(summary['totalCount'] == 6);
  assert(summary['passedCount'] == 2);
  assert(summary['failedCount'] == 1);
  assert(summary['manualRequiredCount'] == 3);
  assert(summary['completedCount'] == 3);
  assert(summary['incompleteCount'] == 3);
  assert(summary['hasFailures'] == true);
  assert(summary['allResolved'] == false);
  assert(
    (summary['pendingGateLabels'] as List<Object?>)
        .contains('Lock-screen scan continuity'),
  );
  assert(
    (summary['failedGateLabels'] as List<Object?>).contains('Real BLE scan'),
  );
}

void testExternalValidationGateEvidenceJsonIncludesMetadata() {
  final json = buildExternalValidationGateEvidenceJson(
    validationSessionId: 'validation-manual-001',
    exportedAt: DateTime.utc(2026, 5, 30, 12),
    environment: const AcceptanceBundleEnvironment(
      exportSource: 'validationSection',
      platform: 'windows',
      operatingSystemVersion: 'Windows 11',
      dartVersion: 'Dart test',
      buildMode: 'debug',
    ),
    gate: defaultExternalValidationGates.gates.first,
    status: ExternalValidationGateStatus.passed,
    record: const ExternalValidationGateRecord(
      status: ExternalValidationGateStatus.passed,
      result: 'Built on Windows 11 ARM64',
      evidence: 'bleunlock-windows-build.log',
      notes: 'WinRT linkage verified',
    ),
  );

  assert(json['schemaVersion'] == 1);
  assert(json['bundleType'] == 'externalValidationGate');
  assert(json['validationSessionId'] == 'validation-manual-001');
  assert(json['exportedAt'] == '2026-05-30T12:00:00.000Z');
  final environment = json['environment'] as Map<String, Object?>;
  assert(environment['exportSource'] == 'validationSection');
  assert(environment['platform'] == 'windows');
  assert(environment['operatingSystemVersion'] == 'Windows 11');
  assert(environment['dartVersion'] == 'Dart test');
  assert(environment['buildMode'] == 'debug');
  assert(json['id'] == 'windowsBuild');
  assert(json['label'] == 'Windows build verification');
  assert(json['status'] == 'passed');
  assert(json['result'] == 'Built on Windows 11 ARM64');
  assert(json['evidence'] == 'bleunlock-windows-build.log');
  assert(json['notes'] == 'WinRT linkage verified');
  assert((json['action'] as String).contains('flutter build windows'));
}

void testExternalValidationGateIndexJsonListsEvidenceFiles() {
  final gate = defaultExternalValidationGates.gates.first;
  final evidenceFile = ValidationEvidenceFileIndexEntry(
    type: 'externalValidationGate',
    path:
        '/tmp/bleunlock-external-gate-validation-manual-001-windowsBuild.json',
    gateId: gate.id,
    gateLabel: gate.label,
    status: ExternalValidationGateStatus.passed.value,
  );
  final json = buildExternalValidationGateIndexJson(
    validationSessionId: 'validation-manual-001',
    exportedAt: DateTime.utc(2026, 5, 30, 12, 15),
    environment: const AcceptanceBundleEnvironment(
      exportSource: 'validationSection',
      platform: 'windows',
      operatingSystemVersion: 'Windows 11',
      dartVersion: 'Dart test',
      buildMode: 'debug',
    ),
    files: [evidenceFile],
  );

  assert(json['schemaVersion'] == 1);
  assert(json['bundleType'] == 'externalValidationGateIndex');
  assert(json['validationSessionId'] == 'validation-manual-001');
  assert(json['exportedAt'] == '2026-05-30T12:15:00.000Z');
  final environment = json['environment'] as Map<String, Object?>;
  assert(environment['exportSource'] == 'validationSection');
  assert(environment['platform'] == 'windows');
  assert(json['fileCount'] == 1);
  final files = json['files'] as List<Object?>;
  final entry = files.single as Map<String, Object?>;
  assert(entry['type'] == 'externalValidationGate');
  assert(entry['gateId'] == 'windowsBuild');
  assert(entry['gateLabel'] == 'Windows build verification');
  assert(entry['status'] == 'passed');
  assert(entry['validationSessionId'] == 'validation-manual-001');
  assert(entry['filename'] ==
      'bleunlock-external-gate-validation-manual-001-windowsBuild.json');
}

void testExternalValidationGateIndexMergeKeepsLatestGateEntry() {
  const existingWindowsBuild = ValidationEvidenceFileIndexEntry(
    type: 'externalValidationGate',
    path: '/tmp/windows-build-old.json',
    gateId: 'windowsBuild',
    gateLabel: 'Windows build verification',
    status: 'failed',
  );
  const existingRealBleScan = ValidationEvidenceFileIndexEntry(
    type: 'externalValidationGate',
    path: '/tmp/real-ble-scan.json',
    gateId: 'realBleScan',
    gateLabel: 'Real BLE scan',
    status: 'passed',
  );
  const currentWindowsBuild = ValidationEvidenceFileIndexEntry(
    type: 'externalValidationGate',
    path: '/tmp/windows-build-new.json',
    gateId: 'windowsBuild',
    gateLabel: 'Windows build verification',
    status: 'passed',
  );

  final merged = mergeExternalValidationGateIndexEntries(
    existing: const [
      existingWindowsBuild,
      existingRealBleScan,
    ],
    current: currentWindowsBuild,
  );

  assert(merged.length == 2);
  final windowsBuild = merged.singleWhere(
    (entry) => entry.gateId == 'windowsBuild',
  );
  final realBleScan = merged.singleWhere(
    (entry) => entry.gateId == 'realBleScan',
  );
  assert(windowsBuild.path == '/tmp/windows-build-new.json');
  assert(windowsBuild.status == 'passed');
  assert(realBleScan.path == '/tmp/real-ble-scan.json');
  assert(realBleScan.status == 'passed');
}

void testExternalValidationGateIndexEntriesParseAndIgnoreMalformedJson() {
  final entries = externalValidationGateIndexEntriesFromJson({
    'files': [
      {
        'type': 'externalValidationGate',
        'path': '/tmp/windows-build.json',
        'gateId': 'windowsBuild',
        'gateLabel': 'Windows build verification',
        'status': 'passed',
      },
      {
        'path': '/tmp/legacy-gate.json',
      },
      'not an object',
    ],
  });

  assert(entries.length == 2);
  assert(entries.first.type == 'externalValidationGate');
  assert(entries.first.path == '/tmp/windows-build.json');
  assert(entries.first.gateId == 'windowsBuild');
  assert(entries.first.gateLabel == 'Windows build verification');
  assert(entries.first.status == 'passed');
  assert(entries.last.type == 'externalValidationGate');
  assert(entries.last.path == '/tmp/legacy-gate.json');
  assert(entries.last.gateId == null);

  assert(externalValidationGateIndexEntriesFromJson({}).isEmpty);
  assert(
    externalValidationGateIndexEntriesFromJson({
      'files': 'not a list',
    }).isEmpty,
  );
}

void testLatestExternalValidationGateIndexEntriesReadNewestFile() {
  final directory = Directory.systemTemp.createTempSync(
    'bleunlock_external_gate_index_latest_test_',
  );
  try {
    File(
      '${directory.path}/'
      'bleunlock-external-gate-index-validation-manual-001-20260530T120000Z.json',
    ).writeAsStringSync(
      jsonEncode({
        'files': [
          {
            'type': 'externalValidationGate',
            'path': '/tmp/windows-build-old.json',
            'gateId': 'windowsBuild',
            'gateLabel': 'Windows build verification',
            'status': 'failed',
          },
        ],
      }),
    );
    File(
      '${directory.path}/'
      'bleunlock-external-gate-index-validation-manual-001-20260530T121000Z.json',
    ).writeAsStringSync(
      jsonEncode({
        'files': [
          {
            'type': 'externalValidationGate',
            'path': '/tmp/windows-build-new.json',
            'gateId': 'windowsBuild',
            'gateLabel': 'Windows build verification',
            'status': 'passed',
          },
          {
            'type': 'externalValidationGate',
            'path': '/tmp/real-ble-scan.json',
            'gateId': 'realBleScan',
            'gateLabel': 'Real BLE scan',
            'status': 'passed',
          },
        ],
      }),
    );
    File(
      '${directory.path}/'
      'bleunlock-external-gate-index-other-session-20260530T122000Z.json',
    ).writeAsStringSync(
      jsonEncode({
        'files': [
          {
            'path': '/tmp/other-session.json',
            'gateId': 'other',
          },
        ],
      }),
    );

    final entries = latestExternalValidationGateIndexEntries(
      directory: directory,
      validationSessionId: 'validation-manual-001',
    );

    assert(entries.length == 2);
    final windowsBuild = entries.singleWhere(
      (entry) => entry.gateId == 'windowsBuild',
    );
    final realBleScan = entries.singleWhere(
      (entry) => entry.gateId == 'realBleScan',
    );
    assert(windowsBuild.path == '/tmp/windows-build-new.json');
    assert(windowsBuild.status == 'passed');
    assert(realBleScan.path == '/tmp/real-ble-scan.json');
  } finally {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}

void
    testLatestExternalValidationGateIndexEntriesIgnoreMissingAndMalformedInput() {
  final missingDirectory = Directory(
    '${Directory.systemTemp.path}/bleunlock_missing_index_directory',
  );
  assert(
    latestExternalValidationGateIndexEntries(
      directory: missingDirectory,
      validationSessionId: 'validation-manual-001',
    ).isEmpty,
  );

  final directory = Directory.systemTemp.createTempSync(
    'bleunlock_external_gate_index_malformed_test_',
  );
  try {
    assert(
      latestExternalValidationGateIndexEntries(
        directory: directory,
        validationSessionId: 'validation-manual-001',
      ).isEmpty,
    );
    File(
      '${directory.path}/'
      'bleunlock-external-gate-index-validation-manual-001-20260530T120000Z.json',
    ).writeAsStringSync('not json');

    assert(
      latestExternalValidationGateIndexEntries(
        directory: directory,
        validationSessionId: 'validation-manual-001',
      ).isEmpty,
    );
  } finally {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}

void testMissingActionsDocumentIncludesRelatedFilesAndGateStatuses() {
  final document = buildMissingActionsDocument(
    validationSessionId: 'validation-manual-001',
    missingActionList: [
      'Lock and wake: Move the selected device away',
      'Tray menu: Use every tray action',
    ].join('\n'),
    exportDirectoryPath: '/tmp/bleunlock-validation',
    environment: const AcceptanceBundleEnvironment(
      exportSource: 'validationSection',
      platform: 'macos',
      operatingSystemVersion: 'Version 26.3.1',
      dartVersion: 'Dart test',
      buildMode: 'debug',
    ),
    externalGateStatuses: const {
      'windowsBuild': ExternalValidationGateStatus.passed,
      'realBleScan': ExternalValidationGateStatus.failed,
    },
    externalGateRecords: const {
      'windowsBuild': ExternalValidationGateRecord(
        status: ExternalValidationGateStatus.passed,
        result: 'Built on Windows 11 ARM64',
        evidence: 'bleunlock-windows-build.log',
        notes: 'WinRT linkage verified',
      ),
    },
    exportedAt: DateTime.utc(2026, 5, 30, 12),
  );

  assert(document.contains('validationSessionId: validation-manual-001'));
  assert(document.contains('exportedAt: 2026-05-30T12:00:00.000Z'));
  assert(document.contains('platform: macos'));
  assert(document.contains('operatingSystemVersion: Version 26.3.1'));
  assert(document.contains('buildMode: debug'));
  assert(document.contains('  exportDirectory: /tmp/bleunlock-validation'));
  assert(
    document.contains(
      '  diagnostics: bleunlock-diagnostics-validation-manual-001-*.jsonl',
    ),
  );
  assert(document.contains('1. Lock and wake: Move the selected device away'));
  assert(document.contains('2. Tray menu: Use every tray action'));
  assert(document.contains('1. Windows build verification\n   status: passed'));
  assert(document.contains('   result: Built on Windows 11 ARM64'));
  assert(document.contains('   evidence: bleunlock-windows-build.log'));
  assert(document.contains('   notes: WinRT linkage verified'));
  assert(document.contains('2. Real BLE scan\n   status: failed'));
  assert(document.contains('5. Tray actions\n   status: manualRequired'));
}

void testValidationManifestExportsFileIndexAndGateStatuses() {
  final manifest = buildValidationManifestJson(
    validationSessionId: 'validation-manual-001',
    exportedAt: DateTime.utc(2026, 5, 30, 12, 30),
    exportDirectoryPath: '/tmp/bleunlock-validation',
    readyForAcceptance: false,
    missingRequiredEvidenceCount: 3,
    missingRequiredChecklistLabels: const [
      'Auto lock action',
      'Wake action',
    ],
    missingActionList: 'Lock and wake: Move the selected device away',
    environment: const AcceptanceBundleEnvironment(
      exportSource: 'validationSection',
      platform: 'macos',
      operatingSystemVersion: 'Version 26.3.1',
      dartVersion: 'Dart test',
      buildMode: 'debug',
    ),
    externalGateStatuses: const {
      'windowsBuild': ExternalValidationGateStatus.passed,
    },
    externalGateRecords: const {
      'windowsBuild': ExternalValidationGateRecord(
        status: ExternalValidationGateStatus.passed,
        result: 'Built on Windows 11 ARM64',
        evidence: 'bleunlock-windows-build.log',
        notes: 'WinRT linkage verified',
      ),
    },
    files: const [
      ValidationEvidenceFileIndexEntry(
        type: 'diagnostics',
        path: '/tmp/bleunlock-validation/bleunlock-diagnostics.jsonl',
      ),
      ValidationEvidenceFileIndexEntry(
        type: 'acceptance',
        path: '/tmp/bleunlock-validation/bleunlock-acceptance.json',
      ),
    ],
  );

  assert(manifest['schemaVersion'] == 1);
  assert(manifest['bundleType'] == 'validationManifest');
  assert(manifest['validationSessionId'] == 'validation-manual-001');
  assert(manifest['exportedAt'] == '2026-05-30T12:30:00.000Z');
  assert(manifest['exportDirectory'] == '/tmp/bleunlock-validation');
  assert(manifest['fileCount'] == 2);
  assert(manifest['readyForAcceptance'] == false);
  assert(manifest['missingRequiredEvidenceCount'] == 3);
  assert(
    (manifest['missingRequiredChecklistLabels'] as List<Object?>)
        .contains('Auto lock action'),
  );
  assert(
    manifest['missingActionList'] ==
        'Lock and wake: Move the selected device away',
  );
  final externalGateSummary =
      manifest['externalValidationGateSummary'] as Map<String, Object?>;
  assert(externalGateSummary['totalCount'] == 6);
  assert(externalGateSummary['passedCount'] == 1);
  assert(externalGateSummary['failedCount'] == 0);
  assert(externalGateSummary['manualRequiredCount'] == 5);
  assert(externalGateSummary['completedCount'] == 1);
  assert(externalGateSummary['incompleteCount'] == 5);
  assert(externalGateSummary['hasFailures'] == false);
  assert(externalGateSummary['allResolved'] == false);
  assert(manifest['overallReadyForAcceptance'] == false);
  assert(manifest['overallAcceptanceBlockers'] == 7);
  assert(
    (manifest['overallAcceptanceBlockerLabels'] as List<Object?>)
        .contains('Runtime evidence missing: Auto lock action'),
  );
  assert(
    (manifest['overallAcceptanceBlockerLabels'] as List<Object?>)
        .contains('External gate pending: Real BLE scan'),
  );

  final externalGates = manifest['externalValidationGates'] as List<Object?>;
  final windowsBuild = externalGates.cast<Map<String, Object?>>().singleWhere(
        (gate) => gate['id'] == 'windowsBuild',
      );
  assert(windowsBuild['status'] == 'passed');
  assert(windowsBuild['result'] == 'Built on Windows 11 ARM64');
  assert(windowsBuild['evidence'] == 'bleunlock-windows-build.log');
  assert(windowsBuild['notes'] == 'WinRT linkage verified');

  final files = manifest['files'] as List<Object?>;
  final diagnostics = files.cast<Map<String, Object?>>().first;
  assert(diagnostics['type'] == 'diagnostics');
  assert(diagnostics['filename'] == 'bleunlock-diagnostics.jsonl');
  assert(diagnostics['validationSessionId'] == 'validation-manual-001');
}

void testValidationEvidenceExporterWritesCompleteBundle() {
  final directory = Directory.systemTemp.createTempSync(
    'bleunlock_validation_exporter_test_',
  );
  try {
    final exporter = ValidationEvidenceExporter(
      clock: () => DateTime.utc(2026, 5, 30, 13),
    );
    final result = exporter.export(
      directory: directory,
      validationSessionId: 'validation-manual-001',
      diagnosticsJsonLines: '{"validationSessionId":"validation-manual-001"}',
      acceptanceBundleJson: const {
        'schemaVersion': 1,
        'bundleType': 'acceptance',
        'validationSessionId': 'validation-manual-001',
      },
      runbookBundleJson: const {
        'schemaVersion': 1,
        'bundleType': 'validationRunbook',
        'validationSessionId': 'validation-manual-001',
      },
      missingActionsDocument: 'validationSessionId: validation-manual-001',
      manifestJson: (files) => buildValidationManifestJson(
        validationSessionId: 'validation-manual-001',
        exportedAt: DateTime.utc(2026, 5, 30, 13),
        exportDirectoryPath: directory.path,
        readyForAcceptance: false,
        missingRequiredEvidenceCount: 1,
        missingRequiredChecklistLabels: const ['Auto lock action'],
        missingActionList: 'Lock and wake: Move the selected device away',
        environment: const AcceptanceBundleEnvironment(
          exportSource: 'validationSection',
          platform: 'macos',
          operatingSystemVersion: 'Version 26.3.1',
          dartVersion: 'Dart test',
          buildMode: 'debug',
        ),
        externalGateStatuses: const {
          'windowsBuild': ExternalValidationGateStatus.passed,
        },
        files: files,
      ),
    );

    assert(result.files.length == 5);
    assert(result.diagnostics.path.endsWith('.jsonl'));
    assert(result.acceptance.path.endsWith('.json'));
    assert(result.runbook.path.endsWith('.json'));
    assert(result.missingActions.path.endsWith('.txt'));
    assert(result.manifest.path.endsWith('.json'));
    assert(result.evidenceFiles.length == 4);
    assert(result.evidenceFiles.map((file) => file.type).join(',') ==
        'diagnostics,acceptance,runbook,missingActions');

    final manifest =
        jsonDecode(result.manifest.readAsStringSync()) as Map<String, Object?>;
    assert(manifest['bundleType'] == 'validationManifest');
    assert(manifest['fileCount'] == 4);

    final files = manifest['files'] as List<Object?>;
    assert(files.length == 4);
    assert(
      files.every(
        (entry) =>
            ((entry as Map<String, Object?>)['path'] as String)
                .startsWith(directory.path) &&
            entry['validationSessionId'] == 'validation-manual-001',
      ),
    );

    final diagnostics = result.diagnostics.readAsStringSync();
    assert(diagnostics.endsWith('\n'));
    assert(
        diagnostics.contains('"validationSessionId":"validation-manual-001"'));
  } finally {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}

void testValidationEvidenceExporterWritesSingleJsonAndTextFiles() {
  final directory = Directory.systemTemp.createTempSync(
    'bleunlock_validation_single_export_test_',
  );
  try {
    final exporter = ValidationEvidenceExporter(
      clock: () => DateTime.utc(2026, 5, 30, 14),
    );

    final jsonFile = exporter.writeJson(
      directory: directory,
      prefix: 'bleunlock-acceptance-validation-manual-001',
      json: const {
        'bundleType': 'acceptance',
        'validationSessionId': 'validation-manual-001',
      },
    );
    final textFile = exporter.writeText(
      directory: directory,
      prefix: 'bleunlock-missing-actions-validation-manual-001',
      text: 'validationSessionId: validation-manual-001',
    );

    assert(jsonFile.path.endsWith('20260530T140000000Z.json'));
    assert(textFile.path.endsWith('20260530T140000000Z.txt'));
    assert(jsonFile.readAsStringSync().endsWith('\n'));
    assert(textFile.readAsStringSync().endsWith('\n'));

    final json =
        jsonDecode(jsonFile.readAsStringSync()) as Map<String, Object?>;
    assert(json['bundleType'] == 'acceptance');
    assert(textFile.readAsStringSync().contains('validationSessionId'));
  } finally {
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }
}
