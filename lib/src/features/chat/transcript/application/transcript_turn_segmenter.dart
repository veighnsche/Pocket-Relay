import 'package:pocket_relay/src/features/chat/transcript/application/transcript_changed_files_parser.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_item_block_factory.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_item_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_memory_budget.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';

class TranscriptTurnArtifactBuilder {
  const TranscriptTurnArtifactBuilder({
    TranscriptItemBlockFactory blockFactory =
        const TranscriptItemBlockFactory(),
    TranscriptChangedFilesParser changedFilesParser =
        const TranscriptChangedFilesParser(),
    TranscriptItemSupport itemSupport = const TranscriptItemSupport(),
    TranscriptMemoryBudget memoryBudget = const TranscriptMemoryBudget(),
  }) : _blockFactory = blockFactory,
       _changedFilesParser = changedFilesParser,
       _itemSupport = itemSupport,
       _memoryBudget = memoryBudget;

  final TranscriptItemBlockFactory _blockFactory;
  final TranscriptChangedFilesParser _changedFilesParser;
  final TranscriptItemSupport _itemSupport;
  final TranscriptMemoryBudget _memoryBudget;

  TranscriptActiveTurnState upsertItem(
    TranscriptActiveTurnState turn,
    TranscriptSessionActiveItem item,
  ) {
    if (_isWorkBlockKind(item.blockKind)) {
      return _upsertWorkArtifact(turn, item);
    }
    if (item.blockKind == TranscriptUiBlockKind.changedFiles) {
      return _upsertChangedFilesArtifact(turn, item);
    }
    return _upsertSingleArtifact(turn, item);
  }

