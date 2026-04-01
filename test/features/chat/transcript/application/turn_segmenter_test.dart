import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_memory_budget.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_turn_segmenter.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';

void main() {
  const builder = TranscriptTurnArtifactBuilder();
  final startedAt = DateTime.utc(2026, 1, 1, 12);
  const unifiedDiffHeaderLineCount = 3;
  int countLines(String text) =>
      text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;

  TranscriptActiveTurnState initialTurn() {
    return TranscriptActiveTurnState(
      turnId: 'turn-1',
      timer: TranscriptSessionTurnTimer(turnId: 'turn-1', startedAt: startedAt),
    );
  }

  TranscriptSessionActiveItem changedFilesItem({
    required String entryId,
    required String itemId,
    required String body,
    bool isRunning = false,
  }) {
    return TranscriptSessionActiveItem(
      itemId: itemId,
      threadId: 'thread-1',
      turnId: 'turn-1',
      itemType: TranscriptCanonicalItemType.fileChange,
      entryId: entryId,
      blockKind: TranscriptUiBlockKind.changedFiles,
      createdAt: startedAt,
      body: body,
      isRunning: isRunning,
    );
  }

  TranscriptSessionActiveItem commandItem({
    required String entryId,
    required String itemId,
    required String body,
    bool isRunning = false,
  }) {
    return TranscriptSessionActiveItem(
      itemId: itemId,
      threadId: 'thread-1',
      turnId: 'turn-1',
      itemType: TranscriptCanonicalItemType.commandExecution,
      entryId: entryId,
      blockKind: TranscriptUiBlockKind.workLogEntry,
      createdAt: startedAt,
      title: 'pwd',
      body: body,
      isRunning: isRunning,
      snapshot: const <String, Object?>{'processId': 'proc-1'},
    );
  }

  String changedFilesBody({
    required String fileName,
    required int lineCount,
    required String linePrefix,
  }) {
    final diffLines = List<String>.generate(
      lineCount,
      (index) => '+$linePrefix line $index',
    ).join('\n');
    return '''
--- a/lib/$fileName.dart
+++ b/lib/$fileName.dart
@@ -0,0 +1,$lineCount @@
$diffLines
''';
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
          secondTurn.artifacts.single as TranscriptTurnChangedFilesArtifact;

      expect(artifact.entries, hasLength(1));
      expect(artifact.files, hasLength(1));
      expect(artifact.files.single.path, 'lib/app.dart');
      expect(artifact.files.single.additions, 2);
      expect(artifact.files.single.deletions, 0);
      expect(artifact.unifiedDiff, contains('@@ -0,0 +1,2 @@'));
      expect(artifact.unifiedDiff, isNot(contains('@@ -0,0 +1 @@')));
    },
  );

  test('does not persist full command output inside work-log artifacts', () {
    final turn = builder.upsertItem(
      initialTurn(),
      commandItem(
        itemId: 'command-1',
        entryId: 'entry-1',
        body: '/workspace\n',
      ),
    );
    final artifact = turn.artifacts.single as TranscriptTurnWorkArtifact;
    final entry = artifact.entries.single;

    expect(entry.itemId, 'command-1');
    expect(entry.threadId, 'thread-1');
    expect(entry.preview, '/workspace');
    expect(entry.body, isNull);
  });

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
    final artifact =
        turn.artifacts.single as TranscriptTurnChangedFilesArtifact;
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
      TranscriptActiveTurnState turn = initialTurn();
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

      final artifact =
          turn.artifacts.single as TranscriptTurnChangedFilesArtifact;

      expect(artifact.entries, hasLength(entryCount));
      expect(
        artifact.entries.every((entry) => entry.unifiedDiff != null),
        isTrue,
      );
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

  test(
    'treats updated changed-file entries as newest when trimming by budget',
    () {
      var turn = initialTurn();
      final retainedLinesPerEntry =
          TranscriptMemoryBudget.maxUnifiedDiffLines -
          unifiedDiffHeaderLineCount;

      turn = builder.upsertItem(
        turn,
        changedFilesItem(
          itemId: 'item-a',
          entryId: 'entry-a',
          body: changedFilesBody(
            fileName: 'file_a',
            lineCount: retainedLinesPerEntry,
            linePrefix: 'entry a first',
          ),
        ),
      );
      turn = builder.upsertItem(
        turn,
        changedFilesItem(
          itemId: 'item-b',
          entryId: 'entry-b',
          body: changedFilesBody(
            fileName: 'file_b',
            lineCount: retainedLinesPerEntry,
            linePrefix: 'entry b',
          ),
        ),
      );
      turn = builder.upsertItem(
        turn,
        changedFilesItem(
          itemId: 'item-a',
          entryId: 'entry-a',
          body: changedFilesBody(
            fileName: 'file_a',
            lineCount: retainedLinesPerEntry,
            linePrefix: 'entry a latest',
          ),
        ),
      );

      final artifact =
          turn.artifacts.single as TranscriptTurnChangedFilesArtifact;
      final entriesById = <String, TranscriptChangedFilesEntry>{
        for (final entry in artifact.entries) entry.id: entry,
      };

      expect(artifact.entries.map((entry) => entry.id).toList(), <String>[
        'entry-b',
        'entry-a',
      ]);
      expect(entriesById['entry-a']!.unifiedDiff, isNotNull);
      expect(entriesById['entry-a']!.unifiedDiff, contains('entry a latest'));
      expect(artifact.unifiedDiff, contains('entry a latest'));
      expect(artifact.unifiedDiff, isNot(contains('entry b line 0')));
    },
  );

  test('does not spend a line of budget on inter-entry diff separators', () {
    var turn = initialTurn();
    final retainedLinesPerEntry =
        (TranscriptMemoryBudget.maxUnifiedDiffLines ~/ 2) -
        unifiedDiffHeaderLineCount;

    turn = builder.upsertItem(
      turn,
      changedFilesItem(
        itemId: 'item-1',
        entryId: 'entry-1',
        body: changedFilesBody(
          fileName: 'file_1',
          lineCount: retainedLinesPerEntry,
          linePrefix: 'entry 1',
        ),
      ),
    );
    turn = builder.upsertItem(
      turn,
      changedFilesItem(
        itemId: 'item-2',
        entryId: 'entry-2',
        body: changedFilesBody(
          fileName: 'file_2',
          lineCount: retainedLinesPerEntry,
          linePrefix: 'entry 2',
        ),
      ),
    );

    final artifact =
        turn.artifacts.single as TranscriptTurnChangedFilesArtifact;
    expect(artifact.unifiedDiff, contains('entry 1 line 0'));
    expect(artifact.unifiedDiff, contains('entry 2 line 0'));
    expect(
      countLines(artifact.unifiedDiff!),
      TranscriptMemoryBudget.maxUnifiedDiffLines,
    );
  });

  test(
    'restores older changed-file hunks when later entries shrink back under budget',
    () {
      var turn = initialTurn();
      final largeEntryLines =
          TranscriptMemoryBudget.maxUnifiedDiffLines -
          unifiedDiffHeaderLineCount -
          100;

      turn = builder.upsertItem(
        turn,
        changedFilesItem(
          itemId: 'item-a',
          entryId: 'entry-a',
          body: changedFilesBody(
            fileName: 'file_a',
            lineCount: largeEntryLines,
            linePrefix: 'entry a large',
          ),
        ),
      );
      turn = builder.upsertItem(
        turn,
        changedFilesItem(
          itemId: 'item-b',
          entryId: 'entry-b',
          body: changedFilesBody(
            fileName: 'file_b',
            lineCount: largeEntryLines,
            linePrefix: 'entry b large',
          ),
        ),
      );
      turn = builder.upsertItem(
        turn,
        changedFilesItem(
          itemId: 'item-b',
          entryId: 'entry-b',
          body: changedFilesBody(
            fileName: 'file_b',
            lineCount: 10,
            linePrefix: 'entry b small',
          ),
        ),
      );

      final artifact =
          turn.artifacts.single as TranscriptTurnChangedFilesArtifact;
      final entriesById = <String, TranscriptChangedFilesEntry>{
        for (final entry in artifact.entries) entry.id: entry,
      };

      expect(
        entriesById['entry-a']!.unifiedDiff,
        contains('entry a large line 1000'),
      );
      expect(artifact.unifiedDiff, contains('entry a large line 1000'));
      expect(artifact.unifiedDiff, contains('entry b small line 9'));
    },
  );
}
