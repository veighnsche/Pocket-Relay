import 'screen_app_server_test_support.dart';

void main() {
  testWidgets(
    'keeps a single local user prompt when the app-server echoes it back',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(agentAdapterClient: appServerClient),
      );

      await pumpAppReady(tester);

      await tester.enterText(
        find.byKey(const ValueKey('composer_input')),
        'Hello Codex',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

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
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'running'},
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'configWarning',
          params: <String, Object?>{
            'summary': 'Connected to the remote session.',
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/updated',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'item_user_1',
              'type': 'userMessage',
              'status': 'inProgress',
              'text': 'Hello Codex',
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
              'id': 'item_user_1',
              'type': 'userMessage',
              'status': 'completed',
              'text': 'Hello Codex',
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hello Codex'), findsOneWidget);
      expect(find.text('You'), findsNothing);
      expect(find.text('local echo'), findsNothing);
      expect(find.text('sent'), findsNothing);
      expect(find.byType(SelectableText), findsWidgets);
      expect(
        find.textContaining('Connected to the remote session.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'consolidates sequential distinct file-change items into one changed-files surface',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(agentAdapterClient: appServerClient),
      );

      await pumpAppReady(tester);

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
                  'diff': 'first line\n',
                },
              ],
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
              'id': 'file_change_2',
              'type': 'fileChange',
              'status': 'completed',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'lib/app.dart',
                  'kind': <String, Object?>{'type': 'update'},
                  'diff':
                      '--- a/lib/app.dart\n'
                      '+++ b/lib/app.dart\n'
                      '@@ -1 +1 @@\n'
                      '-old\n'
                      '+new\n',
                },
              ],
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Changed files'), findsOneWidget);
      expect(
        find.text('2 files changed · 2 additions · 1 deletions'),
        findsOneWidget,
      );
      final readmeDy = tester.getTopLeft(find.text('README.md')).dy;
      final appDy = tester.getTopLeft(find.text('app.dart')).dy;
      expect(readmeDy, lessThan(appDy));
    },
  );

  testWidgets(
    'starts a new changed-files surface when the same file-change item resumes after a warning',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(agentAdapterClient: appServerClient),
      );

      await pumpAppReady(tester);

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
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\n',
                },
              ],
            },
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
                  'diff': 'first line\n',
                },
                <String, Object?>{
                  'path': 'lib/app.dart',
                  'kind': <String, Object?>{'type': 'update'},
                  'diff':
                      '--- a/lib/app.dart\n'
                      '+++ b/lib/app.dart\n'
                      '@@ -1 +1 @@\n'
                      '-old\n'
                      '+new\n',
                },
              ],
            },
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Changed files'), findsNWidgets(2));
      expect(find.text('README.md'), findsNWidgets(2));
      expect(find.text('app.dart'), findsOneWidget);
      expect(find.textContaining('Intervening warning'), findsOneWidget);

      final firstChangedFilesDy = tester
          .getTopLeft(find.text('Changed files').first)
          .dy;
      final warningDy = tester
          .getTopLeft(find.textContaining('Intervening warning'))
          .dy;
      final secondChangedFilesDy = tester
          .getTopLeft(find.text('Changed files').last)
          .dy;

      expect(firstChangedFilesDy, lessThan(warningDy));
      expect(warningDy, lessThan(secondChangedFilesDy));
    },
  );
}
