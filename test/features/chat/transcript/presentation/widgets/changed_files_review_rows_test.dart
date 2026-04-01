import 'ui_block_surface_test_support.dart';

void main() {
  testWidgets('matches renamed files by old-path aliases', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptChangedFilesBlock(
            id: 'diff_rename_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <TranscriptChangedFile>[
              TranscriptChangedFile(path: 'lib/new_name.dart'),
            ],
            unifiedDiff:
                'diff --git a/lib/old_name.dart b/lib/new_name.dart\n'
                'similarity index 88%\n'
                'rename from lib/old_name.dart\n'
                'rename to lib/new_name.dart\n'
                '--- a/lib/old_name.dart\n'
                '+++ b/lib/new_name.dart\n'
                '@@ -1 +1 @@\n'
                '-oldName();\n'
                '+newName();\n',
          ),
        ),
      ),
    );

    expect(find.text('Renamed from lib/old_name.dart'), findsOneWidget);
    expect(find.text('new_name.dart'), findsOneWidget);

    await tester.tap(find.text('new_name.dart'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close diff'), findsOneWidget);
    expect(find.text('Additions'), findsOneWidget);
    expect(find.text('Deletions'), findsOneWidget);
    expect(
      find.textContaining(
        'diff --git a/lib/old_name.dart b/lib/new_name.dart',
        findRichText: true,
      ),
      findsNothing,
    );

    await tester.tap(find.text('Raw patch'));
    await tester.pumpAndSettle();

    expect(find.text('Readable view'), findsOneWidget);
    expect(
      find.textContaining(
        'diff --git a/lib/old_name.dart b/lib/new_name.dart',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders binary files as binary review surfaces', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptChangedFilesBlock(
            id: 'diff_binary_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <TranscriptChangedFile>[
              TranscriptChangedFile(path: 'assets/logo.png'),
            ],
            unifiedDiff:
                'diff --git a/assets/logo.png b/assets/logo.png\n'
                'Binary files a/assets/logo.png and b/assets/logo.png differ\n',
          ),
        ),
      ),
    );

    expect(find.text('Binary · edited'), findsOneWidget);
    expect(find.text('logo.png'), findsOneWidget);

    await tester.tap(find.text('logo.png'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Binary'), findsWidgets);
    expect(
      find.textContaining(
        'Binary files a/assets/logo.png and b/assets/logo.png differ',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders created, edited, and deleted file rows with distinct treatments',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptChangedFilesBlock(
              id: 'diff_states_1',
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Changed files',
              files: const <TranscriptChangedFile>[
                TranscriptChangedFile(path: 'lib/new_file.dart', additions: 3),
                TranscriptChangedFile(
                  path: 'lib/edited_file.dart',
                  additions: 2,
                  deletions: 1,
                ),
                TranscriptChangedFile(
                  path: 'lib/deleted_file.dart',
                  deletions: 4,
                ),
              ],
              unifiedDiff:
                  'diff --git a/lib/new_file.dart b/lib/new_file.dart\n'
                  'new file mode 100644\n'
                  '--- /dev/null\n'
                  '+++ b/lib/new_file.dart\n'
                  '@@ -0,0 +1,3 @@\n'
                  '+first\n'
                  '+second\n'
                  '+third\n'
                  'diff --git a/lib/edited_file.dart b/lib/edited_file.dart\n'
                  '--- a/lib/edited_file.dart\n'
                  '+++ b/lib/edited_file.dart\n'
                  '@@ -1,2 +1,3 @@\n'
                  ' same\n'
                  '-old\n'
                  '+new\n'
                  '+extra\n'
                  'diff --git a/lib/deleted_file.dart b/lib/deleted_file.dart\n'
                  'deleted file mode 100644\n'
                  '--- a/lib/deleted_file.dart\n'
                  '+++ /dev/null\n'
                  '@@ -1,4 +0,0 @@\n'
                  '-gone1\n'
                  '-gone2\n'
                  '-gone3\n'
                  '-gone4\n',
            ),
          ),
        ),
      );

      expect(find.text('Dart · created'), findsOneWidget);
      expect(find.text('Dart · edited'), findsOneWidget);
      expect(find.text('Dart · deleted'), findsOneWidget);

      final createdColor = findDecoratedContainerColorForText(
        tester,
        'lib/new_file.dart',
      );
      final editedColor = findDecoratedContainerColorForText(
        tester,
        'lib/edited_file.dart',
      );
      final deletedColor = findDecoratedContainerColorForText(
        tester,
        'lib/deleted_file.dart',
      );

      expect(createdColor, isNull);
      expect(editedColor, isNull);
      expect(deletedColor, isNull);
    },
  );

  testWidgets('derives file rows from diff-only payloads without git headers', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptChangedFilesBlock(
            id: 'diff_only_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            unifiedDiff:
                '--- a/lib/first.dart\n'
                '+++ b/lib/first.dart\n'
                '@@ -1 +1 @@\n'
                '-old first\n'
                '+new first\n'
                '--- a/lib/second.dart\n'
                '+++ b/lib/second.dart\n'
                '@@ -2 +2 @@\n'
                '-old second\n'
                '+new second\n',
          ),
        ),
      ),
    );

    expect(
      find.text('2 files changed · 2 additions · 2 deletions'),
      findsOneWidget,
    );
    expect(find.text('first.dart'), findsOneWidget);
    expect(find.text('second.dart'), findsOneWidget);

    await tester.tap(find.text('second.dart'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('new second', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('old second', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('shows a bounded preview for very large diffs', (tester) async {
    final diffLines = <String>[
      'diff --git a/lib/large.dart b/lib/large.dart',
      '--- a/lib/large.dart',
      '+++ b/lib/large.dart',
      '@@ -1,0 +1,360 @@',
      for (var index = 0; index < 360; index += 1) '+line $index',
    ];

    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptChangedFilesBlock(
            id: 'diff_large_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <TranscriptChangedFile>[
              TranscriptChangedFile(path: 'lib/large.dart', additions: 360),
            ],
            unifiedDiff: diffLines.join('\n'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('large.dart'));
    await tester.pumpAndSettle();

    expect(find.text('Load full diff'), findsOneWidget);
    expect(
      find.text(
        'Showing the first 320 lines to keep the review surface responsive.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('line 315', findRichText: true), findsOneWidget);
    expect(find.textContaining('line 359', findRichText: true), findsNothing);

    await tester.tap(find.text('Load full diff'));
    await tester.pumpAndSettle();

    expect(find.text('Show preview'), findsOneWidget);
    expect(find.textContaining('line 359', findRichText: true), findsOneWidget);
  });
}
