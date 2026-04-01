import 'dart:async';
import 'dart:math' as math;

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_agent_adapter_bridge.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';

class FakeCodexAppServerClient extends CodexAppServerClient {
  FakeCodexAppServerClient()
    : super(
        transportOpener:
            ({required profile, required secrets, required emitEvent}) async {
              throw UnimplementedError(
                'The fake app-server client never opens a transport.',
              );
            },
      );

  final _eventsController = StreamController<CodexAppServerEvent>.broadcast();

  int connectCalls = 0;
  int startSessionCalls = 0;
  final List<
    ({
      String threadId,
      String? path,
      String? cwd,
      String? model,
      String? modelProvider,
      bool? ephemeral,
      bool persistExtendedHistory,
    })
  >
  forkThreadRequests =
      <
        ({
          String threadId,
          String? path,
          String? cwd,
          String? model,
          String? modelProvider,
          bool? ephemeral,
          bool persistExtendedHistory,
        })
      >[];
  final List<
    ({
      String? cwd,
      String? model,
      CodexReasoningEffort? reasoningEffort,
      String? resumeThreadId,
    })
  >
  startSessionRequests =
      <
        ({
          String? cwd,
          String? model,
          CodexReasoningEffort? reasoningEffort,
          String? resumeThreadId,
        })
      >[];
  final List<String> readThreadCalls = <String>[];
  final List<({String threadId, int numTurns})> rollbackThreadCalls =
      <({String threadId, int numTurns})>[];
  final List<({String? cursor, int? limit})> listThreadCalls =
      <({String? cursor, int? limit})>[];
  final List<({String? cursor, int? limit, bool? includeHidden})>
  listModelCalls = <({String? cursor, int? limit, bool? includeHidden})>[];
  final List<String> sentMessages = <String>[];
  final List<
    ({
      String threadId,
      CodexAppServerTurnInput input,
      String text,
      String? model,
      CodexReasoningEffort? effort,
    })
  >
  sentTurns =
      <
        ({
          String threadId,
          CodexAppServerTurnInput input,
          String text,
          String? model,
          CodexReasoningEffort? effort,
        })
      >[];
  final List<({String? threadId, String? turnId})> abortTurnCalls =
      <({String? threadId, String? turnId})>[];
  final List<({String requestId, bool approved})> approvalDecisions =
      <({String requestId, bool approved})>[];
  final List<({String requestId, Map<String, List<String>> answers})>
  userInputResponses =
      <({String requestId, Map<String, List<String>> answers})>[];
  final List<
    ({
      String requestId,
      CodexAppServerElicitationAction action,
      Object? content,
      Object? metadata,
    })
  >
  elicitationResponses =
      <
        ({
          String requestId,
          CodexAppServerElicitationAction action,
          Object? content,
          Object? metadata,
        })
      >[];
  final List<({String requestId, String message})> rejectedRequests =
      <({String requestId, String message})>[];
  final List<
    ({String requestId, bool success, List<Map<String, Object?>> contentItems})
  >
  dynamicToolResponses =
      <
        ({
          String requestId,
          bool success,
          List<Map<String, Object?>> contentItems,
        })
      >[];
  final Map<String, String> pendingServerRequestMethodsById =
      <String, String>{};
  final Map<String, List<CodexAppServerEvent>>
  resumeThreadReplayEventsByThreadId = <String, List<CodexAppServerEvent>>{};
  final List<CodexAppServerEvent> connectEventsBeforeThrow =
      <CodexAppServerEvent>[];
  Object? connectError;
  Completer<void>? connectGate;
  Object? startSessionError;
  Object? forkThreadError;
  Object? sendUserMessageError;
  Object? readThreadWithTurnsError;
  Object? rollbackThreadError;
  Object? listModelsError;
  String? startSessionModel;
  String? forkThreadId;
  String? startSessionReasoningEffort;
  String? startSessionCwd;
  String? listModelsNextCursor;
  int? listModelsDefaultPageSize;
  final List<CodexAppServerModelListPage> listedModelPages =
      <CodexAppServerModelListPage>[];
  int disconnectCalls = 0;
  String? connectedThreadId;
  Completer<void>? sendUserMessageGate;
  Completer<void>? readThreadWithTurnsGate;
  Completer<void>? rollbackThreadGate;
  final Map<String, Completer<void>> readThreadWithTurnsGatesByThreadId =
      <String, Completer<void>>{};
  final Map<String, CodexAppServerThreadSummary> threadsById =
      <String, CodexAppServerThreadSummary>{};
  final Map<String, CodexAppServerThreadHistory> threadHistoriesById =
      <String, CodexAppServerThreadHistory>{};
  final List<CodexAppServerThreadSummary> listedThreads =
      <CodexAppServerThreadSummary>[];
  final List<CodexAppServerModel> listedModels = <CodexAppServerModel>[];

