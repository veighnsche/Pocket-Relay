part of 'chat_work_log_item_projector.dart';

_ParsedSedReadCommand? _tryParseSedReadCommand(List<String> tokens) {
  final parsed = _parseSedPrintRangeCommand(tokens, requiresFileTarget: true);
  if (parsed == null || parsed.path == null) {
    return null;
  }

  return _ParsedSedReadCommand(
    lineStart: parsed.lineStart,
    lineEnd: parsed.lineEnd,
    path: parsed.path!,
  );
}

_ParsedSedReadCommand? _tryParseNumberedSedReadCommand(String commandText) {
  final pipeCommand = _splitSinglePipeCommand(commandText);
  if (pipeCommand == null) {
    return null;
  }

  final numberedInputTokens = _tokenizeShellCommand(pipeCommand.leftCommand);
  final rangedReadTokens = _tokenizeShellCommand(pipeCommand.rightCommand);
  if (numberedInputTokens == null || rangedReadTokens == null) {
    return null;
  }

  final path = _tryParseNlReadPath(numberedInputTokens);
  if (path == null) {
    return null;
  }

  final parsedSed = _parseSedPrintRangeCommand(
    rangedReadTokens,
    requiresFileTarget: false,
  );
  if (parsedSed == null) {
    return null;
  }

  return _ParsedSedReadCommand(
    lineStart: parsedSed.lineStart,
    lineEnd: parsedSed.lineEnd,
    path: path,
  );
}

_ParsedGetContentReadCommand? _tryParseSelectObjectReadCommand(
  String commandText,
) {
  final pipeCommand = _splitSinglePipeCommand(commandText);
  if (pipeCommand == null) {
    return null;
  }

  final sourceTokens = _tokenizeShellCommand(pipeCommand.leftCommand);
  final selectTokens = _tokenizeShellCommand(pipeCommand.rightCommand);
  if (sourceTokens == null || selectTokens == null) {
    return null;
  }

  final sourceRead = _tryParseGetContentReadCommand(sourceTokens);
  if (sourceRead == null ||
      sourceRead.mode != ChatGetContentReadMode.fullFile) {
    return null;
  }

  final projection = _tryParseSelectObjectReadProjection(selectTokens);
  if (projection == null) {
    return null;
  }

  return _ParsedGetContentReadCommand(
    path: sourceRead.path,
    mode: projection.mode,
    lineCount: projection.lineCount,
    lineStart: projection.lineStart,
    lineEnd: projection.lineEnd,
  );
}

