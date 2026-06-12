enum LockSyncRole {
  disabled,
  server,
  client,
}

extension LockSyncRoleLabel on LockSyncRole {
  String get label {
    switch (this) {
      case LockSyncRole.disabled:
        return 'disabled';
      case LockSyncRole.server:
        return 'server';
      case LockSyncRole.client:
        return 'client';
    }
  }
}

class LockSyncConfig {
  const LockSyncConfig({
    this.role = LockSyncRole.disabled,
    this.serverHost = '',
    this.port = defaultPort,
    this.sharedSecret = '',
    this.syncProximityLocks = true,
    this.syncManualLocks = false,
  });

  factory LockSyncConfig.fromJson(Map<String, Object?> json) {
    return LockSyncConfig(
      role: _roleValue(json['role']),
      serverHost: _stringValue(json['serverHost']) ?? '',
      port: _portValue(json['port']),
      sharedSecret: _stringValue(json['sharedSecret']) ?? '',
      syncProximityLocks: json['syncProximityLocks'] != false,
      syncManualLocks: json['syncManualLocks'] == true,
    );
  }

  static const int defaultPort = 47761;

  final LockSyncRole role;
  final String serverHost;
  final int port;
  final String sharedSecret;
  final bool syncProximityLocks;
  final bool syncManualLocks;

  bool get isEnabled => role != LockSyncRole.disabled;

  bool get isDefault {
    return role == LockSyncRole.disabled &&
        serverHost.trim().isEmpty &&
        port == defaultPort &&
        sharedSecret.trim().isEmpty &&
        syncProximityLocks &&
        !syncManualLocks;
  }

  bool get hasSharedSecret => sharedSecret.trim().isNotEmpty;

  bool get hasClientEndpoint {
    return role == LockSyncRole.client &&
        serverHost.trim().isNotEmpty &&
        _isValidPort(port);
  }

  bool get canStart {
    if (!isEnabled || !hasSharedSecret || !_isValidPort(port)) {
      return false;
    }
    return role == LockSyncRole.server || hasClientEndpoint;
  }

  LockSyncConfig copyWith({
    LockSyncRole? role,
    String? serverHost,
    int? port,
    String? sharedSecret,
    bool? syncProximityLocks,
    bool? syncManualLocks,
  }) {
    return LockSyncConfig(
      role: role ?? this.role,
      serverHost: serverHost ?? this.serverHost,
      port: port ?? this.port,
      sharedSecret: sharedSecret ?? this.sharedSecret,
      syncProximityLocks: syncProximityLocks ?? this.syncProximityLocks,
      syncManualLocks: syncManualLocks ?? this.syncManualLocks,
    );
  }

  Map<String, Object?> toJson({bool includeSharedSecret = true}) {
    return {
      'role': role.name,
      if (serverHost.trim().isNotEmpty) 'serverHost': serverHost.trim(),
      'port': port,
      if (includeSharedSecret && sharedSecret.trim().isNotEmpty)
        'sharedSecret': sharedSecret.trim(),
      'syncProximityLocks': syncProximityLocks,
      'syncManualLocks': syncManualLocks,
    };
  }
}

enum LockSyncRuntimeState {
  stopped,
  starting,
  listening,
  connecting,
  connected,
  failed,
}

extension LockSyncRuntimeStateLabel on LockSyncRuntimeState {
  String get label {
    switch (this) {
      case LockSyncRuntimeState.stopped:
        return 'stopped';
      case LockSyncRuntimeState.starting:
        return 'starting';
      case LockSyncRuntimeState.listening:
        return 'listening';
      case LockSyncRuntimeState.connecting:
        return 'connecting';
      case LockSyncRuntimeState.connected:
        return 'connected';
      case LockSyncRuntimeState.failed:
        return 'failed';
    }
  }
}

class LockSyncSnapshot {
  const LockSyncSnapshot({
    required this.config,
    this.runtimeState = LockSyncRuntimeState.stopped,
    this.connectedClientCount = 0,
    this.lastEventLabel,
    this.lastError,
  });

  const LockSyncSnapshot.initial()
      : config = const LockSyncConfig(),
        runtimeState = LockSyncRuntimeState.stopped,
        connectedClientCount = 0,
        lastEventLabel = null,
        lastError = null;

  final LockSyncConfig config;
  final LockSyncRuntimeState runtimeState;
  final int connectedClientCount;
  final String? lastEventLabel;
  final String? lastError;

  String get roleLabel => config.role.label;

  String get statusLabel {
    if (!config.isEnabled) {
      return 'disabled';
    }
    if (!config.hasSharedSecret) {
      return 'missing shared secret';
    }
    if (config.role == LockSyncRole.client &&
        config.serverHost.trim().isEmpty) {
      return 'missing server host';
    }
    if (lastError != null) {
      return 'failed';
    }
    return runtimeState.label;
  }

  String get endpointLabel {
    switch (config.role) {
      case LockSyncRole.disabled:
        return '--';
      case LockSyncRole.server:
        return '0.0.0.0:${config.port}';
      case LockSyncRole.client:
        final host = config.serverHost.trim();
        return host.isEmpty ? '--' : '$host:${config.port}';
    }
  }

  LockSyncSnapshot copyWith({
    LockSyncConfig? config,
    LockSyncRuntimeState? runtimeState,
    int? connectedClientCount,
    String? lastEventLabel,
    String? lastError,
    bool clearLastError = false,
  }) {
    return LockSyncSnapshot(
      config: config ?? this.config,
      runtimeState: runtimeState ?? this.runtimeState,
      connectedClientCount: connectedClientCount ?? this.connectedClientCount,
      lastEventLabel: lastEventLabel ?? this.lastEventLabel,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toDiagnosticJson() {
    return {
      'role': config.role.name,
      'runtimeState': runtimeState.name,
      'statusLabel': statusLabel,
      'endpointLabel': endpointLabel,
      'connectedClientCount': connectedClientCount,
      'syncProximityLocks': config.syncProximityLocks,
      'syncManualLocks': config.syncManualLocks,
      'hasSharedSecret': config.hasSharedSecret,
      if (lastEventLabel != null) 'lastEventLabel': lastEventLabel,
      if (lastError != null) 'lastError': lastError,
    };
  }
}

bool _isValidPort(int port) => port > 0 && port <= 65535;

LockSyncRole _roleValue(Object? value) {
  for (final role in LockSyncRole.values) {
    if (role.name == value) {
      return role;
    }
  }
  return LockSyncRole.disabled;
}

int _portValue(Object? value) {
  if (value is int && _isValidPort(value)) {
    return value;
  }
  return LockSyncConfig.defaultPort;
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
