import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

part 'chat_work_log_item_projector_classifier.dart';
part 'chat_work_log_item_projector_parser.dart';
part 'chat_work_log_item_projector_parser_git.dart';
part 'chat_work_log_item_projector_parser_git_history.dart';
part 'chat_work_log_item_projector_parser_git_mutation.dart';
part 'chat_work_log_item_projector_parser_git_support.dart';
part 'chat_work_log_item_projector_parser_read.dart';
part 'chat_work_log_item_projector_parser_search.dart';
part 'chat_work_log_item_projector_parser_shell.dart';
part 'chat_work_log_item_projector_support_generic.dart';
part 'chat_work_log_item_projector_support_git.dart';
part 'chat_work_log_item_projector_support_mcp.dart';
part 'chat_work_log_item_projector_support_shell.dart';

class ChatWorkLogItemProjector {
  const ChatWorkLogItemProjector();

  ChatWorkLogGroupItemContract project(TranscriptWorkLogGroupBlock block) {
    return ChatWorkLogGroupItemContract(
      id: block.id,
      entries: block.entries.map(_projectEntry).toList(growable: false),
    );
  }

  ChatTranscriptItemContract projectTranscriptItem(
    TranscriptWorkLogGroupBlock block,
  ) {
    final projected = project(block);
    if (projected.entries.length != 1) {
      return projected;
    }

    return switch (projected.entries.single) {
      final ChatCommandExecutionWorkLogEntryContract commandEntry =>
        ChatExecCommandItemContract(entry: commandEntry),
      final ChatCommandWaitWorkLogEntryContract waitEntry =>
        ChatExecWaitItemContract(entry: waitEntry),
      final ChatWebSearchWorkLogEntryContract webSearchEntry =>
        ChatWebSearchItemContract(entry: webSearchEntry),
      _ => projected,
    };
  }

  ChatWorkLogEntryContract _projectEntry(TranscriptWorkLogEntry entry) {
    final normalizedTitle = _normalizeCompactToolLabel(entry.title);
    for (final classifier in _entryClassifiers) {
      final projected = classifier(this, entry, normalizedTitle);
      if (projected != null) {
        return projected;
      }
    }

    return ChatGenericWorkLogEntryContract(
      id: entry.id,
      entryKind: entry.entryKind,
      title: normalizedTitle,
      preview: _normalizedWorkLogPreview(entry.preview, normalizedTitle),
      turnId: entry.turnId,
      isRunning: entry.isRunning,
      exitCode: entry.exitCode,
    );
  }

  ChatCommandWaitWorkLogEntryContract? _projectCommandWait(
    TranscriptWorkLogEntry entry, {
    required String normalizedTitle,
  }) {
    if (!_isBackgroundTerminalWait(
      entry.snapshot,
      isRunning: entry.isRunning,
    )) {
      return null;
    }

    final snapshot = entry.snapshot;
    final shellFields = _shellTerminalFields(
      entry,
      commandText: normalizedTitle,
    );
    return ChatCommandWaitWorkLogEntryContract(
      id: entry.id,
      commandText: normalizedTitle,
      outputPreview: _normalizedWorkLogPreview(entry.preview, normalizedTitle),
      itemId: entry.itemId,
      threadId: entry.threadId,
      processId: shellFields.processId,
      terminalInput: shellFields.terminalInput,
      terminalOutput: shellFields.terminalOutput,
      turnId: entry.turnId,
      isRunning: entry.isRunning,
      exitCode: entry.exitCode,
    );
  }

  ChatCommandExecutionWorkLogEntryContract? _projectCommandExecution(
    TranscriptWorkLogEntry entry, {
    required String normalizedTitle,
  }) {
    if (!_looksLikeCommandExecution(normalizedTitle) &&
        !_hasBackgroundTerminalMetadata(entry.snapshot)) {
      return null;
    }

    final shellFields = _shellTerminalFields(
      entry,
      commandText: normalizedTitle,
    );
    return ChatCommandExecutionWorkLogEntryContract(
      id: entry.id,
      commandText: normalizedTitle,
      outputPreview: _normalizedWorkLogPreview(entry.preview, normalizedTitle),
      itemId: entry.itemId,
      threadId: entry.threadId,
      processId: shellFields.processId,
      terminalInput: shellFields.terminalInput,
      terminalOutput: shellFields.terminalOutput,
      turnId: entry.turnId,
      isRunning: entry.isRunning,
      exitCode: entry.exitCode,
    );
  }

