import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_memory_budget.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_turn_segmenter.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

void main() {
  const builder = TranscriptTurnArtifactBuilder();
  final startedAt = DateTime.utc(2026, 1, 1, 12);
  int countLines(String text) =>
      text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;

  CodexActiveTurnState initialTurn() {
    return CodexActiveTurnState(
      turnId: 'turn-1',
      timer: CodexSessionTurnTimer(turnId: 'turn-1', startedAt: startedAt),
    );
  }

  CodexSessionActiveItem changedFilesItem({
    required String entryId,
    required String itemId,
    required String body,
    bool isRunning = false,
  }) {
    return CodexSessionActiveItem(
      itemId: itemId,
      threadId: 'thread-1',
      turnId: 'turn-1',
      itemType: CodexCanonicalItemType.fileChange,
      entryId: entryId,
      blockKind: CodexUiBlockKind.changedFiles,
      createdAt: startedAt,
      body: body,
      isRunning: isRunning,
    );
  }

  test(
    'replaces changed-file updates for the same entry without duplicating state',
    () {
      final firstItem = changedFilesItem(
        itemId: 'item-1',
        entryId: 'entry-1',
        body: '''
--- a/lib/app.dart
+++ b/lib/app.dart
@@ -0,0 +1 @@
+first
''',
        isRunning: true,
      );
      final secondItem = changedFilesItem(
        itemId: 'item-1',
        entryId: 'entry-1',
        body: '''
--- a/lib/app.dart
+++ b/lib/app.dart
@@ -0,0 +1,2 @@
+first
+second
''',
      );

      final firstTurn = builder.upsertItem(initialTurn(), firstItem);
      final secondTurn = builder.upsertItem(firstTurn, secondItem);
      final artifact =
          secondTurn.artifacts.single as CodexTurnChangedFilesArtifact;

      expect(artifact.entries, hasLength(1));
      expect(artifact.files, hasLength(1));
      expect(artifact.files.single.path, 'lib/app.dart');
      expect(artifact.files.single.additions, 2);
      expect(artifact.files.single.deletions, 0);
      expect(artifact.unifiedDiff, contains('@@ -0,0 +1,2 @@'));
      expect(artifact.unifiedDiff, isNot(contains('@@ -0,0 +1 @@')));
    },
  );

  test('caps retained changed-file diffs in the segmenter', () {
    final largeDiff = List<String>.generate(
      TranscriptMemoryBudget.maxUnifiedDiffLines + 200,
      (index) => '+line $index ${'x' * 80}',
    ).join('\n');
    final item = changedFilesItem(
      itemId: 'item-2',
      entryId: 'entry-2',
      body:
          '''
--- a/lib/large.dart
+++ b/lib/large.dart
@@ -0,0 +1,${TranscriptMemoryBudget.maxUnifiedDiffLines + 200} @@
$largeDiff
''',
    );

    final turn = builder.upsertItem(initialTurn(), item);
    final artifact = turn.artifacts.single as CodexTurnChangedFilesArtifact;
    final retainedEntryDiff = artifact.entries.single.unifiedDiff;

    expect(artifact.unifiedDiff, isNotNull);
    expect(retainedEntryDiff, isNotNull);
    expect(
      countLines(artifact.unifiedDiff!),
      lessThanOrEqualTo(TranscriptMemoryBudget.maxUnifiedDiffLines),
    );
    expect(
      countLines(retainedEntryDiff!),
      lessThanOrEqualTo(TranscriptMemoryBudget.maxUnifiedDiffLines),
    );
    expect(
      artifact.unifiedDiff!.length,
      lessThanOrEqualTo(TranscriptMemoryBudget.maxUnifiedDiffChars),
    );
    expect(
      retainedEntryDiff.length,
      lessThanOrEqualTo(TranscriptMemoryBudget.maxUnifiedDiffChars),
    );
  });

  test(
    'bounds total retained changed-file entry diffs across many entries',
    () {
      CodexActiveTurnState turn = initialTurn();
      final entryCount = 6;
      final perEntryLines = 260;

      for (var index = 0; index < entryCount; index += 1) {
        final diffLines = List<String>.generate(
          perEntryLines,
          (lineIndex) => '+entry $index line $lineIndex ${'x' * 80}',
        ).join('\n');
        turn = builder.upsertItem(
          turn,
          changedFilesItem(
            itemId: 'item-$index',
            entryId: 'entry-$index',
            body:
                '''
--- a/lib/file_$index.dart
+++ b/lib/file_$index.dart
@@ -0,0 +1,$perEntryLines @@
$diffLines
''',
          ),
        );
      }

      final artifact = turn.artifacts.single as CodexTurnChangedFilesArtifact;
      final retainedEntryDiffs = artifact.entries
          .map((entry) => entry.unifiedDiff)
          .whereType<String>()
          .toList(growable: false);
      final totalRetainedEntryChars = retainedEntryDiffs.fold<int>(
        0,
        (total, diff) => total + diff.length,
      );
      final totalRetainedEntryLines = retainedEntryDiffs.fold<int>(
        0,
        (total, diff) => total + countLines(diff),
      );

      expect(artifact.entries, hasLength(entryCount));
      expect(retainedEntryDiffs, isNotEmpty);
      expect(
        totalRetainedEntryChars,
        lessThanOrEqualTo(TranscriptMemoryBudget.maxUnifiedDiffChars),
      );
      expect(
        totalRetainedEntryLines,
        lessThanOrEqualTo(TranscriptMemoryBudget.maxUnifiedDiffLines),
      );
      expect(artifact.entries.first.unifiedDiff, isNull);
      expect(artifact.entries.last.unifiedDiff, isNotNull);
      expect(
        artifact.unifiedDiff!.length,
        lessThanOrEqualTo(TranscriptMemoryBudget.maxUnifiedDiffChars),
      );
      expect(
        countLines(artifact.unifiedDiff!),
        lessThanOrEqualTo(TranscriptMemoryBudget.maxUnifiedDiffLines),
      );
    },
  );
}
