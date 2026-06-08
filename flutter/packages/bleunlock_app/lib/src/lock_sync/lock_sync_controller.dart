import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bleunlock_app/src/lock_sync/lock_sync_models.dart';
import 'package:crypto/crypto.dart';

const int _protocolVersion = 1;
const String _path = '/bleunlock-lock-sync';
const Duration _messageMaxAge = Duration(minutes: 2);
const Duration _messageFutureSkew = Duration(seconds: 30);
const Duration _clientReconnectDelay = Duration(seconds: 3);
const Duration _connectTimeout = Duration(seconds: 5);
const int _seenEventLimit = 256;

enum LockSyncControllerEventKind {
  statusChanged,
  action,
  error,
  remoteLockRequested,
}

class LockSyncControllerEvent {
  const LockSyncControllerEvent({
    required this.kind,
    required this.timestamp,
    required this.message,
    this.reason,
  });

  final LockSyncControllerEventKind kind;
  final DateTime timestamp;
  final String message;
  final String? reason;
}

class LockSyncController {
  LockSyncController({String? nodeId}) : _nodeId = nodeId ?? _createNodeId();

  final String _nodeId;
  final StreamController<LockSyncControllerEvent> _events =
      StreamController<LockSyncControllerEvent>.broadcast();
  final Set<WebSocket> _serverClients = {};
  final Set<String> _seenEventIds = {};
  final List<String> _seenEventOrder = [];

  LockSyncConfig _config = const LockSyncConfig();
  LockSyncSnapshot _snapshot = const LockSyncSnapshot.initial();
  HttpServer? _server;
  WebSocket? _clientSocket;
  Timer? _clientReconnectTimer;
  int _eventCounter = 0;
  bool _isDisposed = false;
  bool _isConnectingClient = false;

  Stream<LockSyncControllerEvent> get events => _events.stream;

  LockSyncSnapshot get snapshot => _snapshot;

  Future<void> updateConfig(LockSyncConfig config) async {
    if (_isDisposed) {
      return;
    }

    await _stopTransport();
    _config = config;
    _updateSnapshot(
      LockSyncSnapshot(config: config),
      emitStatus: true,
    );

    if (!config.isEnabled) {
      return;
    }
    if (!config.canStart) {
      _updateSnapshot(
        _snapshot.copyWith(
          runtimeState: LockSyncRuntimeState.stopped,
          lastError: _configProblemLabel(config),
        ),
        emitStatus: true,
      );
      return;
    }

    switch (config.role) {
      case LockSyncRole.disabled:
        return;
      case LockSyncRole.server:
        await _startServer(config);
      case LockSyncRole.client:
        await _startClient(config);
    }
  }

  Future<void> broadcastLock({
    required String reason,
    required DateTime timestamp,
  }) async {
    if (_isDisposed ||
        _config.role != LockSyncRole.server ||
        _serverClients.isEmpty) {
      return;
    }

    final message = _signedMessage(
      type: 'lockRequested',
      reason: reason,
      target: 'all',
      issuedAt: timestamp,
    );
    final encoded = jsonEncode(message);
    final clients = _serverClients.toList(growable: false);
    var sentCount = 0;
    for (final client in clients) {
      if (client.readyState != WebSocket.open) {
        _serverClients.remove(client);
        continue;
      }
      client.add(encoded);
      sentCount += 1;
    }
    _updateSnapshot(
      _snapshot.copyWith(
        connectedClientCount: _serverClients.length,
        lastEventLabel: 'lockRequested:$reason',
        clearLastError: true,
      ),
      emitStatus: true,
    );
    if (sentCount > 0) {
      _emit(
        LockSyncControllerEventKind.action,
        'Lock sync event sent',
        reason: reason,
        timestamp: timestamp,
      );
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await _stopTransport();
    await _events.close();
  }

  Future<void> _startServer(LockSyncConfig config) async {
    _updateSnapshot(
      _snapshot.copyWith(
        runtimeState: LockSyncRuntimeState.starting,
        clearLastError: true,
      ),
      emitStatus: true,
    );
    try {
      final server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        config.port,
      );
      _server = server;
      server.listen(
        _handleHttpRequest,
        onError: (Object error) {
          _fail('Lock sync server failed', error);
        },
        cancelOnError: false,
      );
      _updateSnapshot(
        _snapshot.copyWith(
          runtimeState: LockSyncRuntimeState.listening,
          clearLastError: true,
        ),
        emitStatus: true,
      );
      _emit(
        LockSyncControllerEventKind.action,
        'Lock sync server listening',
        reason: 'serverStarted',
      );
    } catch (error) {
      _fail('Lock sync server start failed', error);
    }
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    if (request.uri.path != _path ||
        !WebSocketTransformer.isUpgradeRequest(
          request,
        )) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    try {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.pingInterval = const Duration(seconds: 15);
      _handleServerSocket(socket);
    } catch (error) {
      _emit(
        LockSyncControllerEventKind.error,
        'Lock sync client upgrade failed: $error',
        reason: 'upgradeFailed',
      );
    }
  }

