import 'package:pocket_relay/src/core/models/connection_models.dart';

export 'codex_app_server_models.dart';

import 'codex_app_server_connection.dart';
import 'codex_app_server_models.dart';
import 'codex_app_server_process_launcher.dart';
import 'codex_app_server_request_api.dart';
import 'codex_json_rpc_codec.dart';

class CodexAppServerClient {
  CodexAppServerClient({
    CodexAppServerProcessLauncher? processLauncher,
    CodexJsonRpcCodec? jsonRpcCodec,
    CodexJsonRpcRequestTracker? requestTracker,
    CodexJsonRpcInboundRequestStore? inboundRequestStore,
    this.clientName = 'pocket_relay',
    this.clientVersion = '1.0.0',
  }) : _connection = CodexAppServerConnection(
         processLauncher: processLauncher ?? openCodexAppServerProcess,
         jsonRpcCodec: jsonRpcCodec ?? const CodexJsonRpcCodec(),
         requestTracker: requestTracker ?? CodexJsonRpcRequestTracker(),
         inboundRequestStore:
             inboundRequestStore ?? CodexJsonRpcInboundRequestStore(),
         clientName: clientName,
         clientVersion: clientVersion,
       );

  final String clientName;
  final String clientVersion;
  final CodexAppServerConnection _connection;
  final CodexAppServerRequestApi _requestApi = const CodexAppServerRequestApi();
  bool _isDisposed = false;

  Stream<CodexAppServerEvent> get events => _connection.events;
  bool get isConnected => _connection.isConnected;
  String? get threadId => _connection.threadId;
  String? get activeTurnId => _connection.activeTurnId;

  Future<void> connect({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    _ensureNotDisposed();
    await _connection.connect(profile: profile, secrets: secrets);
  }

  Future<CodexAppServerSession> startSession({
    String? cwd,
    String? model,
    CodexReasoningEffort? reasoningEffort,
    String? resumeThreadId,
  }) async {
    _ensureNotDisposed();
    return _requestApi.startSession(
      _connection,
      cwd: cwd,
      model: model,
      reasoningEffort: reasoningEffort,
      resumeThreadId: resumeThreadId,
    );
  }

  Future<CodexAppServerThreadSummary> readThread({
    required String threadId,
  }) async {
    _ensureNotDisposed();
    return _requestApi.readThread(_connection, threadId: threadId);
  }

  Future<CodexAppServerThreadHistory> readThreadWithTurns({
    required String threadId,
  }) async {
    _ensureNotDisposed();
    return _requestApi.readThreadWithTurns(_connection, threadId: threadId);
  }

  Future<CodexAppServerThreadHistory> rollbackThread({
    required String threadId,
    required int numTurns,
  }) async {
    _ensureNotDisposed();
    return _requestApi.rollbackThread(
      _connection,
      threadId: threadId,
      numTurns: numTurns,
    );
  }

  Future<CodexAppServerSession> forkThread({
    required String threadId,
    String? path,
    String? cwd,
    String? model,
    String? modelProvider,
    bool? ephemeral,
    bool persistExtendedHistory = false,
  }) async {
    _ensureNotDisposed();
    return _requestApi.forkThread(
      _connection,
      threadId: threadId,
      path: path,
      cwd: cwd,
      model: model,
      modelProvider: modelProvider,
      ephemeral: ephemeral,
      persistExtendedHistory: persistExtendedHistory,
    );
  }

  Future<CodexAppServerThreadListPage> listThreads({
    String? cursor,
    int? limit,
  }) async {
    _ensureNotDisposed();
    return _requestApi.listThreads(_connection, cursor: cursor, limit: limit);
  }

  Future<CodexAppServerModelListPage> listModels({
    String? cursor,
    int? limit,
    bool? includeHidden,
  }) async {
    _ensureNotDisposed();
    return _requestApi.listModels(
      _connection,
      cursor: cursor,
      limit: limit,
      includeHidden: includeHidden,
    );
  }

  Future<CodexAppServerTurn> sendUserMessage({
    required String threadId,
    required String text,
    String? model,
    CodexReasoningEffort? effort,
  }) async {
    _ensureNotDisposed();
    return _requestApi.sendUserMessage(
      _connection,
      threadId: threadId,
      text: text,
      model: model,
      effort: effort,
    );
  }

  Future<void> answerUserInput({
    required String requestId,
    required Map<String, List<String>> answers,
  }) async {
    _ensureNotDisposed();
    await _requestApi.answerUserInput(
      _connection,
      requestId: requestId,
      answers: answers,
    );
  }

  Future<void> respondDynamicToolCall({
    required String requestId,
    required bool success,
    List<Map<String, Object?>> contentItems = const <Map<String, Object?>>[],
  }) async {
    _ensureNotDisposed();
    await _requestApi.respondDynamicToolCall(
      _connection,
      requestId: requestId,
      success: success,
      contentItems: contentItems,
    );
  }

  Future<void> resolveApproval({
    required String requestId,
    required bool approved,
  }) async {
    _ensureNotDisposed();
    await _requestApi.resolveApproval(
      _connection,
      requestId: requestId,
      approved: approved,
    );
  }

  Future<void> rejectServerRequest({
    required String requestId,
    required String message,
    int code = -32000,
    Object? data,
  }) async {
    _ensureNotDisposed();
    await _connection.rejectServerRequest(
      requestId: requestId,
      message: message,
      code: code,
      data: data,
    );
  }

  Future<void> respondToElicitation({
    required String requestId,
    required CodexAppServerElicitationAction action,
    Object? content,
    Object? metadata,
  }) async {
    _ensureNotDisposed();
    await _requestApi.respondToElicitation(
      _connection,
      requestId: requestId,
      action: action,
      content: content,
      metadata: metadata,
    );
  }

  Future<void> abortTurn({String? threadId, String? turnId}) async {
    _ensureNotDisposed();
    await _requestApi.abortTurn(
      _connection,
      threadId: threadId,
      turnId: turnId,
    );
  }

  Future<void> disconnect() async {
    if (_isDisposed) {
      return;
    }
    await _connection.disconnect();
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    await _connection.dispose();
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw const CodexAppServerException(
        'App-server client has been disposed.',
      );
    }
  }
}
