import 'dart:async';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';

class FakeCodexAppServerClient extends CodexAppServerClient {
  FakeCodexAppServerClient()
    : super(
        processLauncher:
            ({required profile, required secrets, required emitEvent}) async {
              throw UnimplementedError(
                'The fake app-server client never launches a process.',
              );
            },
      );

  final _eventsController = StreamController<CodexAppServerEvent>.broadcast();

  int connectCalls = 0;
  int startSessionCalls = 0;
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
  final List<({String? cursor, int? limit})> listThreadCalls =
      <({String? cursor, int? limit})>[];
  final List<String> sentMessages = <String>[];
  final List<
    ({
      String threadId,
      String text,
      String? model,
      CodexReasoningEffort? effort,
    })
  >
  sentTurns =
      <
        ({
          String threadId,
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
  final List<CodexAppServerEvent> connectEventsBeforeThrow =
      <CodexAppServerEvent>[];
  Object? connectError;
  Object? startSessionError;
  Object? sendUserMessageError;
  String? startSessionModel;
  String? startSessionReasoningEffort;
  String? startSessionCwd;
  int disconnectCalls = 0;
  String? connectedThreadId;
  Completer<void>? sendUserMessageGate;
  final Map<String, CodexAppServerThread> threadsById =
      <String, CodexAppServerThread>{};
  final List<CodexAppServerThread> listedThreads = <CodexAppServerThread>[];

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
    return CodexAppServerSession(
      threadId: _threadId!,
      cwd: startSessionCwd ?? cwd ?? '/workspace',
      model: startSessionModel ?? model ?? 'gpt-5.3-codex',
      modelProvider: 'openai',
      reasoningEffort: startSessionReasoningEffort,
      thread: CodexAppServerThread(id: _threadId!, sourceKind: 'app-server'),
    );
  }

  @override
  Future<CodexAppServerThread> readThread({required String threadId}) async {
    readThreadCalls.add(threadId);
    final configuredThread = threadsById[threadId];
    if (configuredThread != null) {
      return configuredThread;
    }
    return CodexAppServerThread(id: threadId, sourceKind: 'app-server');
  }

  @override
  Future<CodexAppServerThread> readThreadWithTurns({required String threadId}) {
    return readThread(threadId: threadId);
  }

  @override
  Future<CodexAppServerThreadListPage> listThreads({
    String? cursor,
    int? limit,
  }) async {
    listThreadCalls.add((cursor: cursor, limit: limit));
    return CodexAppServerThreadListPage(
      threads: List<CodexAppServerThread>.from(listedThreads),
      nextCursor: null,
    );
  }

  @override
  Future<CodexAppServerTurn> sendUserMessage({
    required String threadId,
    required String text,
    String? model,
    CodexReasoningEffort? effort,
  }) async {
    if (sendUserMessageGate case final gate? when !gate.isCompleted) {
      await gate.future;
    }
    if (sendUserMessageError != null) {
      throw sendUserMessageError!;
    }
    sentMessages.add(text);
    sentTurns.add((
      threadId: threadId,
      text: text,
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
    approvalDecisions.add((requestId: requestId, approved: approved));
  }

  @override
  Future<void> answerUserInput({
    required String requestId,
    required Map<String, List<String>> answers,
  }) async {
    userInputResponses.add((requestId: requestId, answers: answers));
  }

  @override
  Future<void> respondToElicitation({
    required String requestId,
    required CodexAppServerElicitationAction action,
    Object? content,
    Object? metadata,
  }) async {
    elicitationResponses.add((
      requestId: requestId,
      action: action,
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
    emit(const CodexAppServerDisconnectedEvent(exitCode: 0));
  }

  void emit(CodexAppServerEvent event) {
    if (_eventsController.isClosed) {
      return;
    }
    _eventsController.add(event);
  }

  Future<void> close() async {
    await _eventsController.close();
  }
}
