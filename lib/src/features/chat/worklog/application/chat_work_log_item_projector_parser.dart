part of 'chat_work_log_item_projector.dart';

_ParsedReadCommand? _tryParseReadCommand(String commandText) {
  if (commandText.isEmpty || _containsShellOperators(commandText)) {
    return null;
  }

  return _tryParseReadCommandTokens(
    _tokenizeShellCommand(commandText),
    originalCommandText: commandText,
  );
}

_ParsedContentSearchCommand? _tryParseContentSearchCommand(String commandText) {
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
      : _ParsedHeadReadCommand(path: parsed.path, lineCount: parsed.lineCount);
}

_ParsedTailReadCommand? _tryParseTailReadCommand(List<String> tokens) {
  final parsed = _parseHeadTailCommand(tokens);
  return parsed == null
      ? null
      : _ParsedTailReadCommand(path: parsed.path, lineCount: parsed.lineCount);
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
      final parsedCount = _parsePositiveInt(token.substring('--lines='.length));
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

  return _ParsedFindStrSearchCommand(query: query!, scopeTargets: scopeTargets);
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
        _isCombinedShortBooleanFlags(token, allowedFlags: booleanShortFlags)) {
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

  return _ParsedPatternSearchCommand(query: query!, scopeTargets: scopeTargets);
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
    primaryLabel: _formatCompactItemList(targets, emptyLabel: 'Current branch'),
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
    primaryLabel: _formatCompactItemList(targets, emptyLabel: 'Selected paths'),
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
    summaryLabel: targets.isEmpty ? 'Inspecting branches' : 'Managing branches',
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
    primaryLabel: _formatCompactItemList(targets, emptyLabel: 'Default remote'),
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
