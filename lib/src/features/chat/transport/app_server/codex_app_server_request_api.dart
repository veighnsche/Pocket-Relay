import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_connection.dart';
import 'codex_app_server_models.dart';
import 'codex_app_server_thread_read_decoder.dart';

part 'codex_app_server_request_api_session_thread.dart';
part 'codex_app_server_request_api_turn_requests.dart';
part 'codex_app_server_request_api_support.dart';

class CodexAppServerRequestApi {
  const CodexAppServerRequestApi({
    CodexAppServerThreadReadDecoder threadReadDecoder =
        const CodexAppServerThreadReadDecoder(),
  }) : _threadReadDecoder = threadReadDecoder;

  final CodexAppServerThreadReadDecoder _threadReadDecoder;

  Future<CodexAppServerSession> startSession(
    CodexAppServerConnection connection, {
    String? cwd,
    String? model,
    CodexReasoningEffort? reasoningEffort,
    String? resumeThreadId,
  }) {
    return _startSession(
      this,
      connection,
      cwd: cwd,
      model: model,
      reasoningEffort: reasoningEffort,
      resumeThreadId: resumeThreadId,
    );
  }

  Future<CodexAppServerThreadSummary> readThread(
    CodexAppServerConnection connection, {
    required String threadId,
  }) {
    return _readThread(this, connection, threadId: threadId);
  }

  Future<CodexAppServerThreadHistory> readThreadWithTurns(
    CodexAppServerConnection connection, {
    required String threadId,
  }) {
    return _readThreadWithTurns(this, connection, threadId: threadId);
  }

  Future<CodexAppServerThreadHistory> rollbackThread(
    CodexAppServerConnection connection, {
    required String threadId,
    required int numTurns,
  }) {
    return _rollbackThread(
      this,
      connection,
      threadId: threadId,
      numTurns: numTurns,
    );
  }

  Future<CodexAppServerSession> forkThread(
    CodexAppServerConnection connection, {
    required String threadId,
    String? path,
    String? cwd,
    String? model,
    String? modelProvider,
    bool? ephemeral,
    bool persistExtendedHistory = false,
  }) {
    return _forkThread(
      this,
      connection,
      threadId: threadId,
      path: path,
      cwd: cwd,
      model: model,
      modelProvider: modelProvider,
      ephemeral: ephemeral,
      persistExtendedHistory: persistExtendedHistory,
    );
  }

  Future<CodexAppServerThreadListPage> listThreads(
    CodexAppServerConnection connection, {
    String? cursor,
    int? limit,
  }) {
    return _listThreads(this, connection, cursor: cursor, limit: limit);
  }

  Future<CodexAppServerModelListPage> listModels(
    CodexAppServerConnection connection, {
    String? cursor,
    int? limit,
  }) {
    return _listModels(this, connection, cursor: cursor, limit: limit);
  }

  Future<CodexAppServerTurn> sendUserMessage(
    CodexAppServerConnection connection, {
    required String threadId,
    String? text,
    CodexAppServerTurnInput? input,
    String? model,
    CodexReasoningEffort? effort,
  }) {
    return _sendUserMessage(
      connection,
      threadId: threadId,
      text: text,
      input: input,
      model: model,
      effort: effort,
    );
  }

  Future<void> answerUserInput(
    CodexAppServerConnection connection, {
    required String requestId,
    required Map<String, List<String>> answers,
  }) {
    return _answerUserInput(connection, requestId: requestId, answers: answers);
  }

  Future<void> respondDynamicToolCall(
    CodexAppServerConnection connection, {
    required String requestId,
    required bool success,
    List<Map<String, Object?>> contentItems = const <Map<String, Object?>>[],
  }) {
    return _respondDynamicToolCall(
      connection,
      requestId: requestId,
      success: success,
      contentItems: contentItems,
    );
  }

  Future<void> resolveApproval(
    CodexAppServerConnection connection, {
    required String requestId,
    required bool approved,
  }) {
    return _resolveApproval(
      connection,
      requestId: requestId,
      approved: approved,
    );
  }

  Future<void> resolvePermissionsRequest(
    CodexAppServerConnection connection, {
    required String requestId,
    required bool approved,
    String scope = 'turn',
  }) {
    return _resolvePermissionsRequest(
      connection,
      requestId: requestId,
      approved: approved,
      scope: scope,
    );
  }

  Future<void> respondToElicitation(
    CodexAppServerConnection connection, {
    required String requestId,
    required CodexAppServerElicitationAction action,
    Object? content,
    Object? metadata,
  }) {
    return _respondToElicitation(
      connection,
      requestId: requestId,
      action: action,
      content: content,
      metadata: metadata,
    );
  }

  Future<void> abortTurn(
    CodexAppServerConnection connection, {
    String? threadId,
    String? turnId,
  }) {
    return _abortTurn(connection, threadId: threadId, turnId: turnId);
  }
}