  ChatMcpToolCallWorkLogEntryContract? _projectMcpToolCall(
    TranscriptWorkLogEntry entry,
  ) {
    final snapshot = entry.snapshot;
    if (snapshot == null) {
      return null;
    }

    final serverName = _firstNonEmptyString(<Object?>[
      snapshot['server'],
      snapshot['serverName'],
    ]);
    final toolName = _firstNonEmptyString(<Object?>[
      snapshot['tool'],
      snapshot['toolName'],
    ]);
    if (serverName == null || toolName == null) {
      return null;
    }

    final status = _mcpToolCallStatus(snapshot, isRunning: entry.isRunning);
    final preview = _normalizedMcpPreview(entry.preview, toolName: toolName);
    final errorMessage = _firstNonEmptyString(<Object?>[
      _asObjectValue(snapshot['error'])?['message'],
      snapshot['errorMessage'],
    ]);
    final argumentsSummary = _summarizeMcpValue(snapshot['arguments']);
    final resultSummary = _mcpResultSummary(snapshot['result']) ?? preview;
    final progressSummary = status == ChatMcpToolCallStatus.running
        ? preview
        : null;
    final failureSummary = status == ChatMcpToolCallStatus.failed
        ? (errorMessage ?? preview ?? resultSummary ?? argumentsSummary)
        : null;
    final completionSummary = status == ChatMcpToolCallStatus.completed
        ? (resultSummary ?? argumentsSummary)
        : null;

    return ChatMcpToolCallWorkLogEntryContract(
      id: entry.id,
      serverName: serverName,
      toolName: toolName,
      status: status,
      argumentsSummary: argumentsSummary,
      progressSummary: progressSummary,
      resultSummary: completionSummary,
      errorSummary: failureSummary,
      durationMs: _intValue(snapshot['durationMs'] ?? snapshot['duration_ms']),
      rawArguments: snapshot['arguments'],
      rawResult: snapshot['result'],
      rawError: snapshot['error'],
      turnId: entry.turnId,
      isRunning: entry.isRunning,
    );
  }

  ChatWebSearchWorkLogEntryContract? _projectWebSearch(
    TranscriptWorkLogEntry entry,
  ) {
    final snapshot = entry.snapshot;
    final queries = _webSearchQueries(snapshot);
    final queryText = _firstNonEmptyString(<Object?>[
      snapshot?['query'],
      snapshot?['title'],
      if (queries != null && queries.isNotEmpty) queries.join(' | '),
      entry.preview,
      entry.title,
    ]);
    if (queryText == null) {
      return null;
    }

    final resultSummary = _firstNonEmptyString(<Object?>[
      _webSearchResultSummary(snapshot?['result']),
      _webSearchResultSummary(snapshot?['results']),
      _summarizeMcpValue(snapshot?['result']),
      _summarizeMcpValue(snapshot?['results']),
      entry.preview,
    ]);

    return ChatWebSearchWorkLogEntryContract(
      id: entry.id,
      queryText: queryText,
      resultSummary: resultSummary == queryText ? null : resultSummary,
      queryCount: queries?.length,
      turnId: entry.turnId,
      isRunning: entry.isRunning,
    );
  }

  ChatFileReadWorkLogEntryContract _projectReadCommand({
    required _ParsedReadCommand readCommand,
    required TranscriptWorkLogEntry entry,
    required String normalizedTitle,
  }) {
    final fileName = _fileNameForPath(readCommand.path);
    final shellFields = _shellTerminalFields(
      entry,
      commandText: normalizedTitle,
    );
    return switch (readCommand) {
      final _ParsedSedReadCommand sedRead => ChatSedReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: sedRead.path,
        lineStart: sedRead.lineStart,
        lineEnd: sedRead.lineEnd,
        itemId: entry.itemId,
        threadId: entry.threadId,
        processId: shellFields.processId,
        terminalInput: shellFields.terminalInput,
        terminalOutput: shellFields.terminalOutput,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedCatReadCommand catRead => ChatCatReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: catRead.path,
        itemId: entry.itemId,
        threadId: entry.threadId,
        processId: shellFields.processId,
        terminalInput: shellFields.terminalInput,
        terminalOutput: shellFields.terminalOutput,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedTypeReadCommand typeRead => ChatTypeReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: typeRead.path,
        itemId: entry.itemId,
        threadId: entry.threadId,
        processId: shellFields.processId,
        terminalInput: shellFields.terminalInput,
        terminalOutput: shellFields.terminalOutput,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedMoreReadCommand moreRead => ChatMoreReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: moreRead.path,
        itemId: entry.itemId,
        threadId: entry.threadId,
        processId: shellFields.processId,
        terminalInput: shellFields.terminalInput,
        terminalOutput: shellFields.terminalOutput,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedHeadReadCommand headRead => ChatHeadReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: headRead.path,
        lineCount: headRead.lineCount,
        itemId: entry.itemId,
        threadId: entry.threadId,
        processId: shellFields.processId,
        terminalInput: shellFields.terminalInput,
        terminalOutput: shellFields.terminalOutput,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedTailReadCommand tailRead => ChatTailReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: tailRead.path,
        lineCount: tailRead.lineCount,
        itemId: entry.itemId,
        threadId: entry.threadId,
        processId: shellFields.processId,
        terminalInput: shellFields.terminalInput,
        terminalOutput: shellFields.terminalOutput,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedAwkReadCommand awkRead => ChatAwkReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: awkRead.path,
        lineStart: awkRead.lineStart,
        lineEnd: awkRead.lineEnd,
        itemId: entry.itemId,
        threadId: entry.threadId,
        processId: shellFields.processId,
        terminalInput: shellFields.terminalInput,
        terminalOutput: shellFields.terminalOutput,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedGetContentReadCommand getContentRead =>
        ChatGetContentReadWorkLogEntryContract(
          id: entry.id,
          commandText: normalizedTitle,
          fileName: fileName,
          filePath: getContentRead.path,
          mode: getContentRead.mode,
          lineCount: getContentRead.lineCount,
          lineStart: getContentRead.lineStart,
          lineEnd: getContentRead.lineEnd,
          itemId: entry.itemId,
          threadId: entry.threadId,
          processId: shellFields.processId,
          terminalInput: shellFields.terminalInput,
          terminalOutput: shellFields.terminalOutput,
          turnId: entry.turnId,
          isRunning: entry.isRunning,
          exitCode: entry.exitCode,
        ),
    };
  }

