import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_changed_files_parser.dart';

void main() {
  const parser = TranscriptChangedFilesParser();

  test('extracts changed files and line counts from unified diff text', () {
    final files = parser.changedFilesFromSources(
      body:
          'diff --git a/lib/main.dart b/lib/main.dart\n'
          '--- a/lib/main.dart\n'
          '+++ b/lib/main.dart\n'
          '@@ -1,2 +1,3 @@\n'
          '-old line\n'
          '+new line\n'
          '+second line\n',
    );

    expect(files, hasLength(1));
    expect(files.single.path, 'lib/main.dart');
    expect(files.single.additions, 2);
    expect(files.single.deletions, 1);
  });

  test('merges nested payload paths with diff-derived file stats', () {
    final files = parser.changedFilesFromSources(
      body:
          'diff --git a/lib/app.dart b/lib/app.dart\n'
          '--- a/lib/app.dart\n'
          '+++ b/lib/app.dart\n'
          '@@ -1 +1 @@\n'
          '-old\n'
          '+new\n',
      rawPayload: <String, Object?>{
        'result': <String, Object?>{
          'files': <Object?>[
            <String, Object?>{'path': 'lib/app.dart'},
            <String, Object?>{'relativePath': 'README.md'},
          ],
        },
      },
    );

    expect(files.map((file) => file.path), ['README.md', 'lib/app.dart']);
    expect(files.last.additions, 1);
    expect(files.last.deletions, 1);
  });

  test('only returns real unified diffs from candidate fields', () {
    expect(
      parser.unifiedDiffFromSources(
        snapshot: const <String, Object?>{'text': 'plain text output'},
      ),
      isNull,
    );

    expect(
      parser.unifiedDiffFromSources(
        snapshot: const <String, Object?>{
          'patch':
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -1 +1 @@\n'
              '-old\n'
              '+new\n',
        },
      ),
      contains('diff --git'),
    );
  });
}
