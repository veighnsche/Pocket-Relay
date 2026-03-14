import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_models.dart';
import 'codex_json_rpc_codec.dart';

class CodexAppServerConnection {
  CodexAppServerConnection({
    required CodexAppServerProcessLauncher processLauncher,
    required CodexJsonRpcCodec jsonRpcCodec,
    required CodexJsonRpcRequestTracker requestTracker,
    required CodexJsonRpcInboundRequestStore inboundRequestStore,
    required this.clientName,
    required this.clientVersion,
  }) : _processLauncher = processLauncher,
       _jsonRpcCodec = jsonRpcCodec,
       _requestTracker = requestTracker,
       _inboundRequestStore = inboundRequestStore;

  final CodexAppServerProcessLauncher _processLauncher;
  final CodexJsonRpcCodec _jsonRpcCodec;
  final CodexJsonRpcRequestTracker _requestTracker;
  final CodexJsonRpcInboundRequestStore _inboundRequestStore;
  final String clientName;
  final String clientVersion;

  final _eventsController = StreamController<CodexAppServerEvent>.broadcast();

  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  CodexAppServerProcess? _process;
  ConnectionProfile? _profile;
  bool _disconnecting = false;
  String? _threadId;
  String? _activeTurnId;

  Stream<CodexAppServerEvent> get events => _eventsController.stream;
  bool get isConnected => _process != null;
  String? get threadId => _threadId;
  String? get activeTurnId => _activeTurnId;

  Future<void> connect({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    if (isConnected) {
      await disconnect();
    }

    _disconnecting = false;

    try {
      final process = await _processLauncher(
        profile: profile,
        secrets: secrets,
        emitEvent: _emitEvent,
      );

      _process = process;
      _profile = profile;
      _stdoutSubscription = _decodeLines(process.stdout).listen(
        _handleStdoutLine,
        onError: (Object error, StackTrace stackTrace) {
          _emitEvent(
            CodexAppServerDiagnosticEvent(
              message: 'Failed to decode app-server stdout: $error',
              isError: true,
            ),
          );
        },
        onDone: _handleProcessClosed,
      );
      _stderrSubscription = _decodeLines(process.stderr).listen((line) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          return;
        }

        _emitEvent(
          CodexAppServerDiagnosticEvent(message: trimmed, isError: true),
        );
      });

      process.done.then((_) {
        if (!_disconnecting) {
          _handleProcessClosed();
        }
      });

      final initializeResponse = await sendRequest(
        'initialize',
        <String, Object?>{
          'clientInfo': <String, String>{
            'name': clientName,
            'title': 'Pocket Relay',
            'version': clientVersion,
          },
          'capabilities': const <String, bool>{'experimentalApi': true},
        },
      ).timeout(const Duration(seconds: 10));

      writeMessage(const CodexJsonRpcNotification(method: 'initialized'));
      final payload = _asObject(initializeResponse);
      _emitEvent(
        CodexAppServerConnectedEvent(
          userAgent: _asString(payload?['userAgent']),
        ),
      );
    } catch (error) {
      await _disconnect(emitDisconnectedEvent: false);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _disconnect(emitDisconnectedEvent: true);
  }

  Future<Object?> sendRequest(String method, Object? params) {
    requireConnected();

    final trackedRequest = _requestTracker.createRequest(
      method,
      params: params,
    );
    writeMessage(trackedRequest.request);
    return trackedRequest.response.then<Object?>(
      (value) => value,
      onError: (Object error, StackTrace stackTrace) {
        if (error is CodexJsonRpcRemoteException) {
          throw CodexAppServerException(
            error.error.message,
            code: error.error.code,
            data: error.error.data,
          );
        }
        throw error;
      },
    );
  }

  Future<void> sendServerResult({
    required String requestId,
    required Object? result,
  }) async {
    final pending = _inboundRequestStore.take(requestId);
    if (pending == null) {
      throw CodexAppServerException(
        'Unknown pending server request: $requestId',
      );
    }

    writeMessage(CodexJsonRpcResponse.success(id: pending.id, result: result));
  }

  Future<void> rejectServerRequest({
    required String requestId,
    required String message,
    int code = -32000,
    Object? data,
  }) async {
    final pending = _inboundRequestStore.take(requestId);
    if (pending == null) {
      throw CodexAppServerException(
        'Unknown pending server request: $requestId',
      );
    }

    writeMessage(
      CodexJsonRpcResponse.failure(
        id: pending.id,
        error: CodexJsonRpcError(message: message, code: code, data: data),
      ),
    );
  }

