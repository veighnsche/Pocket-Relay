import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_item_projector.dart';

void main() {
  const projector = ChatChangedFilesItemProjector();

  test(
    'builds review sections with unified line tokens and collapsed gaps',
    () {
      final item = projector.project(
        TranscriptChangedFilesBlock(
          id: 'changed_files_review',
          createdAt: DateTime.utc(2026, 3, 27),
          title: 'Changed files',
          files: const <TranscriptChangedFile>[
            TranscriptChangedFile(path: 'lib/app.dart'),
          ],
          unifiedDiff:
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -10,8 +10,9 @@\n'
              ' line 10\n'
              ' line 11\n'
              ' line 12\n'
              '+added line\n'
              ' line 13\n'
              ' line 14\n'
              ' line 15\n'
              ' line 16\n'
              ' line 17\n',
        ),
      );

      final diff = item.rows.single.diff!;
      expect(diff.review.metadataLines, isEmpty);
      expect(diff.review.sections, isNotEmpty);
      expect(
        diff.review.sections.first.kind,
        ChatChangedFileDiffReviewSectionKind.hunk,
      );
      expect(diff.review.sections.first.label, 'Around lines 10-18');
      expect(
        diff.review.sections.first.rows.any(
          (row) =>
              row.kind == ChatChangedFileDiffReviewRowKind.addition &&
              row.lineToken == '+13' &&
              row.content == 'added line',
        ),
        isTrue,
      );
      expect(
        diff.review.sections.any(
          (section) =>
              section.kind ==
                  ChatChangedFileDiffReviewSectionKind.collapsedGap &&
              section.hiddenLineCount == 1,
        ),
        isTrue,
      );
    },
  );

  test('builds bounded preview review contracts for large diffs', () {
    final diffLines = <String>[
      'diff --git a/lib/large.dart b/lib/large.dart',
      '--- a/lib/large.dart',
      '+++ b/lib/large.dart',
      '@@ -1,0 +1,330 @@',
      for (var index = 0; index < 330; index += 1) '+line $index',
    ];

    final item = projector.project(
      TranscriptChangedFilesBlock(
        id: 'changed_files_large',
        createdAt: DateTime.utc(2026, 3, 27),
        title: 'Changed files',
        files: const <TranscriptChangedFile>[
          TranscriptChangedFile(path: 'lib/large.dart', additions: 330),
        ],
        unifiedDiff: diffLines.join('\n'),
      ),
    );

    final diff = item.rows.single.diff!;
    final previewRows = diff.previewReview.sections
        .expand((section) => section.rows)
        .toList(growable: false);
    final fullRows = diff.review.sections
        .expand((section) => section.rows)
        .toList(growable: false);

    expect(diff.hasPreviewLimit, isTrue);
    expect(previewRows.any((row) => row.content == 'line 329'), isFalse);
    expect(fullRows.any((row) => row.content == 'line 329'), isTrue);
  });

  test('builds binary review sections without exposing raw patch headers', () {
    final item = projector.project(
      TranscriptChangedFilesBlock(
        id: 'changed_files_binary',
        createdAt: DateTime.utc(2026, 3, 27),
        title: 'Changed files',
        files: const <TranscriptChangedFile>[
          TranscriptChangedFile(path: 'assets/logo.png'),
        ],
        unifiedDiff:
            'diff --git a/assets/logo.png b/assets/logo.png\n'
            'Binary files a/assets/logo.png and b/assets/logo.png differ\n',
      ),
    );

    final diff = item.rows.single.diff!;
    expect(diff.review.metadataLines, isEmpty);
    expect(
      diff.review.sections.single.kind,
      ChatChangedFileDiffReviewSectionKind.binaryMessage,
    );
    expect(
      diff.review.sections.single.message,
      'Binary files a/assets/logo.png and b/assets/logo.png differ',
    );
  });
}
