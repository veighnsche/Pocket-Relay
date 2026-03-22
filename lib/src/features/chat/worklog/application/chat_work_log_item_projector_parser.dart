part of 'chat_work_log_item_projector.dart';

_ParsedReadCommand? _tryParseReadCommand(String commandText) {
  if (commandText.isEmpty) {
    return null;
  }

  final numberedSedRead = _tryParseNumberedSedReadCommand(commandText);
  if (numberedSedRead != null) {
    return numberedSedRead;
  }
  final selectObjectRead = _tryParseSelectObjectReadCommand(commandText);
  if (selectObjectRead != null) {
    return selectObjectRead;
  }

  if (_containsShellOperators(commandText)) {
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
    'type' => _tryParseTypeReadCommand(tokens),
    'more' => _tryParseMoreReadCommand(tokens),
    'head' => _tryParseHeadReadCommand(tokens),
    'tail' => _tryParseTailReadCommand(tokens),
    'awk' => _tryParseAwkReadCommand(tokens),
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

class _ParsedTypeReadCommand extends _ParsedReadCommand {
  const _ParsedTypeReadCommand({required super.path});
}

class _ParsedMoreReadCommand extends _ParsedReadCommand {
  const _ParsedMoreReadCommand({required super.path});
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
    this.lineCount,
    this.lineStart,
    this.lineEnd,
  });

  final ChatGetContentReadMode mode;
  final int? lineCount;
  final int? lineStart;
  final int? lineEnd;
}

class _ParsedAwkReadCommand extends _ParsedReadCommand {
  const _ParsedAwkReadCommand({
    required super.path,
    required this.lineStart,
    required this.lineEnd,
  });

  final int lineStart;
  final int lineEnd;
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