  ConnectionProfile requireProfile() {
    final profile = _profile;
    if (profile == null) {
      throw const CodexAppServerException(
        'Connect to app-server before starting a session.',
      );
    }
    return profile;
  }

  void requireConnected() {
    if (_process == null) {
      throw const CodexAppServerException('App-server is not connected.');
    }
  }

  CodexJsonRpcRequest requirePendingServerRequest(String requestId) {
    final pending = _inboundRequestStore.lookup(requestId);
    if (pending == null) {
      throw CodexAppServerException(
        'Unknown pending server request: $requestId',
      );
    }
    return pending;
  }

  void setTrackedThread(String? threadId) {
    _threadId = threadId;
    _activeTurnId = null;
  }

  void setTrackedTurn({required String threadId, required String turnId}) {
    _threadId = threadId;
    _activeTurnId = turnId;
  }

  Future<void> _disconnect({required bool emitDisconnectedEvent}) async {
    _disconnecting = true;

    final process = _process;
    _process = null;
    _profile = null;
    _threadId = null;
    _activeTurnId = null;

    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;

    _requestTracker.failPending(
      const CodexAppServerException('App-server session disconnected.'),
    );
    _inboundRequestStore.clear();

    if (process != null) {
      final exitCode = process.exitCode;
      await process.close();
      if (emitDisconnectedEvent) {
        _emitEvent(CodexAppServerDisconnectedEvent(exitCode: exitCode));
      }
    }
  }

  void _handleStdoutLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return;
    }

    switch (_jsonRpcCodec.decodeLine(trimmed)) {
      case CodexJsonRpcMalformedMessage(:final problem):
        _emitEvent(
          CodexAppServerDiagnosticEvent(
            message: 'Malformed app-server message: $problem',
            isError: true,
          ),
        );
      case CodexJsonRpcDecodedMessage(:final message):
        switch (message) {
          case CodexJsonRpcRequest():
            _inboundRequestStore.remember(message);
            _emitEvent(
              CodexAppServerRequestEvent(
                requestId: message.id.token,
                method: message.method,
                params: message.params,
              ),
            );
          case CodexJsonRpcNotification():
            _updateRuntimePointers(message.method, message.params);
            _emitEvent(
              CodexAppServerNotificationEvent(
                method: message.method,
                params: message.params,
              ),
            );
          case CodexJsonRpcResponse():
            if (_requestTracker.completeResponse(message)) {
              return;
            }

            _emitEvent(
              CodexAppServerDiagnosticEvent(
                message:
                    'Received response for unknown request ${message.id.displayValue}.',
                isError: false,
              ),
            );
        }
    }
  }

  void _updateRuntimePointers(String method, Object? params) {
    final payload = _asObject(params);
    switch (method) {
      case 'session/exited':
      case 'session/closed':
        _threadId = null;
        _activeTurnId = null;
        break;
      case 'thread/started':
        final thread = _asObject(payload?['thread']);
        _threadId = _asString(thread?['id']) ?? _asString(payload?['threadId']);
        _activeTurnId = null;
        break;
      case 'thread/closed':
        final threadId = _asString(payload?['threadId']);
        if (threadId == null || threadId == _threadId) {
          _threadId = null;
          _activeTurnId = null;
        }
        break;
      case 'turn/started':
        _threadId = _asString(payload?['threadId']) ?? _threadId;
        final turn = _asObject(payload?['turn']);
        _activeTurnId = _asString(turn?['id']) ?? _asString(payload?['turnId']);
        break;
      case 'turn/completed':
      case 'turn/aborted':
        final turn = _asObject(payload?['turn']);
        final turnId = _asString(turn?['id']) ?? _asString(payload?['turnId']);
        if (turnId == null || turnId == _activeTurnId) {
          _activeTurnId = null;
        }
        break;
    }
  }

  void _handleProcessClosed() {
    if (_process == null) {
      return;
    }
    unawaited(_disconnect(emitDisconnectedEvent: true));
  }

  void writeMessage(CodexJsonRpcMessage message) {
    final process = _process;
    if (process == null) {
      throw const CodexAppServerException('App-server is not connected.');
    }

    final line = _jsonRpcCodec.encodeLine(message);
    process.stdin.add(Uint8List.fromList(utf8.encode(line)));
  }

  void _emitEvent(CodexAppServerEvent event) {
    if (!_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  Stream<String> _decodeLines(Stream<Uint8List> stream) {
    return stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
  }

  static Map<String, dynamic>? _asObject(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }
}
