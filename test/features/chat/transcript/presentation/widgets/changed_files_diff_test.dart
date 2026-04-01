import 'ui_block_surface_test_support.dart';

void main() {
  testWidgets('renders changed files summary and opens a per-file diff sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptChangedFilesBlock(
            id: 'diff_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <TranscriptChangedFile>[
              TranscriptChangedFile(
                path: 'lib/src/features/chat/chat_screen.dart',
                additions: 3,
                deletions: 1,
              ),
              TranscriptChangedFile(
                path:
                    'lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart',
                additions: 8,
                deletions: 2,
              ),
            ],
            unifiedDiff:
                'diff --git a/lib/src/features/chat/chat_screen.dart b/lib/src/features/chat/chat_screen.dart\n'
                '--- a/lib/src/features/chat/chat_screen.dart\n'
                '+++ b/lib/src/features/chat/chat_screen.dart\n'
                '@@ -1 +1 @@\n'
                '-old screen\n'
                '+new screen\n'
                'diff --git a/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart b/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart\n'
                '--- a/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart\n'
                '+++ b/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart\n'
                '@@ -2 +2 @@\n'
                '-old card\n'
                '+new card\n',
          ),
        ),
      ),
    );

    expect(
      find.text('2 files changed · 11 additions · 3 deletions'),
      findsOneWidget,
    );
    expect(find.text('Show diff'), findsNothing);

    await tester.tap(find.text('conversation_entry_renderer.dart'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart',
      ),
      findsWidgets,
    );
    expect(find.text('Additions'), findsOneWidget);
    expect(find.text('Deletions'), findsOneWidget);
    expect(find.text('Dart'), findsWidgets);
    expect(find.textContaining('new card', findRichText: true), findsOneWidget);
    expect(
      find.textContaining(
        'diff --git a/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart',
        findRichText: true,
      ),
      findsNothing,
    );

    await tester.tap(find.text('Raw patch'));
    await tester.pumpAndSettle();

    expect(find.text('Readable view'), findsOneWidget);
    expect(
      find.textContaining(
        'diff --git a/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not attach a single patch to unrelated file rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptChangedFilesBlock(
            id: 'diff_unmatched_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <TranscriptChangedFile>[
              TranscriptChangedFile(path: 'README.md'),
              TranscriptChangedFile(
                path: 'lib/app.dart',
                additions: 1,
                deletions: 1,
              ),
            ],
            unifiedDiff:
                'diff --git a/lib/app.dart b/lib/app.dart\n'
                '--- a/lib/app.dart\n'
                '+++ b/lib/app.dart\n'
                '@@ -1 +1 @@\n'
                '-old\n'
                '+new\n',
          ),
        ),
      ),
    );

    expect(find.textContaining('patch unavailable'), findsOneWidget);
    expect(find.text('README.md'), findsOneWidget);
  });

  testWidgets(
    'routes changed-file diff opening through the callback boundary',
    (tester) async {
      ChatChangedFileDiffContract? openedDiff;

      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptChangedFilesBlock(
              id: 'diff_callback_1',
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Changed files',
              files: const <TranscriptChangedFile>[
                TranscriptChangedFile(
                  path: 'lib/app.dart',
                  additions: 1,
                  deletions: 1,
                ),
              ],
              unifiedDiff:
                  'diff --git a/lib/app.dart b/lib/app.dart\n'
                  '--- a/lib/app.dart\n'
                  '+++ b/lib/app.dart\n'
                  '@@ -1 +1 @@\n'
                  '-old\n'
                  '+new\n',
            ),
            onOpenChangedFileDiff: (diff) {
              openedDiff = diff;
            },
          ),
        ),
      );

      await tester.tap(find.text('app.dart'));
      await tester.pump();

      expect(openedDiff, isNotNull);
      expect(openedDiff?.displayPathLabel, 'lib/app.dart');
      expect(openedDiff?.stats.additions, 1);
      expect(openedDiff?.stats.deletions, 1);
      expect(find.text('+new'), findsNothing);
    },
  );
}
