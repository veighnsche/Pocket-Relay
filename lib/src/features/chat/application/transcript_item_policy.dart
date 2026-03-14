import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptItemPolicy {
  const TranscriptItemPolicy({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
  }) : _support = support;

  final TranscriptPolicySupport _support;

  CodexSessionState applyItemLifecycle(
    CodexSessionState state,
    CodexRuntimeItemLifecycleEvent event, {
    required bool removeAfterUpsert,
  }) {
    final existing = state.activeItems[event.itemId!];
    final nextItem = _activeItemFromLifecycle(event, existing: existing);
    final nextBlock = _blockFromActiveItem(nextItem);
    final nextActiveItems = <String, CodexSessionActiveItem>{
      ...state.activeItems,
      event.itemId!: nextItem,
    };

    final nextState = state.copyWith(
      activeItems: removeAfterUpsert
          ? <String, CodexSessionActiveItem>{
              ...nextActiveItems..remove(event.itemId!),
            }
          : nextActiveItems,
    );

    if (_shouldSuppressItemBlock(state, nextItem)) {
      return nextState;
    }

    return _support.upsertBlock(nextState, nextBlock);
  }

  CodexSessionState applyContentDelta(
    CodexSessionState state,
    CodexRuntimeContentDeltaEvent event,
  ) {
    final itemId = event.itemId;
    final threadId = event.threadId;
    final turnId = event.turnId;
    if (itemId == null || threadId == null || turnId == null) {
      return state;
    }

    final existing =
        state.activeItems[itemId] ?? _activeItemFromContentDelta(event);
    final updatedItem = existing.copyWith(
      body: '${existing.body}${event.delta}',
      isRunning: true,
    );

    return _support.upsertBlock(
      state.copyWith(
        activeItems: <String, CodexSessionActiveItem>{
          ...state.activeItems,
          itemId: updatedItem,
        },
      ),
      _blockFromActiveItem(updatedItem),
    );
  }

  List<CodexChangedFile> changedFilesFromSources({
    Map<String, dynamic>? snapshot,
    String? body,
    Object? rawPayload,
  }) {
    final filesByPath = <String, CodexChangedFile>{};

    void addFiles(Iterable<CodexChangedFile> files) {
      for (final file in files) {
        final existing = filesByPath[file.path];
        if (existing == null) {
          filesByPath[file.path] = file;
          continue;
        }
        filesByPath[file.path] = CodexChangedFile(
          path: file.path,
          additions: file.additions > 0 ? file.additions : existing.additions,
          deletions: file.deletions > 0 ? file.deletions : existing.deletions,
        );
      }
    }

    addFiles(_extractChangedFilesFromObject(snapshot));
    if (rawPayload is Map<String, dynamic>) {
      addFiles(_extractChangedFilesFromObject(rawPayload));
    } else if (rawPayload is Map) {
      addFiles(
        _extractChangedFilesFromObject(Map<String, dynamic>.from(rawPayload)),
      );
    }

    final unifiedDiff = unifiedDiffFromSources(snapshot: snapshot, body: body);
    if (unifiedDiff != null && unifiedDiff.isNotEmpty) {
      addFiles(_extractChangedFilesFromDiff(unifiedDiff));
    }

    return filesByPath.values.toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));
  }

  String? unifiedDiffFromSources({
    Map<String, dynamic>? snapshot,
    String? body,
  }) {
    final diff = _support.stringFromCandidates(<Object?>[
      body,
      snapshot?['unifiedDiff'],
      snapshot?['diff'],
      snapshot?['patch'],
      snapshot?['text'],
      snapshot?['aggregatedOutput'],
      snapshot?['aggregated_output'],
    ]);
    if (diff == null) {
      return null;
    }
    return diff.contains('diff --git') || diff.contains('@@') ? diff : null;
  }

  CodexSessionActiveItem _activeItemFromLifecycle(
    CodexRuntimeItemLifecycleEvent event, {
    CodexSessionActiveItem? existing,
  }) {
    final blockKind = _blockKindForItemType(event.itemType);
    final title = _itemTitle(event, existing?.title);
    final body = _itemBody(event, existing?.body ?? '');
    final exitCode = _extractExitCode(event.snapshot) ?? existing?.exitCode;
    return CodexSessionActiveItem(
      itemId: event.itemId!,
      threadId: event.threadId!,
      turnId: event.turnId!,
      itemType: event.itemType,
      entryId: existing?.entryId ?? 'item_${event.itemId}',
      blockKind: blockKind,
      createdAt: existing?.createdAt ?? event.createdAt,
      title: title,
      body: body,
      isRunning: event.status == CodexRuntimeItemStatus.inProgress,
      exitCode: exitCode,
      snapshot: event.snapshot ?? existing?.snapshot,
    );
  }

  CodexSessionActiveItem _activeItemFromContentDelta(
    CodexRuntimeContentDeltaEvent event,
  ) {
    final itemType = _itemTypeFromStreamKind(event.streamKind);
    return CodexSessionActiveItem(
      itemId: event.itemId!,
      threadId: event.threadId!,
      turnId: event.turnId!,
      itemType: itemType,
      entryId: 'item_${event.itemId}',
      blockKind: _blockKindForItemType(itemType),
      createdAt: event.createdAt,
      title: _defaultItemTitle(itemType),
      body: '',
      isRunning: true,
      snapshot: null,
    );
  }

  CodexUiBlock _blockFromActiveItem(CodexSessionActiveItem item) {
    final title = item.title ?? _defaultItemTitle(item.itemType);
    return switch (item.blockKind) {
      CodexUiBlockKind.userMessage => CodexUserMessageBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        text: item.body,
      ),
      CodexUiBlockKind.commandExecution => CodexCommandExecutionBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        command: title,
        output: item.body,
        isRunning: item.isRunning,
        exitCode: item.exitCode,
      ),
      CodexUiBlockKind.workLogEntry => CodexWorkLogEntryBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        entryKind: _workLogEntryKindFor(item.itemType),
        preview: _workLogPreview(item),
        isRunning: item.isRunning,
        exitCode: item.exitCode,
      ),
      CodexUiBlockKind.changedFiles => CodexChangedFilesBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        files: changedFilesFromSources(
          snapshot: item.snapshot,
          body: item.body,
        ),
        unifiedDiff: unifiedDiffFromSources(
          snapshot: item.snapshot,
          body: item.body,
        ),
        isRunning: item.isRunning,
      ),
      CodexUiBlockKind.reasoning => CodexTextBlock(
        id: item.entryId,
        kind: CodexUiBlockKind.reasoning,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
        isRunning: item.isRunning,
      ),
      CodexUiBlockKind.proposedPlan => CodexProposedPlanBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        markdown: item.body,
        isStreaming: item.isRunning,
      ),
      CodexUiBlockKind.plan => CodexPlanUpdateBlock(
        id: item.entryId,
        createdAt: item.createdAt,
      ),
      CodexUiBlockKind.status => CodexStatusBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
      ),
      CodexUiBlockKind.error => CodexErrorBlock(
        id: item.entryId,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
      ),
      _ => CodexTextBlock(
        id: item.entryId,
        kind: CodexUiBlockKind.assistantMessage,
        createdAt: item.createdAt,
        title: title,
        body: item.body,
        isRunning: item.isRunning,
      ),
    };
  }

  String _itemTitle(
    CodexRuntimeItemLifecycleEvent event,
    String? existingTitle,
  ) {
    if (event.itemType == CodexCanonicalItemType.commandExecution) {
      return event.detail?.trim().isNotEmpty == true
          ? event.detail!
          : (existingTitle ?? event.title ?? 'Command');
    }
    return existingTitle ?? event.title ?? _defaultItemTitle(event.itemType);
  }

  String _itemBody(CodexRuntimeItemLifecycleEvent event, String currentBody) {
    final snapshotText = _extractTextFromSnapshot(event.snapshot);
    if (event.itemType == CodexCanonicalItemType.commandExecution) {
      if (snapshotText != null && snapshotText.isNotEmpty) {
        return snapshotText;
      }
      if (event.rawMethod == 'item/commandExecution/terminalInteraction' &&
          event.detail != null &&
          event.detail!.isNotEmpty) {
        return event.detail!;
      }
      return currentBody;
    }

    final body = _support.stringFromCandidates(<Object?>[
      snapshotText,
      event.detail,
    ]);
    if (body != null && body.isNotEmpty) {
      return body;
    }
    if (currentBody.isNotEmpty) {
      return currentBody;
    }
    return switch (event.itemType) {
      CodexCanonicalItemType.reviewEntered => 'Codex entered review mode.',
      CodexCanonicalItemType.reviewExited => 'Codex exited review mode.',
      CodexCanonicalItemType.contextCompaction =>
        'Codex compacted the current thread context.',
      _ => currentBody,
    };
  }

  bool _shouldSuppressItemBlock(
    CodexSessionState state,
    CodexSessionActiveItem item,
  ) {
    if (item.itemType == CodexCanonicalItemType.reasoning &&
        item.body.trim().isEmpty) {
      return true;
    }

    if (item.itemType != CodexCanonicalItemType.userMessage) {
      return false;
    }

    final text = item.body.trim();
    if (text.isEmpty) {
      return true;
    }

    final latestBlock = state.blocks.isEmpty ? null : state.blocks.last;
    return latestBlock is CodexUserMessageBlock && latestBlock.text == text;
  }

  String? _extractTextFromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null) {
      return null;
    }

    final result = snapshot['result'];
    final nestedResult = result is Map<String, dynamic> ? result : null;
    return _support.stringFromCandidates(<Object?>[
      snapshot['aggregatedOutput'],
      snapshot['aggregated_output'],
      snapshot['text'],
      snapshot['summary'],
      snapshot['review'],
      snapshot['revisedPrompt'],
      snapshot['patch'],
      snapshot['result'],
      nestedResult?['output'],
      nestedResult?['text'],
      nestedResult?['path'],
    ]);
  }

  int? _extractExitCode(Map<String, dynamic>? snapshot) {
    final value = snapshot?['exitCode'] ?? snapshot?['exit_code'];
    return value is num ? value.toInt() : null;
  }

  CodexUiBlockKind _blockKindForItemType(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.userMessage => CodexUiBlockKind.userMessage,
      CodexCanonicalItemType.commandExecution ||
      CodexCanonicalItemType.webSearch ||
      CodexCanonicalItemType.imageView ||
      CodexCanonicalItemType.imageGeneration ||
      CodexCanonicalItemType.mcpToolCall ||
      CodexCanonicalItemType.dynamicToolCall ||
      CodexCanonicalItemType.collabAgentToolCall =>
        CodexUiBlockKind.workLogEntry,
      CodexCanonicalItemType.reasoning => CodexUiBlockKind.reasoning,
      CodexCanonicalItemType.plan => CodexUiBlockKind.proposedPlan,
      CodexCanonicalItemType.fileChange => CodexUiBlockKind.changedFiles,
      CodexCanonicalItemType.reviewEntered ||
      CodexCanonicalItemType.reviewExited ||
      CodexCanonicalItemType.contextCompaction ||
      CodexCanonicalItemType.unknown => CodexUiBlockKind.status,
      CodexCanonicalItemType.error => CodexUiBlockKind.error,
      _ => CodexUiBlockKind.assistantMessage,
    };
  }

  CodexCanonicalItemType _itemTypeFromStreamKind(
    CodexRuntimeContentStreamKind streamKind,
  ) {
    return switch (streamKind) {
      CodexRuntimeContentStreamKind.assistantText =>
        CodexCanonicalItemType.assistantMessage,
      CodexRuntimeContentStreamKind.reasoningText ||
      CodexRuntimeContentStreamKind.reasoningSummaryText =>
        CodexCanonicalItemType.reasoning,
      CodexRuntimeContentStreamKind.planText => CodexCanonicalItemType.plan,
      CodexRuntimeContentStreamKind.commandOutput =>
        CodexCanonicalItemType.commandExecution,
      CodexRuntimeContentStreamKind.fileChangeOutput =>
        CodexCanonicalItemType.fileChange,
      _ => CodexCanonicalItemType.unknown,
    };
  }

  String _defaultItemTitle(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.userMessage => 'You',
      CodexCanonicalItemType.assistantMessage => 'Codex',
      CodexCanonicalItemType.reasoning => 'Reasoning',
      CodexCanonicalItemType.plan => 'Proposed plan',
      CodexCanonicalItemType.commandExecution => 'Command',
      CodexCanonicalItemType.fileChange => 'Changed files',
      CodexCanonicalItemType.webSearch => 'Web search',
      CodexCanonicalItemType.imageView => 'Image view',
      CodexCanonicalItemType.imageGeneration => 'Image generation',
      CodexCanonicalItemType.mcpToolCall => 'MCP tool call',
      CodexCanonicalItemType.dynamicToolCall => 'Tool call',
      CodexCanonicalItemType.collabAgentToolCall => 'Agent tool call',
      CodexCanonicalItemType.reviewEntered => 'Review started',
      CodexCanonicalItemType.reviewExited => 'Review finished',
      CodexCanonicalItemType.contextCompaction => 'Context compacted',
      CodexCanonicalItemType.error => 'Error',
      _ => 'Codex',
    };
  }

  CodexWorkLogEntryKind _workLogEntryKindFor(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.commandExecution =>
        CodexWorkLogEntryKind.commandExecution,
      CodexCanonicalItemType.webSearch => CodexWorkLogEntryKind.webSearch,
      CodexCanonicalItemType.imageView => CodexWorkLogEntryKind.imageView,
      CodexCanonicalItemType.imageGeneration =>
        CodexWorkLogEntryKind.imageGeneration,
      CodexCanonicalItemType.mcpToolCall => CodexWorkLogEntryKind.mcpToolCall,
      CodexCanonicalItemType.dynamicToolCall =>
        CodexWorkLogEntryKind.dynamicToolCall,
      CodexCanonicalItemType.collabAgentToolCall =>
        CodexWorkLogEntryKind.collabAgentToolCall,
      CodexCanonicalItemType.fileChange => CodexWorkLogEntryKind.fileChange,
      _ => CodexWorkLogEntryKind.unknown,
    };
  }

  String? _workLogPreview(CodexSessionActiveItem item) {
    final body = item.body.trim();
    if (body.isEmpty) {
      return null;
    }

    if (item.itemType == CodexCanonicalItemType.commandExecution) {
      final lines = body
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      return lines.isEmpty ? null : lines.last;
    }

    return body.split(RegExp(r'\r?\n')).first.trim();
  }

  List<CodexChangedFile> _extractChangedFilesFromObject(
    Map<String, dynamic>? value,
  ) {
    if (value == null) {
      return const <CodexChangedFile>[];
    }

    final paths = <String>{};

    void collect(Object? current, int depth) {
      if (current == null || depth > 4 || paths.length >= 20) {
        return;
      }

      if (current is List) {
        for (final entry in current) {
          collect(entry, depth + 1);
          if (paths.length >= 20) {
            return;
          }
        }
        return;
      }

      final map = switch (current) {
        final Map<String, dynamic> typedMap => typedMap,
        final Map rawMap => Map<String, dynamic>.from(rawMap),
        _ => null,
      };
      if (map == null) {
        return;
      }

      for (final key in <String>[
        'path',
        'filePath',
        'relativePath',
        'filename',
        'newPath',
        'oldPath',
      ]) {
        final candidate = map[key];
        if (candidate is String && candidate.trim().isNotEmpty) {
          paths.add(candidate.trim());
        }
      }

      for (final nestedKey in <String>[
        'item',
        'result',
        'input',
        'data',
        'changes',
        'files',
        'edits',
        'patch',
        'patches',
        'operations',
      ]) {
        if (map.containsKey(nestedKey)) {
          collect(map[nestedKey], depth + 1);
        }
      }
    }

    collect(value, 0);
    return paths
        .map((path) => CodexChangedFile(path: path))
        .toList(growable: false);
  }

  List<CodexChangedFile> _extractChangedFilesFromDiff(String diff) {
    final files = <String, _DiffStat>{};
    String? currentPath;

    for (final line in diff.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('diff --git ')) {
        final match = RegExp(r'^diff --git a/(.+?) b/(.+)$').firstMatch(line);
        final path = _normalizeDiffPath(match?.group(2));
        if (path != null) {
          currentPath = path;
          files.putIfAbsent(path, () => const _DiffStat());
        }
        continue;
      }

      if (line.startsWith('+++ ')) {
        final path = _normalizeDiffPath(line.substring(4).trim());
        if (path != null) {
          currentPath = path;
          files.putIfAbsent(path, () => const _DiffStat());
        }
        continue;
      }

      if (line.startsWith('rename to ')) {
        final path = _normalizeDiffPath(line.substring('rename to '.length));
        if (path != null) {
          currentPath = path;
          files.putIfAbsent(path, () => const _DiffStat());
        }
        continue;
      }

      if (currentPath == null) {
        continue;
      }

      if (line.startsWith('+++') || line.startsWith('---')) {
        continue;
      }

      if (line.startsWith('+')) {
        final stat = files[currentPath] ?? const _DiffStat();
        files[currentPath] = stat.copyWith(additions: stat.additions + 1);
      } else if (line.startsWith('-')) {
        final stat = files[currentPath] ?? const _DiffStat();
        files[currentPath] = stat.copyWith(deletions: stat.deletions + 1);
      }
    }

    return files.entries
        .map(
          (entry) => CodexChangedFile(
            path: entry.key,
            additions: entry.value.additions,
            deletions: entry.value.deletions,
          ),
        )
        .toList(growable: false);
  }

  String? _normalizeDiffPath(String? rawPath) {
    if (rawPath == null) {
      return null;
    }

    final trimmed = rawPath.trim();
    if (trimmed.isEmpty || trimmed == '/dev/null') {
      return null;
    }

    if (trimmed.startsWith('a/') || trimmed.startsWith('b/')) {
      return trimmed.substring(2);
    }
    return trimmed;
  }
}

class _DiffStat {
  const _DiffStat({this.additions = 0, this.deletions = 0});

  final int additions;
  final int deletions;

  _DiffStat copyWith({int? additions, int? deletions}) {
    return _DiffStat(
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
    );
  }
}
