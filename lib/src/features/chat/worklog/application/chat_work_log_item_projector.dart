import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

typedef _EntryClassifier =
    ChatWorkLogEntryContract? Function(
      ChatWorkLogItemProjector projector,
      CodexWorkLogEntry entry,
      String normalizedTitle,
    );

class ChatWorkLogItemProjector {
  const ChatWorkLogItemProjector();

  static final RegExp _sedPrintRangePattern = RegExp(r'^(\d+)(?:,(\d+))?p$');
  static final RegExp _shortHeadTailCountPattern = RegExp(r'^-(\d+)$');

  ChatWorkLogGroupItemContract project(CodexWorkLogGroupBlock block) {
    return ChatWorkLogGroupItemContract(
      id: block.id,
      entries: block.entries.map(_projectEntry).toList(growable: false),
    );
  }

  ChatTranscriptItemContract projectTranscriptItem(
    CodexWorkLogGroupBlock block,
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
      final ChatMcpToolCallWorkLogEntryContract mcpEntry =>
        ChatMcpToolCallItemContract(entry: mcpEntry),
      _ => projected,
    };
  }

  ChatWorkLogEntryContract _projectEntry(CodexWorkLogEntry entry) {
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

  static final List<_EntryClassifier> _entryClassifiers = <_EntryClassifier>[
    (projector, entry, normalizedTitle) =>
        entry.entryKind == CodexWorkLogEntryKind.mcpToolCall
        ? projector._projectMcpToolCall(entry)
        : null,
    (projector, entry, normalizedTitle) =>
        entry.entryKind == CodexWorkLogEntryKind.webSearch
        ? projector._projectWebSearch(entry)
        : null,
    (projector, entry, normalizedTitle) =>
        entry.entryKind == CodexWorkLogEntryKind.commandExecution
        ? projector._projectCommandWait(entry, normalizedTitle: normalizedTitle)
        : null,
    (projector, entry, normalizedTitle) => switch (
      entry.entryKind == CodexWorkLogEntryKind.commandExecution
          ? projector._tryParseReadCommand(normalizedTitle)
          : null
    ) {
      final _ParsedReadCommand readCommand => projector._projectReadCommand(
        readCommand: readCommand,
        entry: entry,
        normalizedTitle: normalizedTitle,
      ),
      _ => null,
    },
    (projector, entry, normalizedTitle) => switch (
      entry.entryKind == CodexWorkLogEntryKind.commandExecution
          ? projector._tryParseGitCommand(normalizedTitle)
          : null
    ) {
      final _ParsedGitCommand gitCommand => projector._projectGitCommand(
        gitCommand: gitCommand,
        entry: entry,
        normalizedTitle: normalizedTitle,
      ),
      _ => null,
    },
    (projector, entry, normalizedTitle) => switch (
      entry.entryKind == CodexWorkLogEntryKind.commandExecution
          ? projector._tryParseContentSearchCommand(normalizedTitle)
          : null
    ) {
      final _ParsedContentSearchCommand searchCommand =>
        projector._projectSearchCommand(
          searchCommand: searchCommand,
          entry: entry,
          normalizedTitle: normalizedTitle,
        ),
      _ => null,
    },
    (projector, entry, normalizedTitle) =>
        entry.entryKind == CodexWorkLogEntryKind.commandExecution
        ? projector._projectCommandExecution(
            entry,
            normalizedTitle: normalizedTitle,
          )
        : null,
  ];

  ChatCommandWaitWorkLogEntryContract? _projectCommandWait(
    CodexWorkLogEntry entry, {
    required String normalizedTitle,
  }) {
    if (!_isBackgroundTerminalWait(
      entry.snapshot,
      isRunning: entry.isRunning,
    )) {
      return null;
    }

    final snapshot = entry.snapshot;
    return ChatCommandWaitWorkLogEntryContract(
      id: entry.id,
      commandText: normalizedTitle,
      outputPreview: _normalizedWorkLogPreview(entry.preview, normalizedTitle),
      processId: _firstNonEmptyString(<Object?>[
        snapshot?['processId'],
        snapshot?['process_id'],
      ]),
      turnId: entry.turnId,
      isRunning: entry.isRunning,
      exitCode: entry.exitCode,
    );
  }

  ChatCommandExecutionWorkLogEntryContract? _projectCommandExecution(
    CodexWorkLogEntry entry, {
    required String normalizedTitle,
  }) {
    if (!_looksLikeCommandExecution(normalizedTitle) &&
        !_hasBackgroundTerminalMetadata(entry.snapshot)) {
      return null;
    }

    return ChatCommandExecutionWorkLogEntryContract(
      id: entry.id,
      commandText: normalizedTitle,
      outputPreview: _normalizedWorkLogPreview(entry.preview, normalizedTitle),
      turnId: entry.turnId,
      isRunning: entry.isRunning,
      exitCode: entry.exitCode,
    );
  }

  ChatMcpToolCallWorkLogEntryContract? _projectMcpToolCall(
    CodexWorkLogEntry entry,
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
    CodexWorkLogEntry entry,
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
    required CodexWorkLogEntry entry,
    required String normalizedTitle,
  }) {
    final fileName = _fileNameForPath(readCommand.path);
    return switch (readCommand) {
      final _ParsedSedReadCommand sedRead => ChatSedReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: sedRead.path,
        lineStart: sedRead.lineStart,
        lineEnd: sedRead.lineEnd,
        turnId: entry.turnId,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      final _ParsedCatReadCommand catRead => ChatCatReadWorkLogEntryContract(
        id: entry.id,
        commandText: normalizedTitle,
        fileName: fileName,
        filePath: catRead.path,
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
          turnId: entry.turnId,
          isRunning: entry.isRunning,
          exitCode: entry.exitCode,
        ),
    };
  }

  ChatGitWorkLogEntryContract _projectGitCommand({
    required _ParsedGitCommand gitCommand,
    required CodexWorkLogEntry entry,
    required String normalizedTitle,
  }) {
    return ChatGitWorkLogEntryContract(
      id: entry.id,
      commandText: normalizedTitle,
      subcommandLabel: gitCommand.subcommandLabel,
      summaryLabel: gitCommand.summaryLabel,
      primaryLabel: gitCommand.primaryLabel,
      secondaryLabel: gitCommand.secondaryLabel,
      turnId: entry.turnId,
      isRunning: entry.isRunning,
      exitCode: entry.exitCode,
    );
  }

  ChatContentSearchWorkLogEntryContract _projectSearchCommand({
    required _ParsedContentSearchCommand searchCommand,
    required CodexWorkLogEntry entry,
    required String normalizedTitle,
  }) {
    final scopeTargets = List<String>.unmodifiable(searchCommand.scopeTargets);
    return switch (searchCommand) {
      final _ParsedRipgrepSearchCommand rgSearch =>
        ChatRipgrepSearchWorkLogEntryContract(
          id: entry.id,
          commandText: normalizedTitle,
          queryText: rgSearch.query,
          scopeTargets: scopeTargets,
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
          turnId: entry.turnId,
          isRunning: entry.isRunning,
          exitCode: entry.exitCode,
        ),
    };
  }

  _ParsedReadCommand? _tryParseReadCommand(String commandText) {
    if (commandText.isEmpty || _containsShellOperators(commandText)) {
      return null;
    }

    return _tryParseReadCommandTokens(
      _tokenizeShellCommand(commandText),
      originalCommandText: commandText,
    );
  }

  _ParsedContentSearchCommand? _tryParseContentSearchCommand(
    String commandText,
  ) {
    if (commandText.isEmpty || _containsShellOperators(commandText)) {
      return null;
    }

    return _tryParseContentSearchCommandTokens(
      _tokenizeShellCommand(commandText),
      originalCommandText: commandText,
    );
  }

  _ParsedGitCommand? _tryParseGitCommand(String commandText) {
    if (commandText.isEmpty || _containsShellOperators(commandText)) {
      return null;
    }

    return _tryParseGitCommandTokens(
      _tokenizeShellCommand(commandText),
      originalCommandText: commandText,
    );
  }

  _ParsedReadCommand? _tryParseReadCommandTokens(
    List<String>? tokens, {
    required String originalCommandText,
  }) {
    if (tokens == null || tokens.isEmpty) {
      return null;
    }

    final commandName = _commandName(tokens.first);
    if (commandName == 'pwsh' || commandName == 'powershell') {
      final unwrappedCommand = _unwrapPowerShellWrappedCommand(tokens);
      if (unwrappedCommand == null || unwrappedCommand == originalCommandText) {
        return null;
      }
      return _tryParseReadCommand(unwrappedCommand);
    }

    return switch (commandName) {
      'sed' => _tryParseSedReadCommand(tokens),
      'cat' => _tryParseCatReadCommand(tokens),
      'head' => _tryParseHeadReadCommand(tokens),
      'tail' => _tryParseTailReadCommand(tokens),
      'get-content' => _tryParseGetContentReadCommand(tokens),
      _ => null,
    };
  }

  _ParsedContentSearchCommand? _tryParseContentSearchCommandTokens(
    List<String>? tokens, {
    required String originalCommandText,
  }) {
    if (tokens == null || tokens.isEmpty) {
      return null;
    }

    final commandName = _commandName(tokens.first);
    if (commandName == 'pwsh' || commandName == 'powershell') {
      final unwrappedCommand = _unwrapPowerShellWrappedCommand(tokens);
      if (unwrappedCommand == null || unwrappedCommand == originalCommandText) {
        return null;
      }
      return _tryParseContentSearchCommand(unwrappedCommand);
    }

    return switch (commandName) {
      'rg' => _tryParseRipgrepSearchCommand(tokens),
      'grep' => _tryParseGrepSearchCommand(tokens),
      'select-string' => _tryParseSelectStringSearchCommand(tokens),
      'findstr' => _tryParseFindStrSearchCommand(tokens),
      _ => null,
    };
  }

  _ParsedGitCommand? _tryParseGitCommandTokens(
    List<String>? tokens, {
    required String originalCommandText,
  }) {
    if (tokens == null || tokens.isEmpty) {
      return null;
    }

    final commandName = _commandName(tokens.first);
    if (commandName == 'pwsh' || commandName == 'powershell') {
      final unwrappedCommand = _unwrapPowerShellWrappedCommand(tokens);
      if (unwrappedCommand == null || unwrappedCommand == originalCommandText) {
        return null;
      }
      return _tryParseGitCommand(unwrappedCommand);
    }
    if (commandName != 'git') {
      return null;
    }

    final invocation = _parseGitInvocation(tokens);
    if (invocation == null) {
      return null;
    }

    return _buildParsedGitCommand(invocation);
  }

  _ParsedSedReadCommand? _tryParseSedReadCommand(List<String> tokens) {
    if (tokens.length < 4) {
      return null;
    }

    var index = 1;
    var hasPrintOnlyFlag = false;
    String? scriptToken;
    while (index < tokens.length) {
      final token = tokens[index];
      if (!token.startsWith('-') || token == '-') {
        break;
      }
      if (token == '--') {
        index++;
        break;
      }
      if (token == '-n') {
        hasPrintOnlyFlag = true;
        index++;
        continue;
      }
      if (token == '-e') {
        if (scriptToken != null || index + 1 >= tokens.length) {
          return null;
        }
        scriptToken = tokens[index + 1];
        index += 2;
        continue;
      }
      if (token == '-ne' || token == '-en') {
        if (scriptToken != null || index + 1 >= tokens.length) {
          return null;
        }
        hasPrintOnlyFlag = true;
        scriptToken = tokens[index + 1];
        index += 2;
        continue;
      }
      if (token != '-n') {
        return null;
      }
    }

    if (!hasPrintOnlyFlag || index >= tokens.length) {
      return null;
    }

    final resolvedScriptToken = scriptToken ?? tokens[index];
    final scriptMatch = _sedPrintRangePattern.firstMatch(resolvedScriptToken);
    if (scriptMatch == null) {
      return null;
    }
    if (scriptToken == null) {
      index++;
    }

    if (index < tokens.length && tokens[index] == '--') {
      index++;
    }

    if (index != tokens.length - 1) {
      return null;
    }

    final path = tokens[index].trim();
    if (!_isFileTarget(path)) {
      return null;
    }

    final lineStart = int.parse(scriptMatch.group(1)!);
    final lineEnd = int.parse(scriptMatch.group(2) ?? scriptMatch.group(1)!);
    if (lineStart <= 0 || lineEnd < lineStart) {
      return null;
    }
    return _ParsedSedReadCommand(
      lineStart: lineStart,
      lineEnd: lineEnd,
      path: path,
    );
  }

  _ParsedCatReadCommand? _tryParseCatReadCommand(List<String> tokens) {
    var index = 1;
    if (index < tokens.length && tokens[index] == '--') {
      index++;
    } else if (index < tokens.length && tokens[index].startsWith('-')) {
      return null;
    }

    if (index != tokens.length - 1) {
      return null;
    }

    final path = tokens[index].trim();
    if (!_isFileTarget(path)) {
      return null;
    }
    return _ParsedCatReadCommand(path: path);
  }

  _ParsedHeadReadCommand? _tryParseHeadReadCommand(List<String> tokens) {
    final parsed = _parseHeadTailCommand(tokens);
    return parsed == null
        ? null
        : _ParsedHeadReadCommand(
            path: parsed.path,
            lineCount: parsed.lineCount,
          );
  }

  _ParsedTailReadCommand? _tryParseTailReadCommand(List<String> tokens) {
    final parsed = _parseHeadTailCommand(tokens);
    return parsed == null
        ? null
        : _ParsedTailReadCommand(
            path: parsed.path,
            lineCount: parsed.lineCount,
          );
  }

  _ParsedHeadTailCommand? _parseHeadTailCommand(List<String> tokens) {
    if (tokens.length < 2) {
      return null;
    }

    var index = 1;
    var lineCount = 10;
    while (index < tokens.length) {
      final token = tokens[index];
      if (token == '--') {
        index++;
        break;
      }
      if (!token.startsWith('-') || token == '-') {
        break;
      }

      if (token == '-n' || token == '--lines') {
        if (index + 1 >= tokens.length) {
          return null;
        }
        final parsedCount = _parsePositiveInt(tokens[index + 1]);
        if (parsedCount == null) {
          return null;
        }
        lineCount = parsedCount;
        index += 2;
        continue;
      }

      if (token.startsWith('-n') && token.length > 2) {
        final parsedCount = _parsePositiveInt(token.substring(2));
        if (parsedCount == null) {
          return null;
        }
        lineCount = parsedCount;
        index++;
        continue;
      }

      if (token.startsWith('--lines=')) {
        final parsedCount = _parsePositiveInt(
          token.substring('--lines='.length),
        );
        if (parsedCount == null) {
          return null;
        }
        lineCount = parsedCount;
        index++;
        continue;
      }

      final shortCountMatch = _shortHeadTailCountPattern.firstMatch(token);
      if (shortCountMatch != null) {
        final parsedCount = _parsePositiveInt(shortCountMatch.group(1)!);
        if (parsedCount == null) {
          return null;
        }
        lineCount = parsedCount;
        index++;
        continue;
      }

      return null;
    }

    if (index != tokens.length - 1) {
      return null;
    }

    final path = tokens[index].trim();
    if (!_isFileTarget(path)) {
      return null;
    }

    return _ParsedHeadTailCommand(path: path, lineCount: lineCount);
  }

  _ParsedGetContentReadCommand? _tryParseGetContentReadCommand(
    List<String> tokens,
  ) {
    if (tokens.length < 2) {
      return null;
    }

    String? path;
    ChatGetContentReadMode mode = ChatGetContentReadMode.fullFile;
    int? lineCount;

    var index = 1;
    while (index < tokens.length) {
      final token = tokens[index];
      final normalizedToken = token.toLowerCase();

      if (_isPowerShellNamedParameter(normalizedToken, 'path')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'path',
        );
        if (result == null || path != null) {
          return null;
        }
        path = result.value;
        index = result.nextIndex;
        continue;
      }

      if (_isPowerShellNamedParameter(normalizedToken, 'literalpath')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'literalpath',
        );
        if (result == null || path != null) {
          return null;
        }
        path = result.value;
        index = result.nextIndex;
        continue;
      }

      if (_isPowerShellNamedParameter(normalizedToken, 'totalcount')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'totalcount',
        );
        if (result == null) {
          return null;
        }
        final parsedCount = _parsePositiveInt(result.value);
        if (parsedCount == null) {
          return null;
        }
        mode = ChatGetContentReadMode.firstLines;
        lineCount = parsedCount;
        index = result.nextIndex;
        continue;
      }

      if (_isPowerShellNamedParameter(normalizedToken, 'tail')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'tail',
        );
        if (result == null) {
          return null;
        }
        final parsedCount = _parsePositiveInt(result.value);
        if (parsedCount == null) {
          return null;
        }
        mode = ChatGetContentReadMode.lastLines;
        lineCount = parsedCount;
        index = result.nextIndex;
        continue;
      }

      if (normalizedToken == '-raw') {
        index++;
        continue;
      }

      if (token.startsWith('-')) {
        return null;
      }

      if (path != null) {
        return null;
      }
      path = token;
      index++;
    }

    if (!_isFileTarget(path)) {
      return null;
    }

    return _ParsedGetContentReadCommand(
      path: path!,
      mode: mode,
      lineCount: lineCount,
    );
  }

  _ParsedRipgrepSearchCommand? _tryParseRipgrepSearchCommand(
    List<String> tokens,
  ) {
    final parsed = _parseFlaggedPatternSearchCommand(
      tokens: tokens,
      booleanFlags: const <String>{
        '-n',
        '--line-number',
        '-S',
        '--smart-case',
        '-i',
        '--ignore-case',
        '-F',
        '--fixed-strings',
        '-w',
        '--word-regexp',
        '-l',
        '--files-with-matches',
        '-L',
        '--files-without-match',
        '-c',
        '--count',
        '--hidden',
        '--no-ignore',
        '-u',
        '-uu',
        '-uuu',
      },
      valueFlags: const <String>{
        '-g',
        '--glob',
        '-t',
        '--type',
        '-T',
        '--type-not',
        '-m',
        '--max-count',
        '-A',
        '--after-context',
        '-B',
        '--before-context',
        '-C',
        '--context',
      },
      booleanShortFlags: const <String>{
        'n',
        'S',
        'i',
        'F',
        'w',
        'l',
        'L',
        'c',
        'u',
      },
      valueShortFlags: const <String>{'g', 't', 'T', 'm', 'A', 'B', 'C'},
    );
    return parsed == null
        ? null
        : _ParsedRipgrepSearchCommand(
            query: parsed.query,
            scopeTargets: parsed.scopeTargets,
          );
  }

  _ParsedGrepSearchCommand? _tryParseGrepSearchCommand(List<String> tokens) {
    final parsed = _parseFlaggedPatternSearchCommand(
      tokens: tokens,
      booleanFlags: const <String>{
        '-n',
        '--line-number',
        '-r',
        '-R',
        '--recursive',
        '-i',
        '--ignore-case',
        '-F',
        '--fixed-strings',
        '-w',
        '--word-regexp',
        '-l',
        '--files-with-matches',
        '-L',
        '--files-without-match',
        '-c',
        '--count',
        '-h',
        '--no-filename',
        '-H',
        '--with-filename',
        '-s',
      },
      valueFlags: const <String>{
        '-m',
        '--max-count',
        '-A',
        '--after-context',
        '-B',
        '--before-context',
        '-C',
        '--context',
        '--include',
        '--exclude',
        '--exclude-dir',
      },
      booleanShortFlags: const <String>{
        'n',
        'r',
        'R',
        'i',
        'F',
        'w',
        'l',
        'L',
        'c',
        'h',
        'H',
        's',
      },
      valueShortFlags: const <String>{'m', 'A', 'B', 'C'},
    );
    return parsed == null
        ? null
        : _ParsedGrepSearchCommand(
            query: parsed.query,
            scopeTargets: parsed.scopeTargets,
          );
  }

  _ParsedSelectStringSearchCommand? _tryParseSelectStringSearchCommand(
    List<String> tokens,
  ) {
    if (tokens.length < 2) {
      return null;
    }

    String? query;
    final scopeTargets = <String>[];

    var index = 1;
    while (index < tokens.length) {
      final token = tokens[index];
      final normalizedToken = token.toLowerCase();

      if (_isPowerShellNamedParameter(normalizedToken, 'pattern')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'pattern',
        );
        if (result == null || query != null) {
          return null;
        }
        query = result.value;
        index = result.nextIndex;
        continue;
      }

      if (_isPowerShellNamedParameter(normalizedToken, 'path')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'path',
        );
        if (result == null) {
          return null;
        }
        final scopes = _splitScopeTargets(result.value);
        if (scopes == null) {
          return null;
        }
        scopeTargets.addAll(scopes);
        index = result.nextIndex;
        continue;
      }

      if (_isPowerShellNamedParameter(normalizedToken, 'literalpath')) {
        final result = _resolvePowerShellParameterValue(
          tokens: tokens,
          index: index,
          parameterName: 'literalpath',
        );
        if (result == null) {
          return null;
        }
        final scopes = _splitScopeTargets(result.value);
        if (scopes == null) {
          return null;
        }
        scopeTargets.addAll(scopes);
        index = result.nextIndex;
        continue;
      }

      if (const <String>{
        '-casesensitive',
        '-simplematch',
        '-list',
        '-allmatches',
        '-quiet',
        '-notmatch',
        '-raw',
      }.contains(normalizedToken)) {
        index++;
        continue;
      }

      if (token.startsWith('-')) {
        return null;
      }

      if (query == null) {
        query = token;
      } else if (!_isSearchScopeTarget(token)) {
        return null;
      } else {
        scopeTargets.add(token);
      }
      index++;
    }

    if (!_isSearchQuery(query)) {
      return null;
    }

    return _ParsedSelectStringSearchCommand(
      query: query!,
      scopeTargets: scopeTargets,
    );
  }

  _ParsedFindStrSearchCommand? _tryParseFindStrSearchCommand(
    List<String> tokens,
  ) {
    if (tokens.length < 2) {
      return null;
    }

    String? query;
    final scopeTargets = <String>[];

    var index = 1;
    while (index < tokens.length) {
      final token = tokens[index];
      final normalizedToken = token.toLowerCase();

      if (normalizedToken == '/c') {
        if (query != null || index + 1 >= tokens.length) {
          return null;
        }
        query = tokens[index + 1];
        index += 2;
        continue;
      }
      if (normalizedToken.startsWith('/c:')) {
        if (query != null || token.length <= 3) {
          return null;
        }
        query = token.substring(3);
        index++;
        continue;
      }

      if (normalizedToken == '/g' ||
          normalizedToken.startsWith('/g:') ||
          normalizedToken == '/f' ||
          normalizedToken.startsWith('/f:')) {
        return null;
      }

      if (token.startsWith('/')) {
        index++;
        continue;
      }

      if (query == null) {
        query = token;
      } else if (!_isSearchScopeTarget(token)) {
        return null;
      } else {
        scopeTargets.add(token);
      }
      index++;
    }

    if (!_isSearchQuery(query)) {
      return null;
    }

    return _ParsedFindStrSearchCommand(
      query: query!,
      scopeTargets: scopeTargets,
    );
  }

  _ParsedPatternSearchCommand? _parseFlaggedPatternSearchCommand({
    required List<String> tokens,
    required Set<String> booleanFlags,
    required Set<String> valueFlags,
    required Set<String> booleanShortFlags,
    required Set<String> valueShortFlags,
  }) {
    if (tokens.length < 2) {
      return null;
    }

    String? query;
    var index = 1;
    while (index < tokens.length && query == null) {
      final token = tokens[index];
      final normalizedToken = token.toLowerCase();
      if (token == '--') {
        index++;
        break;
      }

      if (normalizedToken == '-e' || normalizedToken == '--regexp') {
        if (index + 1 >= tokens.length) {
          return null;
        }
        query = tokens[index + 1];
        index += 2;
        break;
      }
      if (normalizedToken.startsWith('--regexp=')) {
        final value = token.substring('--regexp='.length);
        if (!_isSearchQuery(value)) {
          return null;
        }
        query = value;
        index++;
        break;
      }
      if (normalizedToken.startsWith('-e') && token.length > 2) {
        query = token.substring(2);
        index++;
        break;
      }

      if (booleanFlags.contains(normalizedToken) ||
          _isCombinedShortBooleanFlags(
            token,
            allowedFlags: booleanShortFlags,
          )) {
        index++;
        continue;
      }

      if (valueFlags.contains(normalizedToken)) {
        if (index + 1 >= tokens.length) {
          return null;
        }
        index += 2;
        continue;
      }
      if (_isLongFlagWithInlineValue(token, allowedFlags: valueFlags) ||
          _isCompactShortValueFlag(token, allowedFlags: valueShortFlags)) {
        index++;
        continue;
      }

      if (token.startsWith('-')) {
        return null;
      }

      query = token;
      index++;
    }

    if (!_isSearchQuery(query)) {
      return null;
    }

    if (index < tokens.length && tokens[index] == '--') {
      index++;
    }

    final scopeTargets = <String>[];
    while (index < tokens.length) {
      final token = tokens[index];
      if (!_isSearchScopeTarget(token)) {
        return null;
      }
      scopeTargets.add(token);
      index++;
    }

    return _ParsedPatternSearchCommand(
      query: query!,
      scopeTargets: scopeTargets,
    );
  }

  _ParsedGitInvocation? _parseGitInvocation(List<String> tokens) {
    if (tokens.isEmpty) {
      return null;
    }

    var index = 1;
    String? repoPath;
    String? gitDir;
    String? workTree;

    while (index < tokens.length) {
      final token = tokens[index];
      final normalizedToken = token.toLowerCase();

      if (!token.startsWith('-') || token == '-') {
        break;
      }

      if (token == '-C') {
        if (index + 1 >= tokens.length) {
          return null;
        }
        repoPath = tokens[index + 1];
        index += 2;
        continue;
      }
      if (token.startsWith('-C') && token.length > 2) {
        repoPath = token.substring(2);
        index++;
        continue;
      }

      if (token == '-c') {
        if (index + 1 >= tokens.length) {
          return null;
        }
        index += 2;
        continue;
      }
      if (token.startsWith('-c') && token.length > 2) {
        index++;
        continue;
      }

      if (normalizedToken == '--git-dir') {
        if (index + 1 >= tokens.length) {
          return null;
        }
        gitDir = tokens[index + 1];
        index += 2;
        continue;
      }
      if (normalizedToken.startsWith('--git-dir=')) {
        gitDir = token.substring('--git-dir='.length);
        index++;
        continue;
      }

      if (normalizedToken == '--work-tree') {
        if (index + 1 >= tokens.length) {
          return null;
        }
        workTree = tokens[index + 1];
        index += 2;
        continue;
      }
      if (normalizedToken.startsWith('--work-tree=')) {
        workTree = token.substring('--work-tree='.length);
        index++;
        continue;
      }

      if (normalizedToken == '--namespace' ||
          normalizedToken == '--super-prefix' ||
          normalizedToken == '--config-env' ||
          normalizedToken == '--exec-path') {
        if (index + 1 >= tokens.length) {
          return null;
        }
        index += 2;
        continue;
      }
      if (normalizedToken.startsWith('--namespace=') ||
          normalizedToken.startsWith('--super-prefix=') ||
          normalizedToken.startsWith('--config-env=') ||
          normalizedToken.startsWith('--exec-path=')) {
        index++;
        continue;
      }

      index++;
    }

    final subcommand = index < tokens.length ? tokens[index] : null;
    final args = index < tokens.length
        ? tokens.sublist(index + 1)
        : const <String>[];

    return _ParsedGitInvocation(
      subcommand: subcommand,
      args: args,
      repoPath: repoPath,
      gitDir: gitDir,
      workTree: workTree,
    );
  }

  _ParsedGitCommand _buildParsedGitCommand(_ParsedGitInvocation invocation) {
    final subcommand = invocation.subcommand;
    final normalizedSubcommand = subcommand?.toLowerCase();
    final repoScopeLabel = _gitScopeLabel(invocation);

    if (normalizedSubcommand == null || normalizedSubcommand.isEmpty) {
      return _ParsedGitCommand(
        subcommandLabel: 'git',
        summaryLabel: 'Running git',
        primaryLabel: repoScopeLabel ?? 'Repository command',
      );
    }

    return switch (normalizedSubcommand) {
      'status' => _buildGitStatusCommand(invocation, repoScopeLabel),
      'diff' => _buildGitDiffCommand(invocation, repoScopeLabel),
      'show' => _buildGitShowCommand(invocation, repoScopeLabel),
      'log' => _buildGitLogCommand(invocation, repoScopeLabel),
      'grep' => _buildGitGrepCommand(invocation, repoScopeLabel),
      'add' => _buildGitAddCommand(invocation, repoScopeLabel),
      'restore' => _buildGitRestoreCommand(invocation, repoScopeLabel),
      'checkout' => _buildGitCheckoutCommand(invocation, repoScopeLabel),
      'switch' => _buildGitSwitchCommand(invocation, repoScopeLabel),
      'rev-parse' => _buildGitRevParseCommand(invocation, repoScopeLabel),
      'branch' => _buildGitBranchCommand(invocation, repoScopeLabel),
      'commit' => _buildGitCommitCommand(invocation, repoScopeLabel),
      'stash' => _buildGitStashCommand(invocation, repoScopeLabel),
      'fetch' => _buildGitRemoteCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Fetching remote updates',
      ),
      'pull' => _buildGitRemoteCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Pulling remote changes',
      ),
      'push' => _buildGitRemoteCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Pushing commits',
      ),
      'merge' => _buildGitTargetedCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Merging history',
        emptyPrimaryLabel: 'Requested merge target',
      ),
      'rebase' => _buildGitTargetedCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Rebasing commits',
        emptyPrimaryLabel: 'Current branch',
      ),
      'cherry-pick' => _buildGitTargetedCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Applying commit',
        emptyPrimaryLabel: 'Selected commit',
      ),
      'revert' => _buildGitTargetedCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Reverting commit',
        emptyPrimaryLabel: 'Selected commit',
      ),
      'blame' => _buildGitTargetedCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Tracing line history',
        emptyPrimaryLabel: 'Requested file',
      ),
      'rm' => _buildGitTargetedCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Removing tracked files',
        emptyPrimaryLabel: 'Selected paths',
      ),
      'mv' => _buildGitTargetedCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Moving tracked files',
        emptyPrimaryLabel: 'Selected paths',
      ),
      'clean' => _buildGitTargetedCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Cleaning untracked files',
        emptyPrimaryLabel: 'Current repository',
      ),
      'reset' => _buildGitTargetedCommand(
        invocation: invocation,
        repoScopeLabel: repoScopeLabel,
        summaryLabel: 'Resetting repository state',
        emptyPrimaryLabel: 'Current branch',
      ),
      _ => _buildGenericGitCommand(invocation, repoScopeLabel),
    };
  }

  _ParsedGitCommand _buildGitStatusCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final targets = _collectGitPositionalArgs(
      invocation.args,
      valueOptions: const <String>{
        '--untracked-files',
        '--ignored',
        '--column',
        '--ahead-behind',
      },
      shortValueOptions: const <String>{'u'},
    );
    return _ParsedGitCommand(
      subcommandLabel: 'status',
      summaryLabel: 'Checking worktree status',
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: 'Current repository',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitDiffCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final isStaged =
        invocation.args.contains('--staged') ||
        invocation.args.contains('--cached');
    final targets = _collectGitPositionalArgs(
      invocation.args,
      valueOptions: const <String>{
        '--diff-filter',
        '--submodule',
        '--output',
        '--word-diff-regex',
      },
      shortValueOptions: const <String>{'U'},
    );
    final primaryLabel = isStaged
        ? 'Staged changes'
        : _formatCompactItemList(targets, emptyLabel: 'Working tree changes');
    final secondaryLabel = _combineDetailLabels(<String?>[
      isStaged && targets.isNotEmpty
          ? _formatCompactItemList(targets, emptyLabel: '')
          : null,
      repoScopeLabel,
    ]);
    return _ParsedGitCommand(
      subcommandLabel: 'diff',
      summaryLabel: 'Inspecting diff',
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
    );
  }

  _ParsedGitCommand _buildGitShowCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final targets = _collectGitPositionalArgs(
      invocation.args,
      valueOptions: const <String>{'--format', '--pretty'},
      shortValueOptions: const <String>{'n'},
    );
    return _ParsedGitCommand(
      subcommandLabel: 'show',
      summaryLabel: 'Inspecting git object',
      primaryLabel: _formatCompactItemList(targets, emptyLabel: 'HEAD'),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitLogCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final targets = _collectGitPositionalArgs(
      invocation.args,
      valueOptions: const <String>{'--max-count', '--author', '--grep'},
      shortValueOptions: const <String>{'n'},
    );
    return _ParsedGitCommand(
      subcommandLabel: 'log',
      summaryLabel: 'Reviewing commit history',
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: 'Current branch',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitGrepCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final search = _parseGitGrepArgs(invocation.args);
    if (search != null) {
      return _ParsedGitCommand(
        subcommandLabel: 'grep',
        summaryLabel: 'Searching tracked files',
        primaryLabel: search.query,
        secondaryLabel: _combineDetailLabels(<String?>[
          search.scopeTargets.isEmpty
              ? 'In tracked files'
              : 'In ${_formatCompactItemList(search.scopeTargets, emptyLabel: '')}',
          repoScopeLabel,
        ]),
      );
    }
    return _buildGenericGitCommand(invocation, repoScopeLabel);
  }

  _ParsedGitCommand _buildGitAddCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final targets = _collectGitPositionalArgs(
      invocation.args,
      valueOptions: const <String>{'--chmod'},
    );
    final primaryLabel =
        invocation.args.contains('-A') ||
            invocation.args.contains('--all') ||
            invocation.args.contains('-u') ||
            invocation.args.contains('--update')
        ? 'All tracked changes'
        : _formatCompactItemList(targets, emptyLabel: 'Selected paths');
    return _ParsedGitCommand(
      subcommandLabel: 'add',
      summaryLabel: 'Staging changes',
      primaryLabel: primaryLabel,
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitRestoreCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final targets = _collectGitPositionalArgs(invocation.args);
    return _ParsedGitCommand(
      subcommandLabel: 'restore',
      summaryLabel: invocation.args.contains('--staged')
          ? 'Restoring staged changes'
          : 'Restoring tracked files',
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: 'Selected paths',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitCheckoutCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final separatorIndex = invocation.args.indexOf('--');
    if (separatorIndex >= 0) {
      final pathTargets = invocation.args
          .skip(separatorIndex + 1)
          .where(_isNonEmptyToken)
          .toList(growable: false);
      return _ParsedGitCommand(
        subcommandLabel: 'checkout',
        summaryLabel: 'Restoring paths',
        primaryLabel: _formatCompactItemList(
          pathTargets,
          emptyLabel: 'Selected paths',
        ),
        secondaryLabel: repoScopeLabel,
      );
    }

    final targets = _collectGitPositionalArgs(
      invocation.args,
      valueOptions: const <String>{'--detach'},
      shortValueOptions: const <String>{'b', 'B'},
    );
    return _ParsedGitCommand(
      subcommandLabel: 'checkout',
      summaryLabel: 'Switching checkout target',
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: 'Requested target',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitSwitchCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final targets = _collectGitPositionalArgs(
      invocation.args,
      shortValueOptions: const <String>{'c', 'C'},
    );
    return _ParsedGitCommand(
      subcommandLabel: 'switch',
      summaryLabel: 'Switching branch',
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: 'Requested branch',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitRevParseCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final targets = _collectGitPositionalArgs(invocation.args);
    return _ParsedGitCommand(
      subcommandLabel: 'rev-parse',
      summaryLabel: 'Resolving git reference',
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: 'Repository state',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitBranchCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final targets = _collectGitPositionalArgs(
      invocation.args,
      shortValueOptions: const <String>{'m', 'M', 'c', 'C'},
    );
    return _ParsedGitCommand(
      subcommandLabel: 'branch',
      summaryLabel: targets.isEmpty
          ? 'Inspecting branches'
          : 'Managing branches',
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: 'Current repository',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitCommitCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final message = _extractGitOptionValue(
      invocation.args,
      options: const <String>{'--message'},
      shortOptions: const <String>{'m'},
    );
    return _ParsedGitCommand(
      subcommandLabel: 'commit',
      summaryLabel: 'Creating commit',
      primaryLabel: message ?? 'Staged changes',
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitStashCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final targets = _collectGitPositionalArgs(invocation.args);
    return _ParsedGitCommand(
      subcommandLabel: 'stash',
      summaryLabel: 'Managing stash',
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: 'Current stash state',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitRemoteCommand({
    required _ParsedGitInvocation invocation,
    required String? repoScopeLabel,
    required String summaryLabel,
  }) {
    final targets = _collectGitPositionalArgs(invocation.args);
    return _ParsedGitCommand(
      subcommandLabel: invocation.subcommand ?? 'git',
      summaryLabel: summaryLabel,
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: 'Default remote',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGitTargetedCommand({
    required _ParsedGitInvocation invocation,
    required String? repoScopeLabel,
    required String summaryLabel,
    required String emptyPrimaryLabel,
  }) {
    final targets = _collectGitPositionalArgs(invocation.args);
    return _ParsedGitCommand(
      subcommandLabel: invocation.subcommand ?? 'git',
      summaryLabel: summaryLabel,
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: emptyPrimaryLabel,
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitCommand _buildGenericGitCommand(
    _ParsedGitInvocation invocation,
    String? repoScopeLabel,
  ) {
    final targets = _collectGitPositionalArgs(invocation.args);
    return _ParsedGitCommand(
      subcommandLabel: invocation.subcommand ?? 'git',
      summaryLabel: 'Running git ${invocation.subcommand ?? ''}'.trim(),
      primaryLabel: _formatCompactItemList(
        targets,
        emptyLabel: 'Current repository',
      ),
      secondaryLabel: repoScopeLabel,
    );
  }

  _ParsedGitGrepSearch? _parseGitGrepArgs(List<String> args) {
    if (args.isEmpty) {
      return null;
    }

    final syntheticTokens = <String>['grep', ...args];
    final parsed = _tryParseGrepSearchCommand(syntheticTokens);
    if (parsed == null) {
      return null;
    }
    return _ParsedGitGrepSearch(
      query: parsed.query,
      scopeTargets: parsed.scopeTargets,
    );
  }
}

String _normalizeCompactToolLabel(String value) {
  return value
      .replaceFirst(
        RegExp(r'\s+(?:complete|completed)\s*$', caseSensitive: false),
        '',
      )
      .trim();
}

String? _normalizedWorkLogPreview(String? preview, String normalizedTitle) {
  final value = preview?.trim();
  if (value == null || value.isEmpty || value == normalizedTitle) {
    return null;
  }
  return value;
}

bool _isBackgroundTerminalWait(
  Map<String, dynamic>? snapshot, {
  required bool isRunning,
}) {
  if (!isRunning || snapshot == null) {
    return false;
  }

  final stdin = snapshot['stdin'];
  if (stdin is! String || stdin.isNotEmpty) {
    return false;
  }

  return _firstNonEmptyString(<Object?>[
        snapshot['processId'],
        snapshot['process_id'],
      ]) !=
      null;
}

bool _hasBackgroundTerminalMetadata(Map<String, dynamic>? snapshot) {
  if (snapshot == null) {
    return false;
  }

  return _firstNonEmptyString(<Object?>[
        snapshot['processId'],
        snapshot['process_id'],
      ]) !=
      null;
}

bool _looksLikeCommandExecution(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  if (trimmed.contains('&&') ||
      trimmed.contains('||') ||
      trimmed.contains('|') ||
      trimmed.contains(';')) {
    return false;
  }

  final tokens = _tokenizeShellCommand(trimmed);
  if (tokens == null || tokens.isEmpty) {
    return false;
  }

  final commandName = _commandName(tokens.first);
  if (commandName.isEmpty) {
    return false;
  }
  if (_structuredCommandNames.contains(commandName)) {
    return false;
  }

  if (tokens.length == 1) {
    return true;
  }

  return tokens
      .skip(1)
      .any(
        (token) =>
            token.startsWith('-') ||
            token.contains('/') ||
            token.contains('\\') ||
            token.contains('.') ||
            token.contains('=') ||
            token.contains(':'),
      );
}

const Set<String> _structuredCommandNames = <String>{
  'cat',
  'findstr',
  'get-content',
  'git',
  'grep',
  'head',
  'more',
  'rg',
  'sed',
  'select-string',
  'tail',
  'type',
};

Map<String, dynamic>? _asObjectValue(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

String? _firstNonEmptyString(List<Object?> candidates) {
  for (final candidate in candidates) {
    final value = _stringValue(candidate);
    if (value != null) {
      return value;
    }
  }
  return null;
}

String? _stringValue(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _intValue(Object? value) {
  return value is num ? value.toInt() : null;
}

List<String>? _webSearchQueries(Map<String, dynamic>? snapshot) {
  final rawQueries = snapshot?['queries'];
  if (rawQueries is! List) {
    return null;
  }

  final queries = rawQueries
      .map(_stringValue)
      .whereType<String>()
      .toList(growable: false);
  return queries.isEmpty ? null : queries;
}

String? _webSearchResultSummary(Object? value) {
  final object = _asObjectValue(value);
  if (object == null) {
    return null;
  }
  return _firstNonEmptyString(<Object?>[
    object['summary'],
    object['text'],
    object['result'],
    object['message'],
  ]);
}

ChatMcpToolCallStatus _mcpToolCallStatus(
  Map<String, dynamic> snapshot, {
  required bool isRunning,
}) {
  final normalizedStatus = _normalizeIdentifier(
    _stringValue(snapshot['status']),
  );
  return switch (normalizedStatus) {
    'failed' => ChatMcpToolCallStatus.failed,
    'completed' => ChatMcpToolCallStatus.completed,
    'inprogress' || 'in_progress' || 'running' => ChatMcpToolCallStatus.running,
    _ =>
      isRunning
          ? ChatMcpToolCallStatus.running
          : ChatMcpToolCallStatus.completed,
  };
}

String? _normalizedMcpPreview(String? preview, {required String toolName}) {
  final value = _compactSummaryText(preview);
  if (value == null) {
    return null;
  }

  final normalizedValue = _normalizeIdentifier(value);
  if (normalizedValue == _normalizeIdentifier(toolName) ||
      normalizedValue == _normalizeIdentifier('MCP tool call')) {
    return null;
  }
  return value;
}

String? _mcpResultSummary(Object? rawResult) {
  final result = _asObjectValue(rawResult);
  if (result == null) {
    return null;
  }

  final contentText = _contentBlockText(result['content']);
  if (contentText != null) {
    return contentText;
  }

  final structuredSummary = _summarizeMcpValue(
    result['structuredContent'] ?? result['structured_content'],
  );
  if (structuredSummary != null) {
    return structuredSummary;
  }

  final contentItems = result['content'];
  if (contentItems is List && contentItems.isNotEmpty) {
    return contentItems.length == 1
        ? 'Returned 1 content block'
        : 'Returned ${contentItems.length} content blocks';
  }

  return null;
}

String? _contentBlockText(Object? rawContent) {
  if (rawContent is! List) {
    return null;
  }

  for (final entry in rawContent) {
    final object = _asObjectValue(entry);
    final text = _compactSummaryText(
      _firstNonEmptyString(<Object?>[
        object?['text'],
        _asObjectValue(object?['content'])?['text'],
      ]),
    );
    if (text != null) {
      return text;
    }
  }

  return null;
}

String? _summarizeMcpValue(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is String) {
    return _compactSummaryText(value);
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  if (value is List) {
    if (value.isEmpty) {
      return null;
    }
    final scalarItems = value
        .map<String?>((item) => _summarizeMcpScalar(item))
        .whereType<String>()
        .toList(growable: false);
    if (scalarItems.isNotEmpty) {
      return _formatCompactItemList(scalarItems, emptyLabel: '');
    }
    return value.length == 1 ? '1 item' : '${value.length} items';
  }
  if (value is Map) {
    final object = Map<String, dynamic>.from(value);
    if (object.isEmpty) {
      return null;
    }
    final scalarEntries = <String>[];
    var omittedCount = 0;
    for (final entry in object.entries) {
      final summarizedValue = _summarizeMcpScalar(entry.value);
      if (summarizedValue == null) {
        continue;
      }
      if (scalarEntries.length == 2) {
        omittedCount++;
        continue;
      }
      scalarEntries.add(
        '${_humanizeFieldName(entry.key)}: $summarizedValue'.trim(),
      );
    }
    if (scalarEntries.isNotEmpty) {
      if (omittedCount > 0) {
        return '${scalarEntries.join(', ')}, +$omittedCount more';
      }
      return scalarEntries.join(', ');
    }
    return object.length == 1 ? '1 parameter' : '${object.length} parameters';
  }
  return null;
}

String? _summarizeMcpScalar(Object? value) {
  return switch (value) {
    final String stringValue => _compactSummaryText(stringValue),
    final num numberValue => numberValue.toString(),
    final bool boolValue => boolValue.toString(),
    _ => null,
  };
}

String? _compactSummaryText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  final firstLine = trimmed.split(RegExp(r'\r?\n')).first.trim();
  if (firstLine.isEmpty) {
    return null;
  }
  return firstLine.replaceAll(RegExp(r'\s+'), ' ');
}

String _humanizeFieldName(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim()
      .toLowerCase();
}

String _normalizeIdentifier(String? value) {
  if (value == null || value.isEmpty) {
    return '';
  }
  return value.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '').toLowerCase();
}

bool _containsShellOperators(String commandText) {
  var inSingleQuote = false;
  var inDoubleQuote = false;
  var escaping = false;

  for (var index = 0; index < commandText.length; index++) {
    final char = commandText[index];

    if (escaping) {
      escaping = false;
      continue;
    }
    if (inSingleQuote) {
      if (char == "'") {
        inSingleQuote = false;
      }
      continue;
    }
    if (inDoubleQuote) {
      if (char == '\\') {
        escaping = true;
        continue;
      }
      if (char == '"') {
        inDoubleQuote = false;
      }
      continue;
    }

    if (char == "'") {
      inSingleQuote = true;
      continue;
    }
    if (char == '"') {
      inDoubleQuote = true;
      continue;
    }
    if (char == '\\') {
      final next = index + 1 < commandText.length
          ? commandText[index + 1]
          : null;
      if (next != null &&
          (RegExp(r'\s').hasMatch(next) ||
              next == '"' ||
              next == "'" ||
              next == '\\' ||
              next == ';' ||
              next == '&' ||
              next == '|' ||
              next == '>' ||
              next == '<' ||
              next == '`')) {
        escaping = true;
        continue;
      }
    }
    if (char == '\n' ||
        char == ';' ||
        char == '&' ||
        char == '|' ||
        char == '>' ||
        char == '<' ||
        char == '`') {
      return true;
    }
  }

  return false;
}

List<String>? _tokenizeShellCommand(String commandText) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  String? quote;
  var escaping = false;

  void flushBuffer() {
    if (buffer.isEmpty) {
      return;
    }
    tokens.add(buffer.toString());
    buffer.clear();
  }

  for (var index = 0; index < commandText.length; index++) {
    final char = commandText[index];
    if (escaping) {
      buffer.write(char);
      escaping = false;
      continue;
    }

    if (quote == "'") {
      if (char == "'") {
        quote = null;
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (quote == '"') {
      if (char == '"') {
        quote = null;
      } else if (char == '\\') {
        final next = index + 1 < commandText.length
            ? commandText[index + 1]
            : null;
        if (next != null &&
            (RegExp(r'\s').hasMatch(next) ||
                next == '"' ||
                next == "'" ||
                next == '\\')) {
          escaping = true;
          continue;
        }
        buffer.write(char);
      } else {
        buffer.write(char);
      }
      continue;
    }

    if (char == "'") {
      quote = "'";
      continue;
    }
    if (char == '"') {
      quote = '"';
      continue;
    }
    if (char == '\\') {
      final next = index + 1 < commandText.length
          ? commandText[index + 1]
          : null;
      if (next != null &&
          (RegExp(r'\s').hasMatch(next) ||
              next == '"' ||
              next == "'" ||
              next == '\\')) {
        escaping = true;
        continue;
      }
      buffer.write(char);
      continue;
    }
    if (RegExp(r'\s').hasMatch(char)) {
      flushBuffer();
      continue;
    }

    buffer.write(char);
  }

  if (escaping || quote != null) {
    return null;
  }

  flushBuffer();
  return tokens.isEmpty ? null : tokens;
}

String _fileNameForPath(String path) {
  final normalizedPath = path.replaceAll('\\', '/');
  final segments = normalizedPath
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  return segments.isEmpty ? path : segments.last;
}

String _commandName(String executableToken) {
  final normalizedToken = executableToken.replaceAll('\\', '/');
  final segments = normalizedToken
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  final fileName = segments.isEmpty ? executableToken : segments.last;
  return fileName.toLowerCase().replaceFirst(RegExp(r'\.exe$'), '');
}

String? _unwrapPowerShellWrappedCommand(List<String> tokens) {
  for (var index = 1; index < tokens.length; index++) {
    final token = tokens[index].toLowerCase();
    if (token == '-command' || token == '-c') {
      final commandTokens = tokens.sublist(index + 1);
      if (commandTokens.isEmpty) {
        return null;
      }
      return commandTokens.join(' ').trim();
    }
  }
  return null;
}

bool _isFileTarget(String? path) {
  final value = path?.trim();
  return value != null && value.isNotEmpty && value != '-';
}

bool _isSearchQuery(String? value) {
  final query = value?.trim();
  return query != null && query.isNotEmpty;
}

bool _isSearchScopeTarget(String token) {
  final value = token.trim();
  return value.isNotEmpty &&
      value != '-' &&
      value != '--' &&
      !value.startsWith('-');
}

int? _parsePositiveInt(String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}

bool _isCombinedShortBooleanFlags(
  String token, {
  required Set<String> allowedFlags,
}) {
  if (!token.startsWith('-') || token.startsWith('--') || token.length <= 2) {
    return false;
  }

  for (final rune in token.substring(1).runes) {
    if (!allowedFlags.contains(String.fromCharCode(rune))) {
      return false;
    }
  }
  return true;
}

bool _isCompactShortValueFlag(
  String token, {
  required Set<String> allowedFlags,
}) {
  if (!token.startsWith('-') || token.startsWith('--') || token.length <= 2) {
    return false;
  }
  return allowedFlags.contains(token[1]);
}

bool _isLongFlagWithInlineValue(
  String token, {
  required Set<String> allowedFlags,
}) {
  if (!token.startsWith('--')) {
    return false;
  }
  for (final flag in allowedFlags.where((flag) => flag.startsWith('--'))) {
    if (token.startsWith('$flag=')) {
      return true;
    }
  }
  return false;
}

List<String>? _splitScopeTargets(String value) {
  final scopes = value
      .split(',')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
  if (scopes.isEmpty || scopes.any((scope) => !_isSearchScopeTarget(scope))) {
    return null;
  }
  return scopes;
}

String? _gitScopeLabel(_ParsedGitInvocation invocation) {
  if (_isNonEmptyToken(invocation.repoPath)) {
    return 'In ${invocation.repoPath}';
  }
  if (_isNonEmptyToken(invocation.workTree)) {
    return 'Work tree ${invocation.workTree}';
  }
  if (_isNonEmptyToken(invocation.gitDir)) {
    return 'Git dir ${invocation.gitDir}';
  }
  return null;
}

String _formatCompactItemList(
  List<String> items, {
  required String emptyLabel,
}) {
  if (items.isEmpty) {
    return emptyLabel;
  }
  if (items.length == 1) {
    return items.single;
  }
  if (items.length == 2) {
    return '${items[0]}, ${items[1]}';
  }
  return '${items[0]}, ${items[1]}, +${items.length - 2} more';
}

String? _combineDetailLabels(Iterable<String?> values) {
  final parts = values
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) {
    return null;
  }
  return parts.join(' · ');
}

List<String> _collectGitPositionalArgs(
  List<String> args, {
  Set<String> valueOptions = const <String>{},
  Set<String> shortValueOptions = const <String>{},
}) {
  final positionals = <String>[];
  var index = 0;
  var afterSeparator = false;

  while (index < args.length) {
    final token = args[index];
    final normalizedToken = token.toLowerCase();

    if (afterSeparator) {
      if (_isNonEmptyToken(token)) {
        positionals.add(token);
      }
      index++;
      continue;
    }

    if (token == '--') {
      afterSeparator = true;
      index++;
      continue;
    }

    if (!token.startsWith('-') || token == '-') {
      positionals.add(token);
      index++;
      continue;
    }

    if (valueOptions.contains(normalizedToken)) {
      if (index + 1 >= args.length) {
        return positionals;
      }
      index += 2;
      continue;
    }

    if (_matchesInlineLongOption(token, options: valueOptions)) {
      index++;
      continue;
    }

    if (_matchesCompactShortOption(token, options: shortValueOptions)) {
      index++;
      continue;
    }

    if (shortValueOptions.contains(token.substring(1))) {
      if (index + 1 >= args.length) {
        return positionals;
      }
      index += 2;
      continue;
    }

    index++;
  }

  return positionals;
}

String? _extractGitOptionValue(
  List<String> args, {
  Set<String> options = const <String>{},
  Set<String> shortOptions = const <String>{},
}) {
  for (var index = 0; index < args.length; index++) {
    final token = args[index];
    final normalizedToken = token.toLowerCase();
    if (options.contains(normalizedToken)) {
      if (index + 1 >= args.length) {
        return null;
      }
      return args[index + 1];
    }
    for (final option in options) {
      if (token.startsWith('$option=')) {
        return token.substring(option.length + 1);
      }
    }
    if (token.startsWith('-') &&
        !token.startsWith('--') &&
        token.length >= 2 &&
        shortOptions.contains(token[1])) {
      if (token.length > 2) {
        return token.substring(2);
      }
      if (index + 1 >= args.length) {
        return null;
      }
      return args[index + 1];
    }
  }
  return null;
}

bool _matchesInlineLongOption(String token, {required Set<String> options}) {
  if (!token.startsWith('--')) {
    return false;
  }
  for (final option in options.where((option) => option.startsWith('--'))) {
    if (token.startsWith('$option=')) {
      return true;
    }
  }
  return false;
}

bool _matchesCompactShortOption(String token, {required Set<String> options}) {
  if (!token.startsWith('-') || token.startsWith('--') || token.length <= 2) {
    return false;
  }
  return options.contains(token[1]);
}

bool _isNonEmptyToken(String? value) {
  return value != null && value.trim().isNotEmpty;
}

bool _isPowerShellNamedParameter(String token, String parameterName) {
  return token == '-$parameterName' || token.startsWith('-$parameterName:');
}

_ResolvedPowerShellParameter? _resolvePowerShellParameterValue({
  required List<String> tokens,
  required int index,
  required String parameterName,
}) {
  final token = tokens[index];
  final prefix = '-$parameterName:';
  if (token.toLowerCase().startsWith(prefix)) {
    final value = token.substring(prefix.length);
    if (value.isEmpty) {
      return null;
    }
    return _ResolvedPowerShellParameter(value: value, nextIndex: index + 1);
  }
  if (index + 1 >= tokens.length) {
    return null;
  }
  return _ResolvedPowerShellParameter(
    value: tokens[index + 1],
    nextIndex: index + 2,
  );
}

sealed class _ParsedReadCommand {
  const _ParsedReadCommand({required this.path});

  final String path;
}

sealed class _ParsedContentSearchCommand {
  const _ParsedContentSearchCommand({
    required this.query,
    required this.scopeTargets,
  });

  final String query;
  final List<String> scopeTargets;
}

class _ParsedSedReadCommand extends _ParsedReadCommand {
  const _ParsedSedReadCommand({
    required this.lineStart,
    required this.lineEnd,
    required super.path,
  });

  final int lineStart;
  final int lineEnd;
}

class _ParsedCatReadCommand extends _ParsedReadCommand {
  const _ParsedCatReadCommand({required super.path});
}

class _ParsedHeadReadCommand extends _ParsedReadCommand {
  const _ParsedHeadReadCommand({required super.path, required this.lineCount});

  final int lineCount;
}

class _ParsedTailReadCommand extends _ParsedReadCommand {
  const _ParsedTailReadCommand({required super.path, required this.lineCount});

  final int lineCount;
}

class _ParsedHeadTailCommand {
  const _ParsedHeadTailCommand({required this.path, required this.lineCount});

  final String path;
  final int lineCount;
}

class _ParsedGetContentReadCommand extends _ParsedReadCommand {
  const _ParsedGetContentReadCommand({
    required super.path,
    required this.mode,
    required this.lineCount,
  });

  final ChatGetContentReadMode mode;
  final int? lineCount;
}

class _ParsedPatternSearchCommand {
  const _ParsedPatternSearchCommand({
    required this.query,
    required this.scopeTargets,
  });

  final String query;
  final List<String> scopeTargets;
}

class _ParsedGitCommand {
  const _ParsedGitCommand({
    required this.subcommandLabel,
    required this.summaryLabel,
    required this.primaryLabel,
    this.secondaryLabel,
  });

  final String subcommandLabel;
  final String summaryLabel;
  final String primaryLabel;
  final String? secondaryLabel;
}

class _ParsedGitInvocation {
  const _ParsedGitInvocation({
    required this.subcommand,
    required this.args,
    this.repoPath,
    this.gitDir,
    this.workTree,
  });

  final String? subcommand;
  final List<String> args;
  final String? repoPath;
  final String? gitDir;
  final String? workTree;
}

class _ParsedGitGrepSearch {
  const _ParsedGitGrepSearch({required this.query, required this.scopeTargets});

  final String query;
  final List<String> scopeTargets;
}

class _ParsedRipgrepSearchCommand extends _ParsedContentSearchCommand {
  const _ParsedRipgrepSearchCommand({
    required super.query,
    required super.scopeTargets,
  });
}

class _ParsedGrepSearchCommand extends _ParsedContentSearchCommand {
  const _ParsedGrepSearchCommand({
    required super.query,
    required super.scopeTargets,
  });
}

class _ParsedSelectStringSearchCommand extends _ParsedContentSearchCommand {
  const _ParsedSelectStringSearchCommand({
    required super.query,
    required super.scopeTargets,
  });
}

class _ParsedFindStrSearchCommand extends _ParsedContentSearchCommand {
  const _ParsedFindStrSearchCommand({
    required super.query,
    required super.scopeTargets,
  });
}

class _ResolvedPowerShellParameter {
  const _ResolvedPowerShellParameter({
    required this.value,
    required this.nextIndex,
  });

  final String value;
  final int nextIndex;
}
