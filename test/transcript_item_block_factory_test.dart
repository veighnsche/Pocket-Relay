import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_item_block_factory.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

void main() {
  const factory = TranscriptItemBlockFactory();
  final createdAt = DateTime(2026, 3, 15, 12);

  test('builds work-log blocks with command previews', () {
    final block = factory.blockFromActiveItem(
      CodexSessionActiveItem(
        itemId: 'cmd_1',
        threadId: 'thread_1',
        turnId: 'turn_1',
        itemType: CodexCanonicalItemType.commandExecution,
        entryId: 'item_cmd_1',
        blockKind: factory.blockKindForItemType(
          CodexCanonicalItemType.commandExecution,
        ),
        createdAt: createdAt,
        title: 'git status',
        body: 'line one\n\nline two\nfinal line',
        isRunning: true,
      ),
    );

    expect(block, isA<CodexWorkLogEntryBlock>());
    final workLog = block as CodexWorkLogEntryBlock;
    expect(workLog.entryKind, CodexWorkLogEntryKind.commandExecution);
    expect(workLog.preview, 'final line');
    expect(workLog.isRunning, isTrue);
  });

  test('builds changed-files blocks with parsed file details', () {
    final block = factory.blockFromActiveItem(
      CodexSessionActiveItem(
        itemId: 'file_1',
        threadId: 'thread_1',
        turnId: 'turn_1',
        itemType: CodexCanonicalItemType.fileChange,
        entryId: 'item_file_1',
        blockKind: factory.blockKindForItemType(
          CodexCanonicalItemType.fileChange,
        ),
        createdAt: createdAt,
        title: 'Changed files',
        body:
            'diff --git a/lib/app.dart b/lib/app.dart\n'
            '--- a/lib/app.dart\n'
            '+++ b/lib/app.dart\n'
            '@@ -1 +1 @@\n'
            '-old\n'
            '+new\n',
      ),
    );

    expect(block, isA<CodexChangedFilesBlock>());
    final changedFiles = block as CodexChangedFilesBlock;
    expect(changedFiles.files.single.path, 'lib/app.dart');
    expect(changedFiles.unifiedDiff, contains('diff --git'));
  });

  test('provides stable default titles for known item types', () {
    expect(
      factory.defaultItemTitle(CodexCanonicalItemType.reasoning),
      'Reasoning',
    );
    expect(
      factory.defaultItemTitle(CodexCanonicalItemType.imageGeneration),
      'Image generation',
    );
  });
}
