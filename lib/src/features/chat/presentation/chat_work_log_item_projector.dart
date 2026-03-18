import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_work_log_contract.dart';

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

  ChatWorkLogEntryContract _projectEntry(CodexWorkLogEntry entry) {
    final normalizedTitle = _normalizeCompactToolLabel(entry.title);
    final readCommand =
        entry.entryKind == CodexWorkLogEntryKind.commandExecution
        ? _tryParseReadCommand(normalizedTitle)
        : null;
    final searchCommand =
        readCommand == null &&
            entry.entryKind == CodexWorkLogEntryKind.commandExecution
        ? _tryParseContentSearchCommand(normalizedTitle)
        : null;

    if (readCommand != null) {
      return _projectReadCommand(
        readCommand: readCommand,
        entry: entry,
        normalizedTitle: normalizedTitle,
      );
    }
    if (searchCommand != null) {
      return _projectSearchCommand(
        searchCommand: searchCommand,
        entry: entry,
        normalizedTitle: normalizedTitle,
      );
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
      booleanShortFlags: const <String>{'n', 'S', 'i', 'F', 'w', 'l', 'L', 'c', 'u'},
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
      booleanShortFlags: const <String>{'n', 'r', 'R', 'i', 'F', 'w', 'l', 'L', 'c', 'h', 'H', 's'},
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
          _isCompactShortValueFlag(
            token,
            allowedFlags: valueShortFlags,
          )) {
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
  return value.isNotEmpty && value != '-' && value != '--' && !value.startsWith('-');
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