  void _handleServerSocket(WebSocket socket) {
    var isAuthenticated = false;
    late StreamSubscription<dynamic> subscription;
    subscription = socket.listen(
      (message) {
        if (isAuthenticated) {
          return;
        }
        final payload = _decodeMessage(message);
        final validation = _validateMessage(
          payload,
          expectedType: 'hello',
          rememberEvent: true,
        );
        if (!validation.isValid) {
          socket.close(WebSocketStatus.policyViolation, validation.reason);
          return;
        }
        isAuthenticated = true;
        _serverClients.add(socket);
        socket.add(jsonEncode(_signedMessage(type: 'helloAccepted')));
        _updateSnapshot(
          _snapshot.copyWith(
            connectedClientCount: _serverClients.length,
            lastEventLabel: 'clientConnected',
            clearLastError: true,
          ),
          emitStatus: true,
        );
        _emit(
          LockSyncControllerEventKind.action,
          'Lock sync client connected',
          reason: 'clientConnected',
        );
      },
      onDone: () {
        unawaited(subscription.cancel());
        if (_serverClients.remove(socket)) {
          _updateSnapshot(
            _snapshot.copyWith(
              connectedClientCount: _serverClients.length,
              lastEventLabel: 'clientDisconnected',
            ),
            emitStatus: true,
          );
        }
      },
      onError: (Object error) {
        _serverClients.remove(socket);
        _updateSnapshot(
          _snapshot.copyWith(
            connectedClientCount: _serverClients.length,
            lastError: 'client socket failed',
          ),
          emitStatus: true,
        );
        _emit(
          LockSyncControllerEventKind.error,
          'Lock sync client socket failed: $error',
          reason: 'clientSocketFailed',
        );
      },
      cancelOnError: true,
    );
  }

  Future<void> _startClient(LockSyncConfig config) async {
    if (_isDisposed || _isConnectingClient) {
      return;
    }
    _isConnectingClient = true;
    _updateSnapshot(
      _snapshot.copyWith(
        runtimeState: LockSyncRuntimeState.connecting,
        clearLastError: true,
      ),
      emitStatus: true,
    );
    try {
      final uri = Uri(
        scheme: 'ws',
        host: config.serverHost.trim(),
        port: config.port,
        path: _path,
      );
      final socket = await WebSocket.connect(uri.toString()).timeout(
        _connectTimeout,
      );
      if (_isDisposed || _config != config) {
        await socket.close();
        return;
      }
      socket.pingInterval = const Duration(seconds: 15);
      _clientSocket = socket;
      socket.add(jsonEncode(_signedMessage(type: 'hello')));
      _handleClientSocket(socket);
    } catch (error) {
      _updateSnapshot(
        _snapshot.copyWith(
          runtimeState: LockSyncRuntimeState.failed,
          lastError: error.toString(),
        ),
        emitStatus: true,
      );
      _emit(
        LockSyncControllerEventKind.error,
        'Lock sync client connect failed: $error',
        reason: 'clientConnectFailed',
      );
      _scheduleClientReconnect();
    } finally {
      _isConnectingClient = false;
    }
  }

