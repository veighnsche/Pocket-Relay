import 'package:pocket_relay/src/features/chat/application/transcript_changed_files_parser.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_item_block_factory.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptTurnSegmenter {
  const TranscriptTurnSegmenter({
    TranscriptItemBlockFactory blockFactory =
        const TranscriptItemBlockFactory(),
    TranscriptChangedFilesParser changedFilesParser =
        const TranscriptChangedFilesParser(),
  }) : _blockFactory = blockFactory,
       _changedFilesParser = changedFilesParser;

  final TranscriptItemBlockFactory _blockFactory;
  final TranscriptChangedFilesParser _changedFilesParser;

  CodexActiveTurnState upsertItem(
    CodexActiveTurnState turn,
    CodexSessionActiveItem item,
  ) {
    final segment = _segmentFromItem(item);
    if (segment == null) {
      return turn;
    }

    final nextSegments = List<CodexTurnSegment>.from(turn.segments);
    final index = nextSegments.indexWhere(
      (existing) => existing.id == segment.id,
    );
    if (index == -1) {
      nextSegments.add(segment);
    } else {
      nextSegments[index] = segment;
    }

    return turn.copyWith(
      segments: nextSegments,
      itemSegmentIds: <String, String>{
        ...turn.itemSegmentIds,
        item.itemId: segment.id,
      },
      hasWork: turn.hasWork || _isWorkItem(item.itemType),
      hasReasoning:
          turn.hasReasoning ||
          item.itemType == CodexCanonicalItemType.reasoning,
    );
  }

  CodexTurnSegment? _segmentFromItem(CodexSessionActiveItem item) {
    final title = item.title ?? _blockFactory.defaultItemTitle(item.itemType);
    final segmentId = item.entryId;

    return switch (item.blockKind) {
      CodexUiBlockKind.userMessage when item.body.trim().isEmpty => null,
      CodexUiBlockKind.userMessage => CodexTurnBlockSegment(
        block: CodexUserMessageBlock(
          id: segmentId,
          createdAt: item.createdAt,
          text: item.body,
        ),
      ),
      CodexUiBlockKind.reasoning when item.body.trim().isEmpty => null,
      CodexUiBlockKind.reasoning => CodexTurnTextSegment(
        id: segmentId,
        createdAt: item.createdAt,
        kind: CodexUiBlockKind.reasoning,
        title: title,
        body: item.body,
        itemId: item.itemId,
        isStreaming: item.isRunning,
      ),
      CodexUiBlockKind.assistantMessage => CodexTurnTextSegment(
        id: segmentId,
        createdAt: item.createdAt,
        kind: item.blockKind,
        title: title,
        body: item.body,
        itemId: item.itemId,
        isStreaming: item.isRunning,
      ),
      CodexUiBlockKind.status => CodexTurnBlockSegment(
        block: CodexStatusBlock(
          id: segmentId,
          createdAt: item.createdAt,
          title: title,
          body: item.body,
        ),
      ),
      CodexUiBlockKind.error => CodexTurnBlockSegment(
        block: CodexErrorBlock(
          id: segmentId,
          createdAt: item.createdAt,
          title: title,
          body: item.body,
        ),
      ),
      CodexUiBlockKind.proposedPlan => CodexTurnPlanSegment(
        id: segmentId,
        createdAt: item.createdAt,
        title: title,
        markdown: item.body,
        itemId: item.itemId,
        isStreaming: item.isRunning,
      ),
      CodexUiBlockKind.changedFiles => CodexTurnChangedFilesSegment(
        id: segmentId,
        createdAt: item.createdAt,
        title: title,
        itemId: item.itemId,
        files: _changedFilesParser.changedFilesFromSources(
          snapshot: item.snapshot,
          body: item.body,
        ),
        unifiedDiff: _changedFilesParser.unifiedDiffFromSources(
          snapshot: item.snapshot,
          body: item.body,
        ),
        isStreaming: item.isRunning,
      ),
      CodexUiBlockKind.workLogEntry ||
      CodexUiBlockKind.commandExecution => CodexTurnWorkSegment(
        id: segmentId,
        createdAt: item.createdAt,
        itemId: item.itemId,
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: item.entryId,
            createdAt: item.createdAt,
            entryKind: _blockFactory.workLogEntryKindFor(item.itemType),
            title: title,
            turnId: item.turnId,
            preview: _blockFactory.workLogPreview(item),
            isRunning: item.isRunning,
            exitCode: item.exitCode,
          ),
        ],
      ),
      _ => null,
    };
  }

  bool _isWorkItem(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.commandExecution ||
      CodexCanonicalItemType.fileChange ||
      CodexCanonicalItemType.webSearch ||
      CodexCanonicalItemType.imageView ||
      CodexCanonicalItemType.imageGeneration ||
      CodexCanonicalItemType.mcpToolCall ||
      CodexCanonicalItemType.dynamicToolCall ||
      CodexCanonicalItemType.collabAgentToolCall => true,
      _ => false,
    };
  }
}
