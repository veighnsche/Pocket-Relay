import 'screen_app_server_test_support.dart';

void main() {
  testWidgets('sends prompts through app-server and renders assistant output', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient()
      ..startSessionCwd = '/Users/vince/Projects/Pocket-Relay'
      ..startSessionModel = 'gpt-5.4';
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

    final composerField = find.byKey(const ValueKey('composer_input'));
    await tester.enterText(composerField, 'Hello Codex');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(appServerClient.connectCalls, 1);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.sentMessages, <String>['Hello Codex']);
    expect(find.text('Hello Codex'), findsOneWidget);
    expect(tester.widget<TextField>(composerField).controller?.text, isEmpty);
    expect(find.text('Developer Box'), findsOneWidget);
    expect(find.text('example.com · gpt-5.4'), findsOneWidget);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_1',
            'status': 'running',
            'model': 'gpt-5.4',
            'effort': 'high',
          },
        },
      ),
    );
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
    expect(find.textContaining('end'), findsOneWidget);
  });

  testWidgets('keeps the composer text when sending the prompt fails', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient()
      ..sendUserMessageError = StateError('transport broke');
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

    final composerField = find.byKey(const ValueKey('composer_input'));
    await tester.enterText(composerField, 'Hello Codex');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(appServerClient.connectCalls, 1);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.sentMessages, isEmpty);
    expect(
      tester.widget<TextField>(composerField).controller?.text,
      'Hello Codex',
    );
    expect(find.textContaining('Could not send the prompt'), findsWidgets);
  });

  testWidgets(
    'blocks sending after a missing conversation until the user starts fresh',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      final composerField = find.byKey(const ValueKey('composer_input'));
      await tester.enterText(composerField, 'First prompt');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await tester.pumpAndSettle();

      appServerClient.sendUserMessageError = const CodexAppServerException(
        'turn/start failed: thread not found',
      );

      await tester.enterText(composerField, 'Second prompt');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(find.text("This conversation can't continue."), findsOneWidget);
      expect(find.text('Start new conversation'), findsOneWidget);
      expect(
        tester.widget<TextField>(composerField).controller?.text,
        'Second prompt',
      );

      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentMessages, <String>['First prompt']);

      await tester.tap(
        find.byKey(
          const ValueKey('conversation_recovery_startFreshConversation'),
        ),
      );
      await tester.pumpAndSettle();
      appServerClient.sendUserMessageError = null;

      expect(find.text("This conversation can't continue."), findsNothing);

      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(appServerClient.startSessionCalls, 2);
      expect(appServerClient.sentMessages, <String>[
        'First prompt',
        'Second prompt',
      ]);
    },
  );

  testWidgets(
    'startup keeps the lane fresh until the user explicitly picks conversation history',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_old'] = const CodexAppServerThreadHistory(
          id: 'thread_old',
          name: 'Saved conversation',
          sourceKind: 'app-server',
          turns: <CodexAppServerHistoryTurn>[
            CodexAppServerHistoryTurn(
              id: 'turn_saved',
              status: 'completed',
              items: <CodexAppServerHistoryItem>[
                CodexAppServerHistoryItem(
                  id: 'item_user',
                  type: 'user_message',
                  status: 'completed',
                  raw: <String, dynamic>{
                    'id': 'item_user',
                    'type': 'user_message',
                    'status': 'completed',
                    'content': <Object>[
                      <String, Object?>{'text': 'Restore this'},
                    ],
                  },
                ),
                CodexAppServerHistoryItem(
                  id: 'item_assistant',
                  type: 'agent_message',
                  status: 'completed',
                  raw: <String, dynamic>{
                    'id': 'item_assistant',
                    'type': 'agent_message',
                    'status': 'completed',
                    'content': <Object>[
                      <String, Object?>{'text': 'Restored answer'},
                    ],
                  },
                ),
              ],
              raw: <String, dynamic>{
                'id': 'turn_saved',
                'status': 'completed',
                'items': <Object>[
                  <String, Object?>{
                    'id': 'item_user',
                    'type': 'user_message',
                    'status': 'completed',
                    'content': <Object>[
                      <String, Object?>{'text': 'Restore this'},
                    ],
                  },
                  <String, Object?>{
                    'id': 'item_assistant',
                    'type': 'agent_message',
                    'status': 'completed',
                    'content': <Object>[
                      <String, Object?>{'text': 'Restored answer'},
                    ],
                  },
                ],
              },
            ),
          ],
        );
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);
      expect(find.text('Restored answer'), findsNothing);

      final composerField = find.byKey(const ValueKey('composer_input'));
      await tester.enterText(composerField, 'Start fresh from this lane');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(find.text('Conversation identity changed.'), findsNothing);
      expect(appServerClient.startSessionCalls, 1);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        isNull,
      );
      expect(appServerClient.sentMessages, <String>[
        'Start fresh from this lane',
      ]);
    },
  );
}
