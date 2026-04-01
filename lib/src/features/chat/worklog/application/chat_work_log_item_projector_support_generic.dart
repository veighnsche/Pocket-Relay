part of 'chat_work_log_item_projector.dart';

final RegExp _sedPrintRangePattern = RegExp(r'^(\d+)(?:,(\d+))?p$');
final RegExp _shortHeadTailCountPattern = RegExp(r'^-(\d+)$');
final RegExp _awkSingleLineReadPattern = RegExp(
  r'^NR\s*==\s*(\d+)(?:\s*\{\s*print\s*\})?$',
);
final RegExp _awkRangeReadPattern = RegExp(
  r'^NR\s*>=\s*(\d+)\s*&&\s*NR\s*<=\s*(\d+)(?:\s*\{\s*print\s*\})?$',
);

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

  return _processIdFromSnapshot(snapshot) != null;
}

String? _processIdFromSnapshot(Map<String, dynamic>? snapshot) {
  if (snapshot == null) {
    return null;
  }

  return _firstNonEmptyString(<Object?>[
    snapshot['processId'],
    snapshot['process_id'],
  ]);
}

String? _nonBlankTextPreservingWhitespace(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value;
}

String? _terminalInputText(Map<String, dynamic>? snapshot) {
  return _nonBlankTextPreservingWhitespace(snapshot?['stdin']);
}

String? _terminalOutputText(
  TranscriptWorkLogEntry entry, {
  required String commandText,
  String? terminalInput,
}) {
  final body = _nonBlankTextPreservingWhitespace(entry.body);
  if (body == null) {
    return null;
  }
  if (body.trim() == commandText.trim() || body == terminalInput) {
    return null;
  }
  return body;
}

({String? processId, String? terminalInput, String? terminalOutput})
_shellTerminalFields(
  TranscriptWorkLogEntry entry, {
  required String commandText,
}) {
  final processId = _processIdFromSnapshot(entry.snapshot);
  final terminalInput = _terminalInputText(entry.snapshot);
  final terminalOutput = _terminalOutputText(
    entry,
    commandText: commandText,
    terminalInput: terminalInput,
  );
  return (
    processId: processId,
    terminalInput: terminalInput,
    terminalOutput: terminalOutput,
  );
}

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

int? _parseNonNegativeInt(String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < 0) {
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

bool _isNonEmptyToken(String? value) {
  return value != null && value.trim().isNotEmpty;
}
