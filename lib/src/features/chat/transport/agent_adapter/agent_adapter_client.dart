import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_models.dart';

abstract interface class AgentAdapterClient {
  Stream<CodexAppServerEvent> get events;
  bool get isConnected;
  String? get threadId;
  String? get activeTurnId;

  Future<void> connect({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  });

  Future<CodexAppServerSession> startSession({
    String? cwd,
    String? model,
    CodexReasoningEffort? reasoningEffort,
    String? resumeThreadId,
  });

  Future<CodexAppServerSession> resumeThread({
    required String threadId,
    String? cwd,
    String? model,
    CodexReasoningEffort? reasoningEffort,
  });

  Future<CodexAppServerThreadSummary> readThread({required String threadId});

  Future<CodexAppServerThreadHistory> readThreadWithTurns({
    required String threadId,
  });

  Future<CodexAppServerThreadHistory> rollbackThread({
    required String threadId,
    required int numTurns,
  });

  Future<CodexAppServerSession> forkThread({
    required String threadId,
    String? path,
    String? cwd,
    String? model,
    String? modelProvider,
    bool? ephemeral,
    bool persistExtendedHistory = false,
  });

  Future<CodexAppServerThreadListPage> listThreads({
    String? cursor,
    int? limit,
  });

  Future<CodexAppServerModelListPage> listModels({
    String? cursor,
    int? limit,
    bool? includeHidden,
  });

  Future<CodexAppServerTurn> sendUserMessage({
    required String threadId,
    String? text,
    CodexAppServerTurnInput? input,
    String? model,
    CodexReasoningEffort? effort,
  });

  Future<void> answerUserInput({
    required String requestId,
    required Map<String, List<String>> answers,
  });

  Future<void> respondDynamicToolCall({
    required String requestId,
    required bool success,
    List<Map<String, Object?>> contentItems = const <Map<String, Object?>>[],
  });

  Future<void> resolveApproval({
    required String requestId,
    required bool approved,
  });

  Future<void> rejectServerRequest({
    required String requestId,
    required String message,
    int code = -32000,
    Object? data,
  });

  Future<void> respondToElicitation({
    required String requestId,
    required CodexAppServerElicitationAction action,
    Object? content,
    Object? metadata,
  });

  Future<void> abortTurn({String? threadId, String? turnId});
  Future<void> disconnect();
  Future<void> dispose();
}
