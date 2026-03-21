part of 'chat_work_log_item_projector.dart';

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
