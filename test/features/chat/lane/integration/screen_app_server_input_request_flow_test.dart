import 'screen_app_server_test_support.dart';

void main() {
  testWidgets(
    'promotes the next pending approval without broadening the pinned approval surface',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:101',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'reason': 'Write the first file',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:102',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_2',
            'reason': 'Write the second file',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Write the first file'), findsOneWidget);
      expect(find.text('Write the second file'), findsNothing);
      expect(find.text('File change approval'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{'threadId': 'thread_123', 'requestId': 101},
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Write the first file'), findsNothing);
      expect(find.text('Write the second file'), findsOneWidget);
      expect(find.text('File change approval'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the live turn timer above the composer without needing an assistant block',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{'id': 'thread_123'},
          },
        ),
      );
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.textContaining('Elapsed'), findsOneWidget);
      expect(find.text('Assistant message'), findsNothing);

      final timerChip = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.padding ==
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      );
      final timerRect = tester.getRect(timerChip);
      final inputRect = tester.getRect(
        find.byKey(const ValueKey('composer_input')),
      );

      expect(timerRect.top, lessThan(inputRect.top));
      expect(inputRect.top - timerRect.bottom, greaterThan(0));
    },
  );

  testWidgets(
    'user-input requests are submitted through the app-server client',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

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
      expect(appServerClient.elicitationResponses, isEmpty);
    },
  );

  testWidgets(
    'promotes the next pending user-input request without leaking the prior draft',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

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
                'header': 'Project',
                'question': 'Which first project should I use?',
              },
            ],
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 's:user-input-2',
          method: 'item/tool/requestUserInput',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_2',
            'questions': <Object>[
              <String, Object?>{
                'id': 'q1',
                'header': 'Project',
                'question': 'Which second project should I use?',
              },
            ],
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Which first project should I use?'), findsOneWidget);
      expect(find.text('Which second project should I use?'), findsNothing);

      final textField = find.byKey(
        const ValueKey<String>('pending_user_input_q1'),
      );
      await tester.enterText(textField, 'Pocket Relay');
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
          'q1': <String>['Pocket Relay'],
        },
      );

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/tool/requestUserInput/answered',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'requestId': 'user-input-1',
            'answers': <String, Object?>{
              'q1': <String, Object?>{
                'answers': <String>['Pocket Relay'],
              },
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Which first project should I use?'), findsNothing);
      expect(find.text('Which second project should I use?'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey<String>('pending_user_input_q1')),
            )
            .controller
            ?.text,
        isEmpty,
      );
    },
  );

  testWidgets(
    'mcp elicitation requests are submitted through the elicitation response path',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 's:elicitation-1',
          method: 'mcpServer/elicitation/request',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'serverName': 'filesystem',
            'message': 'Choose a directory',
            'mode': 'form',
            'requestedSchema': <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'path': <String, Object?>{'type': 'string'},
              },
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('MCP input required'), findsOneWidget);
      expect(find.text('Choose a directory'), findsOneWidget);

      final responseField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Response',
      );

      await tester.enterText(responseField, '/workspace/mobile');
      await tester.ensureVisible(find.text('Submit response'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit response'));
      await tester.pumpAndSettle();

      expect(appServerClient.userInputResponses, isEmpty);
      expect(appServerClient.elicitationResponses, hasLength(1));
      expect(
        appServerClient.elicitationResponses.single.requestId,
        's:elicitation-1',
      );
      expect(
        appServerClient.elicitationResponses.single.action,
        CodexAppServerElicitationAction.accept,
      );
      expect(
        appServerClient.elicitationResponses.single.content,
        '/workspace/mobile',
      );
    },
  );

  testWidgets(
    'keeps the richer user-input transcript surface when a generic resolved event arrives later',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

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
              },
            ],
          },
        ),
      );

      await tester.pumpAndSettle();

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/tool/requestUserInput/answered',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'requestId': 'user-input-1',
            'answers': <String, Object?>{
              'q1': <Object>['Vince'],
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Input submitted'), findsOneWidget);
      expect(find.textContaining('Vince'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'requestId': 'user-input-1',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Input submitted'), findsOneWidget);
      expect(find.textContaining('Vince'), findsOneWidget);
      expect(find.text('Input required resolved'), findsNothing);
      expect(find.text('Request resolved'), findsNothing);
    },
  );
}