_ParsedSedPrintRangeCommand? _parseSedPrintRangeCommand(
  List<String> tokens, {
  required bool requiresFileTarget,
}) {
  if (tokens.length < (requiresFileTarget ? 4 : 3) ||
      _commandName(tokens.first) != 'sed') {
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
    return null;
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

  String? path;
  if (requiresFileTarget) {
    if (index != tokens.length - 1) {
      return null;
    }
    path = tokens[index].trim();
    if (!_isFileTarget(path)) {
      return null;
    }
  } else if (index != tokens.length) {
    return null;
  }

  final lineStart = int.parse(scriptMatch.group(1)!);
  final lineEnd = int.parse(scriptMatch.group(2) ?? scriptMatch.group(1)!);
  if (lineStart <= 0 || lineEnd < lineStart) {
    return null;
  }

  return _ParsedSedPrintRangeCommand(
    lineStart: lineStart,
    lineEnd: lineEnd,
    path: path,
  );
}

String? _tryParseNlReadPath(List<String> tokens) {
  if (tokens.length < 2 || _commandName(tokens.first) != 'nl') {
    return null;
  }

  var index = 1;
  while (index < tokens.length) {
    final token = tokens[index];
    final normalizedToken = token.toLowerCase();
    if (token == '--') {
      index++;
      break;
    }
    if (!token.startsWith('-') || token == '-') {
      break;
    }
    if (normalizedToken == '-ba' || normalizedToken == '--body-numbering=a') {
      index++;
      continue;
    }
    if (normalizedToken == '-b' || normalizedToken == '--body-numbering') {
      if (index + 1 >= tokens.length ||
          tokens[index + 1].toLowerCase() != 'a') {
        return null;
      }
      index += 2;
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
  return path;
}

class _ParsedSedPrintRangeCommand {
  const _ParsedSedPrintRangeCommand({
    required this.lineStart,
    required this.lineEnd,
    this.path,
  });

  final int lineStart;
  final int lineEnd;
  final String? path;
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

_ParsedTypeReadCommand? _tryParseTypeReadCommand(List<String> tokens) {
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
  return _ParsedTypeReadCommand(path: path);
}

_ParsedMoreReadCommand? _tryParseMoreReadCommand(List<String> tokens) {
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
  return _ParsedMoreReadCommand(path: path);
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

_ParsedAwkReadCommand? _tryParseAwkReadCommand(List<String> tokens) {
  if (tokens.length != 3) {
    return null;
  }

  final script = tokens[1].trim();
  final path = tokens[2].trim();
  if (script.isEmpty || !_isFileTarget(path)) {
    return null;
  }

  final singleLineMatch = _awkSingleLineReadPattern.firstMatch(script);
  if (singleLineMatch != null) {
    final lineNumber = int.parse(singleLineMatch.group(1)!);
    if (lineNumber <= 0) {
      return null;
    }
    return _ParsedAwkReadCommand(
      path: path,
      lineStart: lineNumber,
      lineEnd: lineNumber,
    );
  }

  final rangeMatch = _awkRangeReadPattern.firstMatch(script);
  if (rangeMatch == null) {
    return null;
  }

  final lineStart = int.parse(rangeMatch.group(1)!);
  final lineEnd = int.parse(rangeMatch.group(2)!);
  if (lineStart <= 0 || lineEnd < lineStart) {
    return null;
  }

  return _ParsedAwkReadCommand(
    path: path,
    lineStart: lineStart,
    lineEnd: lineEnd,
  );
}

_ParsedSelectObjectReadProjection? _tryParseSelectObjectReadProjection(
  List<String> tokens,
) {
  if (tokens.length < 3 || _commandName(tokens.first) != 'select-object') {
    return null;
  }

  int? firstCount;
  int? lastCount;
  int? skipCount;

  var index = 1;
  while (index < tokens.length) {
    final token = tokens[index];
    final normalizedToken = token.toLowerCase();

    if (_isPowerShellNamedParameter(normalizedToken, 'first')) {
      final result = _resolvePowerShellParameterValue(
        tokens: tokens,
        index: index,
        parameterName: 'first',
      );
      if (result == null || firstCount != null || lastCount != null) {
        return null;
      }
      firstCount = _parsePositiveInt(result.value);
      if (firstCount == null) {
        return null;
      }
      index = result.nextIndex;
      continue;
    }

    if (_isPowerShellNamedParameter(normalizedToken, 'last')) {
      final result = _resolvePowerShellParameterValue(
        tokens: tokens,
        index: index,
        parameterName: 'last',
      );
      if (result == null || lastCount != null || firstCount != null) {
        return null;
      }
      lastCount = _parsePositiveInt(result.value);
      if (lastCount == null) {
        return null;
      }
      index = result.nextIndex;
      continue;
    }

    if (_isPowerShellNamedParameter(normalizedToken, 'skip')) {
      final result = _resolvePowerShellParameterValue(
        tokens: tokens,
        index: index,
        parameterName: 'skip',
      );
      if (result == null || skipCount != null) {
        return null;
      }
      skipCount = _parseNonNegativeInt(result.value);
      if (skipCount == null) {
        return null;
      }
      index = result.nextIndex;
      continue;
    }

    return null;
  }

  if (firstCount != null) {
    if (skipCount == null || skipCount == 0) {
      return _ParsedSelectObjectReadProjection(
        mode: ChatGetContentReadMode.firstLines,
        lineCount: firstCount,
      );
    }
    return _ParsedSelectObjectReadProjection(
      mode: ChatGetContentReadMode.lineRange,
      lineStart: skipCount + 1,
      lineEnd: skipCount + firstCount,
    );
  }

  if (lastCount != null && skipCount == null) {
    return _ParsedSelectObjectReadProjection(
      mode: ChatGetContentReadMode.lastLines,
      lineCount: lastCount,
    );
  }

  return null;
}

class _ParsedSelectObjectReadProjection {
  const _ParsedSelectObjectReadProjection({
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
