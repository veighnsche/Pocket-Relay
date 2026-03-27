import 'screen_app_server_test_support.dart';

void main() {
  testWidgets(
    'renders one grouped changed-files surface for a multi-file file-change item',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(appServerClient: appServerClient),
      );

      await tester.pump(const Duration(milliseconds: 200));

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'inProgress',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/fileChange/outputDelta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'file_change_1',
            'delta': 'apply_patch exited successfully',
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
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'completed',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\nsecond line\n',
                },
                <String, Object?>{
                  'path': 'lib/app.dart',
                  'kind': <String, Object?>{
                    'type': 'update',
                    'move_path': null,
                  },
                  'diff':
                      '--- a/lib/app.dart\n'
                      '+++ b/lib/app.dart\n'
                      '@@ -1 +1,2 @@\n'
                      '-old\n'
                      '+new\n'
                      '+second\n',
                },
              ],
            },
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Changed files'), findsOneWidget);
      expect(
        find.text('2 files changed · 4 additions · 1 deletions'),
        findsOneWidget,
      );
      expect(find.text('README.md'), findsOneWidget);
      expect(find.text('app.dart'), findsOneWidget);

      await tester.tap(find.text('README.md'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.textContaining('first line', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('second line', findRichText: true),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'keeps interrupted assistant history as separate cards when the same item resumes',
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
            'delta': 'First',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'configWarning',
          params: <String, Object?>{'summary': 'Intervening warning'},
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/agentMessage/delta',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'item_1',
            'delta': 'Second',
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    },
  );

  testWidgets(
    'keeps assistant, work, and resumed assistant in chronological order',
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
              'id': 'assistant_1',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'Before work',
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
              'id': 'command_1',
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
              'id': 'assistant_2',
              'type': 'agentMessage',
              'status': 'completed',
              'text': 'After work',
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      final beforeWorkDy = tester.getTopLeft(find.text('Before work')).dy;
      final workDy = tester
          .getTopLeft(find.text('Checking worktree status'))
          .dy;
      final afterWorkDy = tester.getTopLeft(find.text('After work')).dy;

      expect(find.text('Work log'), findsOneWidget);
      expect(beforeWorkDy, lessThan(workDy));
      expect(workDy, lessThan(afterWorkDy));
    },
  );
}
