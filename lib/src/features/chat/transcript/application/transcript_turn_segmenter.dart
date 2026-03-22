import 'package:pocket_relay/src/features/chat/transcript/application/transcript_changed_files_parser.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_item_block_factory.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_memory_budget.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

class TranscriptTurnArtifactBuilder {
  const TranscriptTurnArtifactBuilder({
    TranscriptItemBlockFactory blockFactory =
        const TranscriptItemBlockFactory(),
    TranscriptChangedFilesParser changedFilesParser =
        const TranscriptChangedFilesParser(),
    TranscriptMemoryBudget memoryBudget = const TranscriptMemoryBudget(),
  }) : _blockFactory = blockFactory,
       _changedFilesParser = changedFilesParser,
       _memoryBudget = memoryBudget;

  final TranscriptItemBlockFactory _blockFactory;
  final TranscriptChangedFilesParser _changedFilesParser;
  final TranscriptMemoryBudget _memoryBudget;

  CodexActiveTurnState upsertItem(
    CodexActiveTurnState turn,
    CodexSessionActiveItem item,
  ) {
    if (_isWorkBlockKind(item.blockKind)) {
      return _upsertWorkArtifact(turn, item);
    }
    if (item.blockKind == CodexUiBlockKind.changedFiles) {
      return _upsertChangedFilesArtifact(turn, item);
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
      snapshot: _memoryBudget.retainWorkLogSnapshot(
        item.itemType,
        item.snapshot,
      ),
    );
    var nextArtifacts = List<CodexTurnArtifact>.from(turn.artifacts);
    String artifactId;
    final boundArtifactIndex = _boundWorkArtifactIndex(turn, item);

    if (boundArtifactIndex != null) {
      final boundArtifact =
          nextArtifacts[boundArtifactIndex] as CodexTurnWorkArtifact;
      nextArtifacts[boundArtifactIndex] = _workArtifactWithEntry(
        boundArtifact,
        entry,
      );
      artifactId = boundArtifact.id;
    } else if (nextArtifacts.lastOrNull
        case final CodexTurnWorkArtifact lastWork) {
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
    );
  }

  int? _boundWorkArtifactIndex(
    CodexActiveTurnState turn,
    CodexSessionActiveItem item,
  ) {
    if (item.itemType != CodexCanonicalItemType.commandExecution) {
      return null;
    }

    final boundArtifactId = turn.itemArtifactIds[item.itemId];
    if (boundArtifactId == null) {
      return null;
    }

    final index = turn.artifacts.indexWhere(
      (artifact) => artifact.id == boundArtifactId,
    );
    if (index == -1 || turn.artifacts[index] is! CodexTurnWorkArtifact) {
      return null;
    }
    return index;
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

  CodexActiveTurnState _upsertChangedFilesArtifact(
    CodexActiveTurnState turn,
    CodexSessionActiveItem item,
  ) {
    final entry = _changedFilesEntryFromItem(item);
    var nextArtifacts = List<CodexTurnArtifact>.from(turn.artifacts);
    String artifactId;

    if (nextArtifacts.lastOrNull
        case final CodexTurnChangedFilesArtifact last) {
      nextArtifacts[nextArtifacts.length - 1] = _changedFilesArtifactWithEntry(
        last,
        entry,
      );
      artifactId = last.id;
    } else {
      final retainedDiff = _memoryBudget.retainUnifiedDiff(entry.unifiedDiff);
      final nextArtifact = CodexTurnChangedFilesArtifact(
        id: 'changed_files_group_${item.entryId}',
        createdAt: item.createdAt,
        title: item.title ?? _blockFactory.defaultItemTitle(item.itemType),
        itemId: item.itemId,
        files: entry.files,
        unifiedDiff: retainedDiff,
        entries: <CodexChangedFilesEntry>[entry.copyWith(unifiedDiff: null)],
        isStreaming: item.isRunning,
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
    );
  }

  CodexChangedFilesEntry _changedFilesEntryFromItem(
    CodexSessionActiveItem item,
  ) {
    return CodexChangedFilesEntry(
      id: item.entryId,
      itemId: item.itemId,
      createdAt: item.createdAt,
      files: _changedFilesParser.changedFilesFromSources(
        snapshot: item.snapshot,
        body: item.body,
      ),
      unifiedDiff: _changedFilesParser.unifiedDiffFromSources(
        snapshot: item.snapshot,
        body: item.body,
      ),
      isRunning: item.isRunning,
    );
  }

  CodexTurnChangedFilesArtifact _changedFilesArtifactWithEntry(
    CodexTurnChangedFilesArtifact artifact,
    CodexChangedFilesEntry entry,
  ) {
    final retainedDiff = _memoryBudget.retainUnifiedDiff(entry.unifiedDiff);
    final sanitizedEntry = entry.copyWith(unifiedDiff: null);
    final nextEntries = List<CodexChangedFilesEntry>.from(artifact.entries);
    final index = nextEntries.indexWhere(
      (existing) => existing.id == sanitizedEntry.id,
    );
    if (index == -1) {
      nextEntries.add(sanitizedEntry);
    } else {
      nextEntries[index] = sanitizedEntry;
    }

    return CodexTurnChangedFilesArtifact(
      id: artifact.id,
      createdAt: artifact.createdAt,
      title: artifact.title,
      itemId: entry.itemId,
      files: _mergeChangedFiles(artifact.files, entry.files),
      unifiedDiff: _memoryBudget.retainUnifiedDiff(
        _joinUnifiedDiffFragments(<String?>[
          artifact.unifiedDiff,
          retainedDiff,
        ]),
      ),
      entries: nextEntries,
      isStreaming: entry.isRunning,
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
          statusKind: _blockFactory.statusKindForItemType(item.itemType),
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
      _ => null,
    };
  }

  bool _isWorkBlockKind(CodexUiBlockKind blockKind) {
    return switch (blockKind) {
      CodexUiBlockKind.workLogEntry => true,
      _ => false,
    };
  }
}

List<CodexChangedFile> _mergeChangedFiles(
  Iterable<CodexChangedFile> existing,
  Iterable<CodexChangedFile> next,
) {
  final mergedByPath = <String, CodexChangedFile>{
    for (final file in existing) file.path: file,
  };

  for (final file in next) {
    final current = mergedByPath[file.path];
    if (current == null) {
      mergedByPath[file.path] = file;
      continue;
    }
    mergedByPath[file.path] = current.copyWith(
      movePath: file.movePath ?? current.movePath,
      additions: current.additions + file.additions,
      deletions: current.deletions + file.deletions,
    );
  }

  return mergedByPath.values.toList(growable: false);
}

String? _joinUnifiedDiffFragments(Iterable<String?> parts) {
  final retainedParts = parts
      .map((part) => part?.trim())
      .whereType<String>()
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (retainedParts.isEmpty) {
    return null;
  }
  return retainedParts.join('\n');
}
