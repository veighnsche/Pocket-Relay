import 'package:pocket_relay/src/features/chat/application/transcript_changed_files_parser.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_item_block_factory.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptTurnArtifactBuilder {
  const TranscriptTurnArtifactBuilder({
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
    if (_isWorkBlockKind(item.blockKind)) {
      return _upsertWorkArtifact(turn, item);
    }
    return _upsertSingleArtifact(turn, item);
  }

  CodexActiveTurnState _upsertSingleArtifact(
    CodexActiveTurnState turn,
    CodexSessionActiveItem item,
  ) {
    final artifact = _artifactFromItem(item);
    if (artifact == null) {
      return turn;
    }

    var nextArtifacts = List<CodexTurnArtifact>.from(turn.artifacts);
    final index = nextArtifacts.indexWhere(
      (existing) => existing.id == artifact.id,
    );
    if (index == -1) {
      nextArtifacts = appendCodexTurnArtifact(nextArtifacts, artifact);
    } else {
      nextArtifacts[index] = artifact;
    }

    return turn.copyWith(
      artifacts: nextArtifacts,
      itemArtifactIds: <String, String>{
        ...turn.itemArtifactIds,
        item.itemId: artifact.id,
      },
      hasWork: turn.hasWork || _isWorkItem(item.itemType),
      hasReasoning:
          turn.hasReasoning ||
          item.itemType == CodexCanonicalItemType.reasoning,
    );
  }

  CodexActiveTurnState _upsertWorkArtifact(
    CodexActiveTurnState turn,
    CodexSessionActiveItem item,
  ) {
    final entry = CodexWorkLogEntry(
      id: item.entryId,
      createdAt: item.createdAt,
      entryKind: _blockFactory.workLogEntryKindFor(item.itemType),
      title: item.title ?? _blockFactory.defaultItemTitle(item.itemType),
      turnId: item.turnId,
      preview: _blockFactory.workLogPreview(item),
      isRunning: item.isRunning,
      exitCode: item.exitCode,
    );
    var nextArtifacts = List<CodexTurnArtifact>.from(turn.artifacts);
    String artifactId;

    if (nextArtifacts.lastOrNull case final CodexTurnWorkArtifact lastWork) {
      nextArtifacts[nextArtifacts.length - 1] = _workArtifactWithEntry(
        lastWork,
        entry,
      );
      artifactId = lastWork.id;
    } else {
      final nextArtifact = CodexTurnWorkArtifact(
        id: 'work_group_${item.entryId}',
        createdAt: item.createdAt,
        entries: <CodexWorkLogEntry>[entry],
      );
      nextArtifacts = appendCodexTurnArtifact(nextArtifacts, nextArtifact);
      artifactId = nextArtifact.id;
    }

    return turn.copyWith(
      artifacts: nextArtifacts,
      itemArtifactIds: <String, String>{
        ...turn.itemArtifactIds,
        item.itemId: artifactId,
      },
      hasWork: true,
      hasReasoning:
          turn.hasReasoning ||
          item.itemType == CodexCanonicalItemType.reasoning,
    );
  }

  CodexTurnWorkArtifact _workArtifactWithEntry(
    CodexTurnWorkArtifact artifact,
    CodexWorkLogEntry entry,
  ) {
    final nextEntries = List<CodexWorkLogEntry>.from(artifact.entries);
    final index = nextEntries.indexWhere((existing) => existing.id == entry.id);
    if (index == -1) {
      nextEntries.add(entry);
    } else {
      nextEntries[index] = entry;
    }

    return CodexTurnWorkArtifact(
      id: artifact.id,
      createdAt: artifact.createdAt,
      entries: nextEntries,
    );
  }

  CodexTurnArtifact? _artifactFromItem(CodexSessionActiveItem item) {
    final title = item.title ?? _blockFactory.defaultItemTitle(item.itemType);
    final artifactId = item.entryId;

    return switch (item.blockKind) {
      CodexUiBlockKind.userMessage when item.body.trim().isEmpty => null,
      CodexUiBlockKind.userMessage => CodexTurnBlockArtifact(
        block: CodexUserMessageBlock(
          id: artifactId,
          createdAt: item.createdAt,
          text: item.body,
          deliveryState: CodexUserMessageDeliveryState.sent,
          providerItemId: item.itemId,
        ),
      ),
      CodexUiBlockKind.reasoning when item.body.trim().isEmpty => null,
      CodexUiBlockKind.reasoning => CodexTurnTextArtifact(
        id: artifactId,
        createdAt: item.createdAt,
        kind: CodexUiBlockKind.reasoning,
        title: title,
        body: item.body,
        itemId: item.itemId,
        isStreaming: item.isRunning,
      ),
      CodexUiBlockKind.assistantMessage => CodexTurnTextArtifact(
        id: artifactId,
        createdAt: item.createdAt,
        kind: item.blockKind,
        title: title,
        body: item.body,
        itemId: item.itemId,
        isStreaming: item.isRunning,
      ),
      CodexUiBlockKind.status => CodexTurnBlockArtifact(
        block: CodexStatusBlock(
          id: artifactId,
          createdAt: item.createdAt,
          title: title,
          body: item.body,
        ),
      ),
      CodexUiBlockKind.error => CodexTurnBlockArtifact(
        block: CodexErrorBlock(
          id: artifactId,
          createdAt: item.createdAt,
          title: title,
          body: item.body,
        ),
      ),
      CodexUiBlockKind.proposedPlan => CodexTurnPlanArtifact(
        id: artifactId,
        createdAt: item.createdAt,
        title: title,
        markdown: item.body,
        itemId: item.itemId,
        isStreaming: item.isRunning,
      ),
      CodexUiBlockKind.changedFiles => CodexTurnChangedFilesArtifact(
        id: artifactId,
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
      _ => null,
    };
  }

  bool _isWorkBlockKind(CodexUiBlockKind blockKind) {
    return switch (blockKind) {
      CodexUiBlockKind.workLogEntry ||
      CodexUiBlockKind.commandExecution => true,
      _ => false,
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