  void _handleClientSocket(WebSocket socket) {
    socket.listen(
      (message) {
        final payload = _decodeMessage(message);
        if (payload == null) {
          _emit(
            LockSyncControllerEventKind.error,
            'Lock sync event rejected: invalid json',
            reason: 'eventRejected',
          );
          return;
        }
        final type = payload['type'];
        if (type == 'helloAccepted') {
          final validation = _validateMessage(
            payload,
            expectedType: 'helloAccepted',
            rememberEvent: true,
          );
          if (!validation.isValid) {
            socket.close(WebSocketStatus.policyViolation, validation.reason);
            return;
          }
          _updateSnapshot(
            _snapshot.copyWith(
              runtimeState: LockSyncRuntimeState.connected,
              lastEventLabel: 'serverConnected',
              clearLastError: true,
            ),
            emitStatus: true,
          );
          _emit(
            LockSyncControllerEventKind.action,
            'Lock sync server connected',
            reason: 'serverConnected',
          );
          return;
        }
        if (type == 'lockRequested') {
          final validation = _validateMessage(
            payload,
            expectedType: 'lockRequested',
            rememberEvent: true,
          );
          if (!validation.isValid) {
            _emit(
              LockSyncControllerEventKind.error,
              'Lock sync event rejected: ${validation.reason}',
              reason: 'eventRejected',
            );
            return;
          }
          final reason = _stringValue(payload['reason']) ?? 'remoteLock';
          _updateSnapshot(
            _snapshot.copyWith(
              lastEventLabel: 'lockRequested:$reason',
              clearLastError: true,
            ),
            emitStatus: true,
          );
          _emit(
            LockSyncControllerEventKind.remoteLockRequested,
            'Remote lock requested',
            reason: reason,
          );
        }
      },
      onDone: () {
        if (_clientSocket == socket) {
          _clientSocket = null;
          _updateSnapshot(
            _snapshot.copyWith(
              runtimeState: LockSyncRuntimeState.connecting,
              lastEventLabel: 'serverDisconnected',
            ),
            emitStatus: true,
          );
          _scheduleClientReconnect();
        }
      },
      onError: (Object error) {
        if (_clientSocket == socket) {
          _clientSocket = null;
        }
        _updateSnapshot(
          _snapshot.copyWith(
            runtimeState: LockSyncRuntimeState.failed,
            lastError: error.toString(),
          ),
          emitStatus: true,
        );
        _emit(
          LockSyncControllerEventKind.error,
          'Lock sync client socket failed: $error',
          reason: 'clientSocketFailed',
        );
        _scheduleClientReconnect();
      },
      cancelOnError: true,
    );
  }

  void _scheduleClientReconnect() {
    if (_isDisposed ||
        _config.role != LockSyncRole.client ||
        !_config.canStart ||
        _clientReconnectTimer != null) {
      return;
    }
    _clientReconnectTimer = Timer(_clientReconnectDelay, () {
      _clientReconnectTimer = null;
      unawaited(_startClient(_config));
    });
  }

  Future<void> _stopTransport() async {
    _clientReconnectTimer?.cancel();
    _clientReconnectTimer = null;
    final clientSocket = _clientSocket;
    _clientSocket = null;
    if (clientSocket != null) {
      await clientSocket.close();
    }
    for (final socket in _serverClients.toList(growable: false)) {
      await socket.close();
    }
    _serverClients.clear();
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
  }

  void _fail(String label, Object error) {
    _updateSnapshot(
      _snapshot.copyWith(
        runtimeState: LockSyncRuntimeState.failed,
        lastError: error.toString(),
      ),
      emitStatus: true,
    );
    _emit(
      LockSyncControllerEventKind.error,
      '$label: $error',
      reason: 'lockSyncFailed',
    );
  }

