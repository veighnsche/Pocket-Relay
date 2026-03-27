import 'screen_app_server_test_support.dart';

void main() {
  testWidgets('renders consecutive work items in one grouped work surface', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_cmd_1',
            'type': 'commandExecution',
            'status': 'completed',
            'command': 'git status',
            'result': <String, Object?>{'output': 'clean', 'exitCode': 0},
          },
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
            'id': 'item_search_2',
            'type': 'webSearch',
            'status': 'completed',
            'title': 'Search docs',
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Work log'), findsOneWidget);
    expect(find.text('Checking worktree status'), findsOneWidget);
    expect(find.text('Current repository'), findsOneWidget);
    expect(find.text('git status'), findsNothing);
    expect(find.text('Search docs'), findsOneWidget);
  });

  testWidgets('renders web-search items with query-focused work-log copy', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_search_1',
            'type': 'webSearch',
            'status': 'completed',
            'title': 'Search docs',
            'query': 'Pocket Relay CLI',
            'result': <String, Object?>{
              'summary': 'Found CLI reference and API notes',
            },
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Work log'), findsNothing);
    expect(find.text('Searched'), findsOneWidget);
    expect(find.text('Pocket Relay CLI'), findsOneWidget);
    expect(find.text('Found CLI reference and API notes'), findsOneWidget);
    expect(find.text('Search docs'), findsNothing);
  });

  testWidgets('strips shell-wrapper noise from command work-log titles', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_cmd_1',
            'type': 'commandExecution',
            'status': 'completed',
            'command': '/usr/bin/zsh -lc "sed -n \'1,40p\' lib/main.dart"',
            'result': <String, Object?>{
              'output': 'class App {}',
              'exitCode': 0,
            },
          },
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reading lines 1 to 40'), findsOneWidget);
    expect(find.text('main.dart'), findsOneWidget);
    expect(find.text('lib/main.dart'), findsOneWidget);
    expect(find.text("sed -n '1,40p' lib/main.dart"), findsNothing);
    expect(find.textContaining('/usr/bin/zsh -lc'), findsNothing);
  });

  testWidgets('renders plain command executions as dedicated work-log rows', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'item/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'item': <String, Object?>{
            'id': 'item_cmd_plain_1',
            'type': 'commandExecution',
            'status': 'inProgress',
            'command': 'pwd',
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
          'itemId': 'item_cmd_plain_1',
          'delta': '/repo',
        },
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Work log'), findsNothing);
    expect(find.text('Running command'), findsOneWidget);
    expect(find.text('pwd'), findsOneWidget);
    expect(find.text('/repo'), findsOneWidget);
  });

  testWidgets(
    'renders empty-stdin terminal interactions as dedicated command wait rows',
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
              'id': 'item_cmd_wait_1',
              'type': 'commandExecution',
              'status': 'inProgress',
              'command': 'sleep 5',
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
            'itemId': 'item_cmd_wait_1',
            'delta': 'still running',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/terminalInteraction',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_cmd_wait_1',
            'processId': 'proc_1',
            'stdin': '',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Work log'), findsNothing);
      expect(find.text('waiting'), findsOneWidget);
      expect(find.text('Waiting for background terminal'), findsOneWidget);
      expect(find.text('sleep 5'), findsOneWidget);
      expect(find.text('still running'), findsOneWidget);
      expect(find.text('Running command'), findsNothing);
    },
  );

  testWidgets(
    'returns command wait rows to running command rows when output resumes',
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
              'id': 'item_cmd_wait_resume_1',
              'type': 'commandExecution',
              'status': 'inProgress',
              'command': 'sleep 5',
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
            'itemId': 'item_cmd_wait_resume_1',
            'delta': 'still running',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/terminalInteraction',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_cmd_wait_resume_1',
            'processId': 'proc_2',
            'stdin': '',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Waiting for background terminal'), findsOneWidget);
      expect(find.text('Running command'), findsNothing);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_cmd_wait_resume_1',
            'delta': '\nready',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Running command'), findsOneWidget);
      expect(find.text('sleep 5'), findsOneWidget);
      expect(find.text('ready'), findsOneWidget);
      expect(find.text('Waiting for background terminal'), findsNothing);
    },
  );
}
