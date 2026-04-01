import 'screen_app_server_test_support.dart';

void main() {
  testWidgets(
    'keeps updating the existing work row after assistant text takes the tail',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'command_1',
              'type': 'commandExecution',
              'status': 'inProgress',
              'command': 'git status',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'command_1',
            'delta': 'clean',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/agentMessage/delta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_1',
            'delta': 'Investigating',
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Work log'), findsOneWidget);
      expect(find.text('Checking worktree status'), findsOneWidget);
      expect(find.text('Investigating'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'command_1',
            'delta': ' status',
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Work log'), findsOneWidget);
      expect(find.text('Checking worktree status'), findsOneWidget);
      expect(find.text('Investigating'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps user-input chronology when assistant output resumes after submission',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'assistant_1',
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
            'itemId': 'assistant_1',
            'delta': 'Before request',
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Before request'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 's:user-input-1',
          method: 'item/tool/requestUserInput',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_1',
            'questions': <Object>[
              <String, Object?>{
                'id': 'q1',
                'header': 'Name',
                'question': 'What is your name?',
              },
            ],
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Input required'), findsOneWidget);
      expect(find.text('Before request'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/tool/requestUserInput/answered',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_1',
            'requestId': 'user-input-1',
            'answers': <String, Object?>{
              'q1': <Object>['Vince'],
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Input required'), findsNothing);
      expect(find.text('Input submitted'), findsOneWidget);
      expect(find.textContaining('Vince'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/agentMessage/delta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_1',
            'delta': 'After request',
          },
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('After request'), findsOneWidget);

      final beforeDy = tester.getTopLeft(find.text('Before request')).dy;
      final submittedDy = tester.getTopLeft(find.text('Input submitted')).dy;
      final afterDy = tester.getTopLeft(find.text('After request')).dy;

      expect(beforeDy, lessThan(submittedDy));
      expect(submittedDy, lessThan(afterDy));
    },
  );

  testWidgets('unsupported host requests are rejected with a status entry', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

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

  testWidgets(
    'streaming updates do not yank the transcript while scrolled up',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

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

      expect(scrollableState.position.pixels, closeTo(pixelsBeforeStream, 1));
      expect(
        scrollableState.position.pixels,
        lessThan(scrollableState.position.maxScrollExtent - 40),
      );
    },
  );

  testWidgets('invalid prompt submission does not force transcript follow', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      buildCatalogApp(
        appServerClient: appServerClient,
        savedProfile: savedProfile(secrets: const ConnectionSecrets()),
      ),
    );

    await pumpAppReady(tester);

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

    final pixelsBeforeSubmit = scrollableState.position.pixels;
    expect(
      pixelsBeforeSubmit,
      lessThan(scrollableState.position.maxScrollExtent),
    );

    await tester.enterText(
      find.byKey(const ValueKey('composer_input')),
      'Needs credentials',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('This profile needs an SSH password.'),
      findsOneWidget,
    );
    expect(appServerClient.sentMessages, isEmpty);
    expect(scrollableState.position.pixels, closeTo(pixelsBeforeSubmit, 1));
    expect(
      scrollableState.position.pixels,
      lessThan(scrollableState.position.maxScrollExtent - 40),
    );
  });

  testWidgets('thread token usage is shown once when the turn completes', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

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

    expect(find.text('Thread usage'), findsNothing);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_live',
            'status': 'completed',
            'usage': <String, Object?>{
              'inputTokens': 12,
              'cachedInputTokens': 3,
              'outputTokens': 7,
            },
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Thread usage'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Thread usage'), findsOneWidget);
    expect(find.text('ctx 200k'), findsOneWidget);
    expect(find.textContaining('end'), findsAtLeastNWidgets(1));

    final endRect = tester.getRect(find.textContaining('end').last);
    final usageRect = tester.getRect(find.text('Thread usage'));
    expect(usageRect.top, lessThan(endRect.top));
  });
}
