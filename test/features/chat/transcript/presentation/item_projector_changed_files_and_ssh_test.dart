import '../../support/screen_presentation_test_support.dart';

void main() {
  group('ChatTranscriptItemProjector', () {
    const projector = ChatTranscriptItemProjector();

    test(
      'projects changed-files blocks into structured changed-files item contracts',
      () {
        final block = CodexChangedFilesBlock(
          id: 'changed_files_1',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Changed files',
          files: const <CodexChangedFile>[
            CodexChangedFile(path: 'lib/app.dart', additions: 1),
          ],
          unifiedDiff:
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -1 +1 @@\n'
              '-old\n'
              '+new\n',
        );

        final item = projector.project(block);

        expect(item, isA<ChatChangedFilesItemContract>());
        final changedFilesItem = item as ChatChangedFilesItemContract;
        expect(changedFilesItem.id, block.id);
        expect(changedFilesItem.title, block.title);
        expect(changedFilesItem.fileCount, 1);
        expect(changedFilesItem.headerStats.additions, 1);
        expect(changedFilesItem.headerStats.deletions, 1);
        expect(changedFilesItem.rows.single.displayPathLabel, 'lib/app.dart');
        expect(changedFilesItem.rows.single.fileName, 'app.dart');
        expect(changedFilesItem.rows.single.languageLabel, 'Dart');
        expect(changedFilesItem.rows.single.stats.deletions, 1);
        expect(changedFilesItem.rows.single.diff, isNotNull);
        expect(changedFilesItem.rows.single.diff?.syntaxLanguage, 'dart');
        expect(
          changedFilesItem.rows.single.diff?.lines.first.text,
          'diff --git a/lib/app.dart b/lib/app.dart',
        );
        expect(changedFilesItem.rows.single.diff?.lines[4].oldLineNumber, 1);
        expect(changedFilesItem.rows.single.diff?.lines[5].newLineNumber, 1);
      },
    );

    test(
      'projects renamed files with current-path metadata and rename state',
      () {
        final block = CodexChangedFilesBlock(
          id: 'changed_files_rename_1',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Changed files',
          files: const <CodexChangedFile>[
            CodexChangedFile(path: 'lib/new.dart'),
          ],
          unifiedDiff:
              'diff --git a/lib/old.dart b/lib/new.dart\n'
              'similarity index 88%\n'
              'rename from lib/old.dart\n'
              'rename to lib/new.dart\n'
              '--- a/lib/old.dart\n'
              '+++ b/lib/new.dart\n'
              '@@ -1 +1 @@\n'
              '-oldName();\n'
              '+newName();\n',
        );

        final item = projector.project(block) as ChatChangedFilesItemContract;
        final row = item.rows.single;

        expect(row.operationKind, ChatChangedFileOperationKind.renamed);
        expect(row.previousPath, 'lib/old.dart');
        expect(row.currentPath, 'lib/new.dart');
        expect(row.languageLabel, 'Dart');
        expect(row.diff?.operationKind, ChatChangedFileOperationKind.renamed);
        expect(row.diff?.syntaxLanguage, 'dart');
        expect(row.diff?.lines.last.text, '+newName();');
      },
    );

    test(
      'keeps hunk lines that look like diff headers as real additions and deletions',
      () {
        final block = CodexChangedFilesBlock(
          id: 'changed_files_header_like_lines_1',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Changed files',
          files: const <CodexChangedFile>[
            CodexChangedFile(path: 'lib/app.dart'),
          ],
          unifiedDiff:
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -1,2 +1,2 @@\n'
              '--- old flag\n'
              '-keep old branch\n'
              '+++ new flag\n'
              '+keep new branch\n',
        );

        final item = projector.project(block) as ChatChangedFilesItemContract;
        final diff = item.rows.single.diff!;

        expect(diff.stats.additions, 2);
        expect(diff.stats.deletions, 2);
        expect(diff.lines[4].kind, ChatChangedFileDiffLineKind.deletion);
        expect(diff.lines[4].oldLineNumber, 1);
        expect(diff.lines[6].kind, ChatChangedFileDiffLineKind.addition);
        expect(diff.lines[6].newLineNumber, 1);
      },
    );

    test('projects binary diffs as binary review items', () {
      final block = CodexChangedFilesBlock(
        id: 'changed_files_binary_1',
        createdAt: DateTime(2026, 3, 15, 12),
        title: 'Changed files',
        files: const <CodexChangedFile>[
          CodexChangedFile(path: 'assets/logo.png'),
        ],
        unifiedDiff:
            'diff --git a/assets/logo.png b/assets/logo.png\n'
            'Binary files a/assets/logo.png and b/assets/logo.png differ\n',
      );

      final item = projector.project(block) as ChatChangedFilesItemContract;
      final row = item.rows.single;

      expect(row.languageLabel, 'Binary');
      expect(row.isBinary, isTrue);
      expect(row.diff, isNotNull);
      expect(row.diff?.syntaxLanguage, isNull);
      expect(row.diff?.isBinary, isTrue);
      expect(row.diff?.lines.last.kind, ChatChangedFileDiffLineKind.meta);
    });

    test('projects SSH transcript blocks into SSH item contracts', () {
      final block = CodexSshConnectFailedBlock(
        id: 'ssh_connect_failed_1',
        createdAt: DateTime(2026, 3, 15, 12),
        host: 'example.com',
        port: 22,
        message: 'Connection refused',
      );

      final item = projector.project(block);

      expect(item, isA<ChatSshItemContract>());
      final sshItem = item as ChatSshItemContract;
      expect(sshItem.block, same(block));
    });

    test(
      'derives changed-files header totals from resolved row stats when file payloads are partial',
      () {
        final block = CodexChangedFilesBlock(
          id: 'changed_files_mixed_1',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Changed files',
          files: const <CodexChangedFile>[
            CodexChangedFile(path: 'README.md', additions: 1),
            CodexChangedFile(path: 'lib/app.dart'),
          ],
          unifiedDiff:
              'diff --git a/README.md b/README.md\n'
              '--- a/README.md\n'
              '+++ b/README.md\n'
              '@@ -1 +1 @@\n'
              '-old readme\n'
              '+new readme\n'
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -1 +1,2 @@\n'
              '-old app\n'
              '+new app\n'
              '+second line\n',
        );

        final item = projector.project(block) as ChatChangedFilesItemContract;

        expect(item.headerStats.additions, 3);
        expect(item.headerStats.deletions, 2);
        expect(item.rows[1].stats.additions, 2);
        expect(item.rows[1].stats.deletions, 1);
      },
    );
  });
}
