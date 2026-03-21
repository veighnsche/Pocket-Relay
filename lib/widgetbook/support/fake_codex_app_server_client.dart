import 'dart:async';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';

class WidgetbookFakeCodexAppServerClient extends CodexAppServerClient {
  WidgetbookFakeCodexAppServerClient()
    : super(
        processLauncher:
            ({required profile, required secrets, required emitEvent}) async {
              throw UnimplementedError(
                'Widgetbook previews never launch a real app-server process.',
              );
            },
      );

  final StreamController<CodexAppServerEvent> _eventsController =
      StreamController<CodexAppServerEvent>.broadcast();

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
    _isConnected = true;
    _eventsController.add(
      const CodexAppServerConnectedEvent(userAgent: 'codex-cli/widgetbook'),
    );
  }

  @override
  Future<CodexAppServerSession> startSession({
    String? cwd,
    String? model,
    CodexReasoningEffort? reasoningEffort,
    String? resumeThreadId,
  }) async {
    _threadId = resumeThreadId ?? 'thread_widgetbook';
    return CodexAppServerSession(
      threadId: _threadId!,
      cwd: cwd ?? '/workspace',
      model: model ?? 'gpt-5.4',
      modelProvider: 'openai',
      reasoningEffort: reasoningEffort?.name,
      thread: _threadSummary(_threadId!),
    );
  }

  @override
  Future<CodexAppServerThreadSummary> readThread({
    required String threadId,
  }) async {
    return _threadSummary(threadId);
  }

  @override
  Future<CodexAppServerThreadHistory> readThreadWithTurns({
    required String threadId,
  }) async {
    final summary = await readThread(threadId: threadId);
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

  @override
  Future<CodexAppServerThreadListPage> listThreads({
    String? cursor,
    int? limit,
  }) async {
    return const CodexAppServerThreadListPage(
      threads: <CodexAppServerThreadSummary>[],
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
    _threadId = threadId;
    _activeTurnId = 'turn_widgetbook';
    return CodexAppServerTurn(threadId: threadId, turnId: _activeTurnId!);
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _activeTurnId = null;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _eventsController.close();
  }

  CodexAppServerThreadSummary _threadSummary(String threadId) {
    return CodexAppServerThreadSummary(id: threadId, sourceKind: 'app-server');
  }
}
