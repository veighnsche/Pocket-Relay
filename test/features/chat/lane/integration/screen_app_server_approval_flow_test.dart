import 'screen_app_server_test_support.dart';

void main() {
  testWidgets('approval actions are routed to the app-server client', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await pumpAppReady(tester);

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

  testWidgets('freezes a running assistant surface when approval opens', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(buildCatalogApp(appServerClient: appServerClient));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

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
        requestId: 'i:99',
        method: 'item/fileChange/requestApproval',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'assistant_1',
          'reason': 'Write files',
        },
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Before request'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('File change approval'), findsOneWidget);
  });

  testWidgets(
    'keeps pending approvals off the transcript until resolution and preserves chronology',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await pumpAppReady(tester);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'assistant_before',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'Before request',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:99',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'assistant_before',
            'reason': 'Write files',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Before request'), findsOneWidget);
      expect(find.text('File change approval'), findsOneWidget);
      expect(find.text('File change approval resolved'), findsNothing);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{'threadId': 'thread_123', 'requestId': 99},
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'assistant_after',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'After request',
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('File change approval'), findsNothing);
      expect(find.text('File change approval resolved'), findsOneWidget);

      final beforeRequestDy = tester.getTopLeft(find.text('Before request')).dy;
      final resolvedDy = tester
          .getTopLeft(find.text('File change approval resolved'))
          .dy;
      final afterRequestDy = tester.getTopLeft(find.text('After request')).dy;

      expect(beforeRequestDy, lessThan(resolvedDy));
      expect(resolvedDy, lessThan(afterRequestDy));
    },
  );

  testWidgets(
    'freezes running work before approval opens and resumes work after resolution',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Work log'), findsOneWidget);
      expect(find.text('Checking worktree status'), findsOneWidget);
      expect(find.text('running'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:99',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'command_1',
            'reason': 'Write files',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Checking worktree status'), findsOneWidget);
      expect(find.text('running'), findsNothing);
      expect(find.text('File change approval'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{'threadId': 'thread_123', 'requestId': 99},
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'search_2',
              'type': 'webSearch',
              'status': 'completed',
              'title': 'Search docs',
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Work log'), findsOneWidget);
      expect(find.text('File change approval resolved'), findsOneWidget);
      expect(find.text('Search docs'), findsOneWidget);

      final firstWorkDy = tester
          .getTopLeft(find.text('Checking worktree status'))
          .dy;
      final resolvedDy = tester
          .getTopLeft(find.text('File change approval resolved'))
          .dy;
      final resumedWorkDy = tester.getTopLeft(find.text('Search docs')).dy;

      expect(firstWorkDy, lessThan(resolvedDy));
      expect(resolvedDy, lessThan(resumedWorkDy));
    },
  );
}
