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
  final List<String> sentMessages = <String>[];
  final List<({String requestId, bool approved})> approvalDecisions =
      <({String requestId, bool approved})>[];
  final List<({String requestId, Map<String, List<String>> answers})>
  userInputResponses =
      <({String requestId, Map<String, List<String>> answers})>[];
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
    connectCalls += 1;
    _isConnected = true;
    emit(const CodexAppServerConnectedEvent(userAgent: 'codex-cli/test'));
  }

  @override
  Future<CodexAppServerSession> startSession({
    String? cwd,
    String? model,
    String? resumeThreadId,
  }) async {
    startSessionCalls += 1;
    _threadId = resumeThreadId ?? 'thread_123';
    return CodexAppServerSession(
      threadId: _threadId!,
      cwd: cwd ?? '/workspace',
      model: model ?? 'gpt-5.3-codex',
      modelProvider: 'openai',
    );
  }

  @override
  Future<CodexAppServerTurn> sendUserMessage({
    required String threadId,
    required String text,
    String? model,
  }) async {
    sentMessages.add(text);
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
    _activeTurnId = null;
  }

  @override
  Future<void> disconnect() async {
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
