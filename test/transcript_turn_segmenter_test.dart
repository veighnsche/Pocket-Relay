import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_memory_budget.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_turn_segmenter.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

void main() {
  const builder = TranscriptTurnArtifactBuilder();
  final startedAt = DateTime.utc(2026, 1, 1, 12);

  CodexActiveTurnState initialTurn() {
    return CodexActiveTurnState(
      turnId: 'turn-1',
      timer: CodexSessionTurnTimer(
        turnId: 'turn-1',
        startedAt: startedAt,
      ),
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

  test('replaces changed-file updates for the same entry without duplicating state', () {
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
    final artifact = secondTurn.artifacts.single as CodexTurnChangedFilesArtifact;

    expect(artifact.entries, hasLength(1));
    expect(artifact.files, hasLength(1));
    expect(artifact.files.single.path, 'lib/app.dart');
    expect(artifact.files.single.additions, 2);
    expect(artifact.files.single.deletions, 0);
    expect(artifact.unifiedDiff, contains('@@ -0,0 +1,2 @@'));
    expect(artifact.unifiedDiff, isNot(contains('@@ -0,0 +1 @@')));
  });

  test('caps retained changed-file diffs in the segmenter', () {
    final largeDiff = List<String>.generate(
      TranscriptMemoryBudget.maxUnifiedDiffLines + 200,
      (index) => '+line $index ${'x' * 80}',
    ).join('\n');
    final item = changedFilesItem(
      itemId: 'item-2',
      entryId: 'entry-2',
      body: '''
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
      '\n'.allMatches(artifact.unifiedDiff!).length + 1,
      lessThanOrEqualTo(TranscriptMemoryBudget.maxUnifiedDiffLines),
    );
    expect(
      '\n'.allMatches(retainedEntryDiff!).length + 1,
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
}