  ChatGitWorkLogEntryContract _projectGitCommand({
    required _ParsedGitCommand gitCommand,
    required TranscriptWorkLogEntry entry,
    required String normalizedTitle,
  }) {
    final shellFields = _shellTerminalFields(
      entry,
      commandText: normalizedTitle,
    );
    return ChatGitWorkLogEntryContract(
      id: entry.id,
      commandText: normalizedTitle,
      subcommandLabel: gitCommand.subcommandLabel,
      summaryLabel: gitCommand.summaryLabel,
      primaryLabel: gitCommand.primaryLabel,
      secondaryLabel: gitCommand.secondaryLabel,
      itemId: entry.itemId,
      threadId: entry.threadId,
      processId: shellFields.processId,
      terminalInput: shellFields.terminalInput,
      terminalOutput: shellFields.terminalOutput,
      turnId: entry.turnId,
      isRunning: entry.isRunning,
      exitCode: entry.exitCode,
    );
  }

  ChatContentSearchWorkLogEntryContract _projectSearchCommand({
    required _ParsedContentSearchCommand searchCommand,
    required TranscriptWorkLogEntry entry,
    required String normalizedTitle,
  }) {
    final scopeTargets = List<String>.unmodifiable(searchCommand.scopeTargets);
    final shellFields = _shellTerminalFields(
      entry,
      commandText: normalizedTitle,
    );
    return switch (searchCommand) {
      final _ParsedRipgrepSearchCommand rgSearch =>
        ChatRipgrepSearchWorkLogEntryContract(
          id: entry.id,
          commandText: normalizedTitle,
          queryText: rgSearch.query,
          scopeTargets: scopeTargets,
          itemId: entry.itemId,
          threadId: entry.threadId,
          processId: shellFields.processId,
          terminalInput: shellFields.terminalInput,
          terminalOutput: shellFields.terminalOutput,
          turnId: entry.turnId,
          isRunning: entry.isRunning,
          exitCode: entry.exitCode,
        ),
      final _ParsedGrepSearchCommand grepSearch =>
        ChatGrepSearchWorkLogEntryContract(
          id: entry.id,
          commandText: normalizedTitle,
          queryText: grepSearch.query,
          scopeTargets: scopeTargets,
          itemId: entry.itemId,
          threadId: entry.threadId,
          processId: shellFields.processId,
          terminalInput: shellFields.terminalInput,
          terminalOutput: shellFields.terminalOutput,
          turnId: entry.turnId,
          isRunning: entry.isRunning,
          exitCode: entry.exitCode,
        ),
      final _ParsedSelectStringSearchCommand selectStringSearch =>
        ChatSelectStringSearchWorkLogEntryContract(
          id: entry.id,
          commandText: normalizedTitle,
          queryText: selectStringSearch.query,
          scopeTargets: scopeTargets,
          itemId: entry.itemId,
          threadId: entry.threadId,
          processId: shellFields.processId,
          terminalInput: shellFields.terminalInput,
          terminalOutput: shellFields.terminalOutput,
          turnId: entry.turnId,
          isRunning: entry.isRunning,
          exitCode: entry.exitCode,
        ),
      final _ParsedFindStrSearchCommand findStrSearch =>
        ChatFindStrSearchWorkLogEntryContract(
          id: entry.id,
          commandText: normalizedTitle,
          queryText: findStrSearch.query,
          scopeTargets: scopeTargets,
          itemId: entry.itemId,
          threadId: entry.threadId,
          processId: shellFields.processId,
          terminalInput: shellFields.terminalInput,
          terminalOutput: shellFields.terminalOutput,
          turnId: entry.turnId,
          isRunning: entry.isRunning,
          exitCode: entry.exitCode,
        ),
    };
  }
}
