import 'screen_app_server_test_support.dart';

void main() {
  testWidgets(
    'starts a new changed-files surface when the same file-change item resumes after approval',
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

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Changed files'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
      expect(find.text('updating'), findsOneWidget);

      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'i:99',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'itemId': 'file_change_1',
            'reason': 'Write files',
          },
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Changed files'), findsOneWidget);
      expect(find.text('updating'), findsNothing);
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

      final firstChangedFilesEntry = find.byKey(
        const ValueKey('transcript_changed_files_group_item_file_change_1'),
      );
      final resolvedApprovalEntry = find.byKey(
        const ValueKey('transcript_request_i:99'),
      );
      final resumedChangedFilesEntry = find.byKey(
        const ValueKey('transcript_changed_files_group_item_file_change_1-2'),
      );

      expect(resolvedApprovalEntry, findsOneWidget);
      expect(resumedChangedFilesEntry, findsOneWidget);
      expect(
        find.descendant(
          of: resumedChangedFilesEntry,
          matching: find.text('Changed files'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: resumedChangedFilesEntry,
          matching: find.text('README.md'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: resumedChangedFilesEntry,
          matching: find.text('app.dart'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: resolvedApprovalEntry,
          matching: find.text('File change approval resolved'),
        ),
        findsOneWidget,
      );
      final resolvedDy = tester.getTopLeft(resolvedApprovalEntry).dy;
      final resumedChangedFilesDy = tester
          .getTopLeft(resumedChangedFilesEntry)
          .dy;

      expect(resolvedDy, lessThan(resumedChangedFilesDy));

      final transcriptScrollable = find.byType(Scrollable).first;
      for (
        var attempt = 0;
        attempt < 8 && firstChangedFilesEntry.evaluate().isEmpty;
        attempt += 1
      ) {
        await tester.drag(transcriptScrollable, const Offset(0, 200));
        await tester.pumpAndSettle();
      }

      expect(firstChangedFilesEntry, findsOneWidget);
      expect(
        find.descendant(
          of: firstChangedFilesEntry,
          matching: find.text('Changed files'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: firstChangedFilesEntry,
          matching: find.text('README.md'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: firstChangedFilesEntry,
          matching: find.text('app.dart'),
        ),
        findsNothing,
      );
    },
  );
}