  Map<String, Object?> _signedMessage({
    required String type,
    String reason = '',
    String target = '',
    DateTime? issuedAt,
  }) {
    final payload = <String, Object?>{
      'protocolVersion': _protocolVersion,
      'type': type,
      'senderId': _nodeId,
      'eventId': _nextEventId(),
      'issuedAt': (issuedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'reason': reason,
      'target': target,
    };
    payload['signature'] = _signature(payload);
    return payload;
  }

  _ValidationResult _validateMessage(
    Map<String, Object?>? payload, {
    required String expectedType,
    required bool rememberEvent,
  }) {
    if (payload == null) {
      return const _ValidationResult(false, 'invalid json');
    }
    if (payload['protocolVersion'] != _protocolVersion) {
      return const _ValidationResult(false, 'unsupported protocol');
    }
    if (payload['type'] != expectedType) {
      return const _ValidationResult(false, 'unexpected message type');
    }
    final eventId = _stringValue(payload['eventId']);
    if (eventId == null) {
      return const _ValidationResult(false, 'missing event id');
    }
    if (_seenEventIds.contains(eventId)) {
      return const _ValidationResult(false, 'replayed event');
    }
    final signature = _stringValue(payload['signature']);
    if (signature == null || signature != _signature(payload)) {
      return const _ValidationResult(false, 'bad signature');
    }
    final issuedAtText = _stringValue(payload['issuedAt']);
    final issuedAt = issuedAtText == null
        ? null
        : DateTime.tryParse(
            issuedAtText,
          );
    if (issuedAt == null) {
      return const _ValidationResult(false, 'bad timestamp');
    }
    final now = DateTime.now().toUtc();
    final utcIssuedAt = issuedAt.toUtc();
    if (utcIssuedAt.isAfter(now.add(_messageFutureSkew))) {
      return const _ValidationResult(false, 'timestamp is in the future');
    }
    if (now.difference(utcIssuedAt) > _messageMaxAge) {
      return const _ValidationResult(false, 'expired event');
    }
    if (rememberEvent) {
      _rememberEvent(eventId);
    }
    return const _ValidationResult(true, 'ok');
  }

  String _signature(Map<String, Object?> payload) {
    final secret = utf8.encode(_config.sharedSecret.trim());
    final hmac = Hmac(sha256, secret);
    return hmac.convert(utf8.encode(_canonicalPayload(payload))).toString();
  }

  String _canonicalPayload(Map<String, Object?> payload) {
    const keys = [
      'protocolVersion',
      'type',
      'senderId',
      'eventId',
      'issuedAt',
      'reason',
      'target',
    ];
    return keys.map((key) => '$key=${payload[key] ?? ''}').join('\n');
  }

  Map<String, Object?>? _decodeMessage(dynamic message) {
    if (message is! String) {
      return null;
    }
    try {
      final decoded = jsonDecode(message);
      return decoded is Map ? decoded.cast<String, Object?>() : null;
    } on FormatException {
      return null;
    }
  }

  void _rememberEvent(String eventId) {
    _seenEventIds.add(eventId);
    _seenEventOrder.add(eventId);
    while (_seenEventOrder.length > _seenEventLimit) {
      _seenEventIds.remove(_seenEventOrder.removeAt(0));
    }
  }

  String _nextEventId() {
    _eventCounter += 1;
    return '$_nodeId-${DateTime.now().microsecondsSinceEpoch}-$_eventCounter';
  }

  void _updateSnapshot(
    LockSyncSnapshot snapshot, {
    required bool emitStatus,
  }) {
    _snapshot = snapshot;
    if (emitStatus) {
      _emit(
        LockSyncControllerEventKind.statusChanged,
        'Lock sync status changed',
        reason: _snapshot.statusLabel,
      );
    }
  }

  void _emit(
    LockSyncControllerEventKind kind,
    String message, {
    String? reason,
    DateTime? timestamp,
  }) {
    if (_events.isClosed) {
      return;
    }
    _events.add(
      LockSyncControllerEvent(
        kind: kind,
        timestamp: timestamp ?? DateTime.now(),
        message: message,
        reason: reason,
      ),
    );
  }
}

class _ValidationResult {
  const _ValidationResult(this.isValid, this.reason);

  final bool isValid;
  final String reason;
}

String _configProblemLabel(LockSyncConfig config) {
  if (!config.hasSharedSecret) {
    return 'missing shared secret';
  }
  if (config.role == LockSyncRole.client && config.serverHost.trim().isEmpty) {
    return 'missing server host';
  }
  return 'invalid config';
}

String _createNodeId() {
  return 'node-${DateTime.now().microsecondsSinceEpoch}';
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
