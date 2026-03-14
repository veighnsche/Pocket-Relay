import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/services/codex_app_server_client.dart';

void main() {
  testWidgets('sends prompts through app-server and renders assistant output', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      PocketRelayApp(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Hello Codex');
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(appServerClient.connectCalls, 1);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.sentMessages, <String>['Hello Codex']);
    expect(find.text('Hello Codex'), findsOneWidget);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_1',
            'type': 'agentMessage',
            'status': 'inProgress',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/agentMessage/delta',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'item_1',
          'delta': 'Hi from Codex',
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_1',
            'type': 'agentMessage',
            'status': 'completed',
            'text': 'Hi from Codex',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_1',
            'status': 'completed',
            'usage': <String, Object?>{'inputTokens': 12, 'outputTokens': 34},
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Hi from Codex'), findsOneWidget);
    expect(find.textContaining('Turn complete'), findsOneWidget);
  });

  testWidgets('approval actions are routed to the app-server client', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      PocketRelayApp(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
      ),
    );

    await tester.pumpAndSettle();

    appServerClient.emit(
      const CodexAppServerRequestEvent(
        requestId: 'i:99',
        method: 'item/fileChange/requestApproval',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'item_1',
          'reason': 'Write files',
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('File change approval'), findsOneWidget);
    expect(find.text('Write files'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(
      appServerClient.approvalDecisions,
      <({String requestId, bool approved})>[
        (requestId: 'i:99', approved: true),
      ],
    );
  });

  testWidgets(
    'user-input requests are submitted through the app-server client',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        PocketRelayApp(
          profileStore: MemoryCodexProfileStore(
            initialValue: SavedProfile(
              profile: _configuredProfile(),
              secrets: const ConnectionSecrets(password: 'secret'),
            ),
          ),
          appServerClient: appServerClient,
        ),
      );

      await tester.pumpAndSettle();

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 's:user-input-1',
          method: 'item/tool/requestUserInput',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'questions': <Object>[
              <String, Object?>{
                'id': 'q1',
                'header': 'Name',
                'question': 'What is your name?',
                'options': <Object>[
                  <String, Object?>{
                    'label': 'Vince',
                    'description': 'Use the saved profile name.',
                  },
                ],
              },
            ],
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Input required'), findsOneWidget);
      expect(find.text('What is your name?'), findsOneWidget);

      await tester.tap(find.text('Vince').first);
      await tester.pump();
      await tester.ensureVisible(find.text('Submit response'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit response'));
      await tester.pumpAndSettle();

      expect(appServerClient.userInputResponses, hasLength(1));
      expect(
        appServerClient.userInputResponses.single.requestId,
        's:user-input-1',
      );
      expect(
        appServerClient.userInputResponses.single.answers,
        <String, List<String>>{
          'q1': <String>['Vince'],
        },
      );
    },
  );

  testWidgets('unsupported host requests are rejected with a status entry', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      PocketRelayApp(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
      ),
    );

    await tester.pumpAndSettle();

    appServerClient.emit(
      const CodexAppServerRequestEvent(
        requestId: 's:auth-1',
        method: 'account/chatgptAuthTokens/refresh',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'reason': 'unauthorized',
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Auth refresh unsupported'), findsOneWidget);
    expect(
      find.textContaining('does not manage external ChatGPT tokens'),
      findsOneWidget,
    );
    expect(appServerClient.rejectedRequests, <
      ({String requestId, String message})
    >[
      (
        requestId: 's:auth-1',
        message:
            'Pocket Relay does not manage external ChatGPT tokens, so this app-server auth refresh request was rejected.',
      ),
    ]);
  });

  testWidgets('streaming updates do not yank the transcript while scrolled up', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      PocketRelayApp(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
      ),
    );

    await tester.pumpAndSettle();

    for (var index = 0; index < 24; index += 1) {
      appServerClient.emit(
        CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_$index',
            'item': <String, Object?>{
              'id': 'item_$index',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'Assistant message $index',
            },
          },
        ),
      );
    }

    await tester.pumpAndSettle();

    final scrollableState = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    expect(scrollableState.position.maxScrollExtent, greaterThan(0));

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();

    final pixelsBeforeStream = scrollableState.position.pixels;
    expect(
      pixelsBeforeStream,
      lessThan(scrollableState.position.maxScrollExtent),
    );

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_live',
          'item': <String, Object?>{
            'id': 'item_live',
            'type': 'agentMessage',
            'status': 'inProgress',
          },
        },
      ),
    );
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/agentMessage/delta',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_live',
          'itemId': 'item_live',
          'delta': 'Live stream text',
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      scrollableState.position.pixels,
      closeTo(pixelsBeforeStream, 1),
    );
    expect(
      scrollableState.position.pixels,
      lessThan(scrollableState.position.maxScrollExtent - 40),
    );
  });

  testWidgets('thread token usage is rendered like a normal transcript card', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      PocketRelayApp(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
      ),
    );

    await tester.pumpAndSettle();

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_live',
            'model': 'gpt-5.3-codex',
          },
        },
      ),
    );

    for (var index = 0; index < 20; index += 1) {
      appServerClient.emit(
        CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_$index',
            'item': <String, Object?>{
              'id': 'item_$index',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'Assistant message $index',
            },
          },
        ),
      );
    }
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'thread/tokenUsage/updated',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_live',
          'tokenUsage': <String, Object?>{
            'last': <String, Object?>{
              'inputTokens': 10,
              'cachedInputTokens': 2,
              'outputTokens': 4,
              'reasoningOutputTokens': 1,
              'totalTokens': 17,
            },
            'total': <String, Object?>{
              'inputTokens': 20,
              'cachedInputTokens': 3,
              'outputTokens': 8,
              'reasoningOutputTokens': 1,
              'totalTokens': 32,
            },
            'modelContextWindow': 200000,
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Thread token usage'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Thread token usage'), findsOneWidget);
    expect(find.text('ctx 200000'), findsOneWidget);
  });
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    host: 'example.com',
    username: 'vince',
  );
}

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
