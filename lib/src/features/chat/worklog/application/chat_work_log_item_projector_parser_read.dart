part of 'chat_work_log_item_projector.dart';

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
