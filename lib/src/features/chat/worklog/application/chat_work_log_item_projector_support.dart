part of 'chat_work_log_item_projector.dart';

final RegExp _sedPrintRangePattern = RegExp(r'^(\d+)(?:,(\d+))?p$');
final RegExp _shortHeadTailCountPattern = RegExp(r'^-(\d+)$');

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