  bool _isConnected = false;
  String? _threadId;
  String? _activeTurnId;

  @override
  Stream<CodexAppServerEvent> get events => _eventsController.stream;

  @override
  bool get isConnected => _isConnected;

  @override
  String? get threadId => _threadId;

  @override
  String? get activeTurnId => _activeTurnId;

  @override
  Future<void> connect({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    if (connectError != null) {
      for (final event in connectEventsBeforeThrow) {
        emit(event);
      }
      throw connectError!;
    }
    final gate = connectGate;
    if (gate != null) {
      await gate.future;
    }
    connectCalls += 1;
    _isConnected = true;
    _threadId = connectedThreadId;
    emit(const CodexAppServerConnectedEvent(userAgent: 'codex-cli/test'));
  }

  @override
  Future<CodexAppServerSession> startSession({
    String? cwd,
    String? model,
    CodexReasoningEffort? reasoningEffort,
    String? resumeThreadId,
  }) async {
    if (startSessionError != null) {
      throw startSessionError!;
    }
    startSessionCalls += 1;
    startSessionRequests.add((
      cwd: cwd,
      model: model,
      reasoningEffort: reasoningEffort,
      resumeThreadId: resumeThreadId,
    ));
    _threadId = resumeThreadId ?? 'thread_123';
    final session = CodexAppServerSession(
      threadId: _threadId!,
      cwd: startSessionCwd ?? cwd ?? '/workspace',
      model: startSessionModel ?? model ?? 'gpt-5.3-codex',
      modelProvider: 'openai',
      reasoningEffort: startSessionReasoningEffort,
      thread: CodexAppServerThreadSummary(
        id: _threadId!,
        sourceKind: 'app-server',
      ),
    );
    if (resumeThreadId != null && resumeThreadId.trim().isNotEmpty) {
      final replayEvents = resumeThreadReplayEventsByThreadId[resumeThreadId];
      if (replayEvents != null) {
        for (final event in replayEvents) {
          emit(event);
        }
      }
    }
    return session;
  }

  @override
  Future<CodexAppServerSession> resumeThread({
    required String threadId,
    String? cwd,
    String? model,
    CodexReasoningEffort? reasoningEffort,
  }) {
    return startSession(
      cwd: cwd,
      model: model,
      reasoningEffort: reasoningEffort,
      resumeThreadId: threadId,
    );
  }

  @override
  Future<CodexAppServerSession> forkThread({
    required String threadId,
    String? path,
    String? cwd,
    String? model,
    String? modelProvider,
    bool? ephemeral,
    bool persistExtendedHistory = false,
  }) async {
    if (forkThreadError != null) {
      throw forkThreadError!;
    }
    forkThreadRequests.add((
      threadId: threadId,
      path: path,
      cwd: cwd,
      model: model,
      modelProvider: modelProvider,
      ephemeral: ephemeral,
      persistExtendedHistory: persistExtendedHistory,
    ));
    _threadId = forkThreadId ?? '${threadId}_fork';
    return CodexAppServerSession(
      threadId: _threadId!,
      cwd: cwd ?? '/workspace',
      model: model ?? 'gpt-5.3-codex',
      modelProvider: modelProvider ?? 'openai',
      thread: CodexAppServerThreadSummary(
        id: _threadId!,
        path: path,
        cwd: cwd,
        sourceKind: 'app-server',
      ),
      approvalPolicy: 'on-request',
      sandbox: const <String, Object?>{'type': 'workspace-write'},
    );
  }

  @override
  Future<CodexAppServerThreadSummary> readThread({
    required String threadId,
  }) async {
    readThreadCalls.add(threadId);
    final configuredThread = threadsById[threadId];
    if (configuredThread != null) {
      return configuredThread;
    }
    final configuredHistory = threadHistoriesById[threadId];
    if (configuredHistory != null) {
      return CodexAppServerThreadSummary(
        id: configuredHistory.id,
        preview: configuredHistory.preview,
        ephemeral: configuredHistory.ephemeral,
        modelProvider: configuredHistory.modelProvider,
        createdAt: configuredHistory.createdAt,
        updatedAt: configuredHistory.updatedAt,
        path: configuredHistory.path,
        cwd: configuredHistory.cwd,
        promptCount: configuredHistory.promptCount,
        name: configuredHistory.name,
        sourceKind: configuredHistory.sourceKind,
        agentNickname: configuredHistory.agentNickname,
        agentRole: configuredHistory.agentRole,
      );
    }
    return CodexAppServerThreadSummary(id: threadId, sourceKind: 'app-server');
  }

  @override
  Future<CodexAppServerThreadHistory> readThreadWithTurns({
    required String threadId,
  }) async {
    final configuredHistory = threadHistoriesById[threadId];
    if (configuredHistory != null) {
      readThreadCalls.add(threadId);
      await _awaitReadThreadWithTurnsGate(threadId);
      if (readThreadWithTurnsError != null) {
        throw readThreadWithTurnsError!;
      }
      return configuredHistory;
    }

    final configuredThread = threadsById[threadId];
    if (configuredThread != null) {
      readThreadCalls.add(threadId);
      await _awaitReadThreadWithTurnsGate(threadId);
      if (readThreadWithTurnsError != null) {
        throw readThreadWithTurnsError!;
      }
      return CodexAppServerThreadHistory(
        id: configuredThread.id,
        preview: configuredThread.preview,
        ephemeral: configuredThread.ephemeral,
        modelProvider: configuredThread.modelProvider,
        createdAt: configuredThread.createdAt,
        updatedAt: configuredThread.updatedAt,
        path: configuredThread.path,
        cwd: configuredThread.cwd,
        promptCount: configuredThread.promptCount,
        name: configuredThread.name,
        sourceKind: configuredThread.sourceKind,
        agentNickname: configuredThread.agentNickname,
        agentRole: configuredThread.agentRole,
      );
    }

    final summary = await readThread(threadId: threadId);
    await _awaitReadThreadWithTurnsGate(threadId);
    if (readThreadWithTurnsError != null) {
      throw readThreadWithTurnsError!;
    }
    return CodexAppServerThreadHistory(
      id: summary.id,
      preview: summary.preview,
      ephemeral: summary.ephemeral,
      modelProvider: summary.modelProvider,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      path: summary.path,
      cwd: summary.cwd,
      promptCount: summary.promptCount,
      name: summary.name,
      sourceKind: summary.sourceKind,
      agentNickname: summary.agentNickname,
      agentRole: summary.agentRole,
    );
  }

  Future<void> _awaitReadThreadWithTurnsGate(String threadId) async {
    final threadGate = readThreadWithTurnsGatesByThreadId[threadId];
    if (threadGate != null) {
      await threadGate.future;
      return;
    }
    if (readThreadWithTurnsGate case final gate?) {
      await gate.future;
    }
  }

  @override
  Future<CodexAppServerThreadHistory> rollbackThread({
    required String threadId,
    required int numTurns,
  }) async {
    rollbackThreadCalls.add((threadId: threadId, numTurns: numTurns));
    if (rollbackThreadGate case final gate?) {
      await gate.future;
    }
    if (rollbackThreadError != null) {
      throw rollbackThreadError!;
    }

    final configuredHistory = threadHistoriesById[threadId];
    if (configuredHistory != null) {
      return configuredHistory;
    }

    return CodexAppServerThreadHistory(id: threadId, sourceKind: 'app-server');
  }

  @override
  Future<CodexAppServerThreadListPage> listThreads({
    String? cursor,
    int? limit,
  }) async {
    listThreadCalls.add((cursor: cursor, limit: limit));
    return CodexAppServerThreadListPage(
      threads: List<CodexAppServerThreadSummary>.from(listedThreads),
      nextCursor: null,
    );
  }

  @override
  Future<CodexAppServerModelListPage> listModels({
    String? cursor,
    int? limit,
    bool? includeHidden,
  }) async {
    if (listModelsError != null) {
      throw listModelsError!;
    }
    listModelCalls.add((
      cursor: cursor,
      limit: limit,
      includeHidden: includeHidden,
    ));
    if (listedModelPages.isNotEmpty) {
      return listedModelPages.removeAt(0);
    }
    final defaultPageSize = listModelsDefaultPageSize;
    if (defaultPageSize != null) {
      final effectivePageSize = limit != null && limit > 0
          ? limit
          : defaultPageSize;
      final startIndex = int.tryParse(cursor ?? '') ?? 0;
      final boundedStartIndex = math.min(
        math.max(startIndex, 0),
        listedModels.length,
      );
      final endIndex = math.min(
        boundedStartIndex + effectivePageSize,
        listedModels.length,
      );
      return CodexAppServerModelListPage(
        models: List<CodexAppServerModel>.from(
          listedModels.sublist(boundedStartIndex, endIndex),
        ),
        nextCursor: endIndex < listedModels.length ? '$endIndex' : null,
      );
    }
    return CodexAppServerModelListPage(
      models: List<CodexAppServerModel>.from(listedModels),
      nextCursor: listModelsNextCursor,
    );
  }

  @override
  Future<CodexAppServerTurn> sendUserMessage({
    required String threadId,
    String? text,
    AgentAdapterTurnInput? input,
    String? model,
    CodexReasoningEffort? effort,
  }) async {
    if (sendUserMessageGate case final gate? when !gate.isCompleted) {
      await gate.future;
    }
    if (sendUserMessageError != null) {
      throw sendUserMessageError!;
    }
    final effectiveInput =
        codexTurnInputFromAgentAdapter(input) ??
        CodexAppServerTurnInput.text(text ?? '');
    sentMessages.add(effectiveInput.text);
    sentTurns.add((
      threadId: threadId,
      input: effectiveInput,
      text: effectiveInput.text,
      model: model,
      effort: effort,
    ));
    _threadId = threadId;
    _activeTurnId = 'turn_${sentMessages.length}';
    return CodexAppServerTurn(threadId: threadId, turnId: _activeTurnId!);
  }

  @override
  Future<void> resolveApproval({
    required String requestId,
    required bool approved,
  }) async {
    _removePendingServerRequest(
      requestId,
      allowedMethods: const <String>{
        'item/commandExecution/requestApproval',
        'item/fileChange/requestApproval',
        'item/permissions/requestApproval',
        'applyPatchApproval',
        'execCommandApproval',
      },
    );
    approvalDecisions.add((requestId: requestId, approved: approved));
  }

  @override
  Future<void> answerUserInput({
    required String requestId,
    required Map<String, List<String>> answers,
  }) async {
    _removePendingServerRequest(
      requestId,
      allowedMethods: const <String>{
        'item/tool/requestUserInput',
        'tool/requestUserInput',
      },
    );
    userInputResponses.add((requestId: requestId, answers: answers));
  }

  @override
  Future<void> respondToElicitation({
    required String requestId,
    required AgentAdapterElicitationAction action,
    Object? content,
    Object? metadata,
  }) async {
    _removePendingServerRequest(
      requestId,
      allowedMethods: const <String>{'mcpServer/elicitation/request'},
    );
    elicitationResponses.add((
      requestId: requestId,
      action: codexElicitationActionFromAgentAdapter(action),
      content: content,
      metadata: metadata,
    ));
  }

  @override
  Future<void> respondDynamicToolCall({
    required String requestId,
    required bool success,
    List<Map<String, Object?>> contentItems = const <Map<String, Object?>>[],
  }) async {
    _removePendingServerRequest(
      requestId,
      allowedMethods: const <String>{'item/tool/call'},
    );
    dynamicToolResponses.add((
      requestId: requestId,
      success: success,
      contentItems: contentItems,
    ));
  }

  @override
  Future<void> rejectServerRequest({
    required String requestId,
    required String message,
    int code = -32000,
    Object? data,
  }) async {
    _removePendingServerRequest(requestId);
    rejectedRequests.add((requestId: requestId, message: message));
  }

  @override
  Future<void> abortTurn({String? threadId, String? turnId}) async {
    abortTurnCalls.add((threadId: threadId, turnId: turnId));
    _activeTurnId = null;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    if (!_isConnected) {
      return;
    }
    _isConnected = false;
    _threadId = null;
    _activeTurnId = null;
    pendingServerRequestMethodsById.clear();
    emit(const CodexAppServerDisconnectedEvent(exitCode: 0));
  }

  void emit(CodexAppServerEvent event) {
    switch (event) {
      case CodexAppServerRequestEvent(:final requestId, :final method):
        pendingServerRequestMethodsById[requestId] = method;
      case CodexAppServerDisconnectedEvent():
        pendingServerRequestMethodsById.clear();
      default:
        break;
    }
    if (_eventsController.isClosed) {
      return;
    }
    _eventsController.add(event);
  }

  Future<void> close() async {
    await _eventsController.close();
  }

  void _removePendingServerRequest(
    String requestId, {
    Set<String>? allowedMethods,
  }) {
    final method = pendingServerRequestMethodsById[requestId];
    if (method == null) {
      throw CodexAppServerException(
        'Unknown pending server request: $requestId',
      );
    }
    if (allowedMethods != null && !allowedMethods.contains(method)) {
      throw CodexAppServerException(
        'Request $requestId is $method, not a compatible pending server request.',
      );
    }
    pendingServerRequestMethodsById.remove(requestId);
  }
}