  TranscriptActiveTurnState _upsertSingleArtifact(
    TranscriptActiveTurnState turn,
    TranscriptSessionActiveItem item,
  ) {
    final artifact = _artifactFromItem(item);
    if (artifact == null) {
      return turn;
    }

    var nextArtifacts = List<TranscriptTurnArtifact>.from(turn.artifacts);
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

  TranscriptActiveTurnState _upsertWorkArtifact(
    TranscriptActiveTurnState turn,
    TranscriptSessionActiveItem item,
  ) {
    final entry = TranscriptWorkLogEntry(
      id: item.entryId,
      createdAt: item.createdAt,
      entryKind: _blockFactory.workLogEntryKindFor(item.itemType),
      title: item.title ?? _blockFactory.defaultItemTitle(item.itemType),
      itemId: item.itemId,
      threadId: item.threadId,
      turnId: item.turnId,
      preview: _blockFactory.workLogPreview(item),
      isRunning: item.isRunning,
      exitCode: item.exitCode,
      snapshot: _memoryBudget.retainWorkLogSnapshot(
        item.itemType,
        item.snapshot,
      ),
    );
    var nextArtifacts = List<TranscriptTurnArtifact>.from(turn.artifacts);
    String artifactId;
    final boundArtifactIndex = _boundWorkArtifactIndex(turn, item);

    if (boundArtifactIndex != null) {
      final boundArtifact =
          nextArtifacts[boundArtifactIndex] as TranscriptTurnWorkArtifact;
      nextArtifacts[boundArtifactIndex] = _workArtifactWithEntry(
        boundArtifact,
        entry,
      );
      artifactId = boundArtifact.id;
    } else if (nextArtifacts.lastOrNull
        case final TranscriptTurnWorkArtifact lastWork) {
      nextArtifacts[nextArtifacts.length - 1] = _workArtifactWithEntry(
        lastWork,
        entry,
      );
      artifactId = lastWork.id;
    } else {
      final nextArtifact = TranscriptTurnWorkArtifact(
        id: 'work_group_${item.entryId}',
        createdAt: item.createdAt,
        entries: <TranscriptWorkLogEntry>[entry],
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
    TranscriptActiveTurnState turn,
    TranscriptSessionActiveItem item,
  ) {
    if (item.itemType != TranscriptCanonicalItemType.commandExecution) {
      return null;
    }

    final boundArtifactId = turn.itemArtifactIds[item.itemId];
    if (boundArtifactId == null) {
      return null;
    }

    final index = turn.artifacts.indexWhere(
      (artifact) => artifact.id == boundArtifactId,
    );
    if (index == -1 || turn.artifacts[index] is! TranscriptTurnWorkArtifact) {
      return null;
    }
    return index;
  }

  TranscriptTurnWorkArtifact _workArtifactWithEntry(
    TranscriptTurnWorkArtifact artifact,
    TranscriptWorkLogEntry entry,
  ) {
    final nextEntries = List<TranscriptWorkLogEntry>.from(artifact.entries);
    final index = nextEntries.indexWhere((existing) => existing.id == entry.id);
    if (index == -1) {
      nextEntries.add(entry);
    } else {
      nextEntries[index] = entry;
    }

    return TranscriptTurnWorkArtifact(
      id: artifact.id,
      createdAt: artifact.createdAt,
      entries: nextEntries,
    );
  }

  TranscriptActiveTurnState _upsertChangedFilesArtifact(
    TranscriptActiveTurnState turn,
    TranscriptSessionActiveItem item,
  ) {
    final entry = _changedFilesEntryFromItem(item);
    var nextArtifacts = List<TranscriptTurnArtifact>.from(turn.artifacts);
    String artifactId;

    if (nextArtifacts.lastOrNull
        case final TranscriptTurnChangedFilesArtifact last) {
      nextArtifacts[nextArtifacts.length - 1] = _changedFilesArtifactWithEntry(
        last,
        entry,
      );
      artifactId = last.id;
    } else {
      final nextEntries = <TranscriptChangedFilesEntry>[entry];
      final retainedEntries = _retainChangedFilesEntryDiffs(nextEntries);
      final nextArtifact = TranscriptTurnChangedFilesArtifact(
        id: 'changed_files_group_${item.entryId}',
        createdAt: item.createdAt,
        title: item.title ?? _blockFactory.defaultItemTitle(item.itemType),
        itemId: item.itemId,
        files: _mergeChangedFilesForEntries(nextEntries),
        unifiedDiff: _mergedRetainedUnifiedDiff(retainedEntries),
        entries: nextEntries,
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

  TranscriptChangedFilesEntry _changedFilesEntryFromItem(
    TranscriptSessionActiveItem item,
  ) {
    return TranscriptChangedFilesEntry(
      id: item.entryId,
      itemId: item.itemId,
      createdAt: item.createdAt,
      files: _changedFilesParser.changedFilesFromSources(
        snapshot: item.snapshot,
        body: item.body,
      ),
      unifiedDiff: _memoryBudget.retainUnifiedDiff(
        _changedFilesParser.unifiedDiffFromSources(
          snapshot: item.snapshot,
          body: item.body,
        ),
      ),
      isRunning: item.isRunning,
    );
  }

  TranscriptTurnChangedFilesArtifact _changedFilesArtifactWithEntry(
    TranscriptTurnChangedFilesArtifact artifact,
    TranscriptChangedFilesEntry entry,
  ) {
    final nextEntries = List<TranscriptChangedFilesEntry>.from(
      artifact.entries,
    );
    final index = nextEntries.indexWhere((existing) => existing.id == entry.id);
    if (index == -1) {
      nextEntries.add(entry);
    } else {
      nextEntries
        ..removeAt(index)
        ..add(entry);
    }
    final retainedEntries = _retainChangedFilesEntryDiffs(nextEntries);

    return TranscriptTurnChangedFilesArtifact(
      id: artifact.id,
      createdAt: artifact.createdAt,
      title: artifact.title,
      itemId: entry.itemId,
      files: _mergeChangedFilesForEntries(nextEntries),
      unifiedDiff: _mergedRetainedUnifiedDiff(retainedEntries),
      entries: nextEntries,
      isStreaming: entry.isRunning,
    );
  }

  TranscriptTurnArtifact? _artifactFromItem(TranscriptSessionActiveItem item) {
    final title = item.title ?? _blockFactory.defaultItemTitle(item.itemType);
    final artifactId = item.entryId;
    final structuredUserDraft =
        item.itemType == TranscriptCanonicalItemType.userMessage
        ? _itemSupport.extractStructuredUserMessageDraft(item.snapshot)
        : null;
    final effectiveUserMessageText = structuredUserDraft?.text ?? item.body;

    return switch (item.blockKind) {
      TranscriptUiBlockKind.userMessage
          when effectiveUserMessageText.trim().isEmpty &&
              (structuredUserDraft == null || structuredUserDraft.isEmpty) =>
        null,
      TranscriptUiBlockKind.userMessage => TranscriptTurnBlockArtifact(
        block: TranscriptUserMessageBlock(
          id: artifactId,
          createdAt: item.createdAt,
          text: effectiveUserMessageText,
          deliveryState: TranscriptUserMessageDeliveryState.sent,
          structuredDraft: structuredUserDraft,
          providerItemId: item.itemId,
        ),
      ),
      TranscriptUiBlockKind.reasoning when item.body.trim().isEmpty => null,
      TranscriptUiBlockKind.reasoning => TranscriptTurnTextArtifact(
        id: artifactId,
        createdAt: item.createdAt,
        kind: TranscriptUiBlockKind.reasoning,
        title: title,
        body: item.body,
        itemId: item.itemId,
        isStreaming: item.isRunning,
      ),
      TranscriptUiBlockKind.assistantMessage => TranscriptTurnTextArtifact(
        id: artifactId,
        createdAt: item.createdAt,
        kind: item.blockKind,
        title: title,
        body: item.body,
        itemId: item.itemId,
        isStreaming: item.isRunning,
      ),
      TranscriptUiBlockKind.status => TranscriptTurnBlockArtifact(
        block: TranscriptStatusBlock(
          id: artifactId,
          createdAt: item.createdAt,
          title: title,
          body: item.body,
          statusKind: _blockFactory.statusKindForItemType(item.itemType),
        ),
      ),
      TranscriptUiBlockKind.error => TranscriptTurnBlockArtifact(
        block: TranscriptErrorBlock(
          id: artifactId,
          createdAt: item.createdAt,
          title: title,
          body: item.body,
        ),
      ),
      TranscriptUiBlockKind.proposedPlan => TranscriptTurnPlanArtifact(
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

  bool _isWorkBlockKind(TranscriptUiBlockKind blockKind) {
    return switch (blockKind) {
      TranscriptUiBlockKind.workLogEntry => true,
      _ => false,
    };
  }
}

List<TranscriptChangedFile> _mergeChangedFilesForEntries(
  Iterable<TranscriptChangedFilesEntry> entries,
) {
  final mergedByPath = <String, TranscriptChangedFile>{};

  for (final entry in entries) {
    for (final file in entry.files) {
      mergedByPath[file.path] = file;
    }
  }

  return mergedByPath.values.toList(growable: false);
}

String? _mergedRetainedUnifiedDiff(
  Iterable<TranscriptChangedFilesEntry> entries,
) {
  return _joinUnifiedDiffFragments(
    entries.map((entry) => entry.unifiedDiff).toList(growable: false),
  );
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

List<TranscriptChangedFilesEntry> _retainChangedFilesEntryDiffs(
  List<TranscriptChangedFilesEntry> entries,
) {
  if (entries.isEmpty) {
    return entries;
  }

  final retainedEntries = List<TranscriptChangedFilesEntry>.from(entries);
  var remainingChars = TranscriptMemoryBudget.maxUnifiedDiffChars;
  var remainingLines = TranscriptMemoryBudget.maxUnifiedDiffLines;
  var hasRetainedLaterDiff = false;

  for (var index = entries.length - 1; index >= 0; index -= 1) {
    final entry = entries[index];
    final separatorChars = hasRetainedLaterDiff ? 1 : 0;
    final retainedDiff = _retainUnifiedDiffWithinBudget(
      entry.unifiedDiff,
      maxChars: remainingChars - separatorChars,
      maxLines: remainingLines,
    );

    if (retainedDiff != entry.unifiedDiff) {
      retainedEntries[index] = _changedFilesEntryWithUnifiedDiff(
        entry,
        retainedDiff,
      );
    }
    if (retainedDiff == null) {
      continue;
    }

    remainingChars -= retainedDiff.length + separatorChars;
    remainingLines -= _lineCount(retainedDiff);
    hasRetainedLaterDiff = true;
  }

  return retainedEntries;
}

String? _retainUnifiedDiffWithinBudget(
  String? unifiedDiff, {
  required int maxChars,
  required int maxLines,
}) {
  final trimmed = unifiedDiff?.trim();
  if (trimmed == null || trimmed.isEmpty || maxChars <= 0 || maxLines <= 0) {
    return null;
  }
  if (trimmed.length <= maxChars) {
    final lineCount = _lineCount(trimmed);
    if (lineCount <= maxLines) {
      return trimmed;
    }
  }

  final lines = trimmed.split(RegExp(r'\r?\n'));
  final buffer = StringBuffer();
  var lineCount = 0;
  var charCount = 0;

  for (final line in lines) {
    final additionalChars = (buffer.isEmpty ? 0 : 1) + line.length;
    if (lineCount >= maxLines || charCount + additionalChars > maxChars) {
      break;
    }
    if (buffer.isNotEmpty) {
      buffer.writeln();
      charCount += 1;
    }
    buffer.write(line);
    charCount += line.length;
    lineCount += 1;
  }

  final retained = buffer.toString().trim();
  return retained.isEmpty ? null : retained;
}

TranscriptChangedFilesEntry _changedFilesEntryWithUnifiedDiff(
  TranscriptChangedFilesEntry entry,
  String? unifiedDiff,
) {
  return TranscriptChangedFilesEntry(
    id: entry.id,
    itemId: entry.itemId,
    createdAt: entry.createdAt,
    files: entry.files,
    unifiedDiff: unifiedDiff,
    isRunning: entry.isRunning,
  );
}

int _lineCount(String value) =>
    value.isEmpty ? 0 : '\n'.allMatches(value).length + 1;
