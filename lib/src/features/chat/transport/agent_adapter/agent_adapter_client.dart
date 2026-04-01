import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';

abstract interface class AgentAdapterClient {
  Stream<AgentAdapterEvent> get events;
  bool get isConnected;
  String? get threadId;
  String? get activeTurnId;

  Future<void> connect({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  });

  Future<AgentAdapterSession> startSession({
    String? cwd,
    String? model,
    AgentAdapterReasoningEffort? reasoningEffort,
    String? resumeThreadId,
  });

  Future<AgentAdapterSession> resumeThread({
    required String threadId,
    String? cwd,
    String? model,
    AgentAdapterReasoningEffort? reasoningEffort,
  });

  Future<AgentAdapterThreadSummary> readThread({required String threadId});

  Future<AgentAdapterThreadHistory> readThreadWithTurns({
    required String threadId,
  });

  Future<AgentAdapterThreadHistory> rollbackThread({
    required String threadId,
    required int numTurns,
  });

  Future<AgentAdapterSession> forkThread({
    required String threadId,
    String? path,
    String? cwd,
    String? model,
    String? modelProvider,
    bool? ephemeral,
    bool persistExtendedHistory = false,
  });

  Future<AgentAdapterThreadListPage> listThreads({String? cursor, int? limit});

  Future<AgentAdapterModelListPage> listModels({
    String? cursor,
    int? limit,
    bool? includeHidden,
  });

  Future<AgentAdapterTurn> sendUserMessage({
    required String threadId,
    String? text,
    AgentAdapterTurnInput? input,
    String? model,
    AgentAdapterReasoningEffort? effort,
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
    required AgentAdapterElicitationAction action,
    Object? content,
    Object? metadata,
  });

  Future<void> abortTurn({String? threadId, String? turnId});
  Future<void> disconnect();
  Future<void> dispose();
}
