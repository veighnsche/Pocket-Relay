import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';

class TranscriptMemoryBudget {
  const TranscriptMemoryBudget();

  static const int maxSnapshotStringChars = 2048;
  static const int maxSnapshotListItems = 12;
  static const int maxSnapshotMapEntries = 16;
  static const int maxSnapshotDepth = 4;
  static const int maxUnifiedDiffChars = 120000;
  static const int maxUnifiedDiffLines = 1200;

  Map<String, dynamic>? retainWorkLogSnapshot(
    CodexCanonicalItemType itemType,
    Map<String, dynamic>? snapshot,
  ) {
    if (snapshot == null || snapshot.isEmpty) {
      return null;
    }

    final scopedSnapshot = switch (itemType) {
      CodexCanonicalItemType.commandExecution => _pickKeys(snapshot, const {
        'command',
        'processId',
        'process_id',
        'stdin',
        'exitCode',
        'exit_code',
      }),
      CodexCanonicalItemType.mcpToolCall => _pickKeys(snapshot, const {
        'server',
        'serverName',
        'tool',
        'toolName',
        'status',
        'durationMs',
        'duration_ms',
        'errorMessage',
        'arguments',
        'result',
        'error',
      }),
      CodexCanonicalItemType.webSearch => _pickKeys(snapshot, const {
        'query',
        'title',
        'queries',
        'result',
        'results',
      }),
      _ => snapshot,
    };

    final sanitized = _sanitizeMap(scopedSnapshot, depth: 0);
    return sanitized.isEmpty ? null : sanitized;
  }

  String? retainUnifiedDiff(String? unifiedDiff) {
    final trimmed = unifiedDiff?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length <= maxUnifiedDiffChars) {
      final lineCount = '\n'.allMatches(trimmed).length + 1;
      if (lineCount <= maxUnifiedDiffLines) {
        return trimmed;
      }
    }

    final lines = trimmed.split(RegExp(r'\r?\n'));
    final buffer = StringBuffer();
    var lineCount = 0;
    var charCount = 0;

    for (final line in lines) {
      final additionalChars = (buffer.isEmpty ? 0 : 1) + line.length;
      if (lineCount >= maxUnifiedDiffLines ||
          charCount + additionalChars > maxUnifiedDiffChars) {
        break;
      }
      if (buffer.isNotEmpty) {
        buffer.writeln();
        charCount += 1;
      }
      buffer.write(line);
      charCount += line.length;
      lineCount += 1;
    }

    final retained = buffer.toString().trim();
    return retained.isEmpty ? null : retained;
  }

  Map<String, dynamic> _pickKeys(
    Map<String, dynamic> value,
    Set<String> allowedKeys,
  ) {
    final result = <String, dynamic>{};
    for (final entry in value.entries) {
      if (allowedKeys.contains(entry.key)) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }

  Map<String, dynamic> _sanitizeMap(
    Map<String, dynamic> value, {
    required int depth,
  }) {
    if (value.isEmpty || depth >= maxSnapshotDepth) {
      return const <String, dynamic>{};
    }

    final result = <String, dynamic>{};
    var retainedEntries = 0;
    for (final entry in value.entries) {
      if (retainedEntries >= maxSnapshotMapEntries) {
        break;
      }
      final sanitized = _sanitizeValue(entry.value, depth: depth + 1);
      if (sanitized == null) {
        continue;
      }
      result[entry.key] = sanitized;
      retainedEntries += 1;
    }
    return result;
  }

  Object? _sanitizeValue(Object? value, {required int depth}) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      if (value.length <= maxSnapshotStringChars) {
        return value;
      }
      return '${value.substring(0, maxSnapshotStringChars)} [truncated]';
    }
    if (value is num || value is bool) {
      return value;
    }
    if (value is Map) {
      return _sanitizeMap(Map<String, dynamic>.from(value), depth: depth);
    }
    if (value is List) {
      if (depth >= maxSnapshotDepth) {
        return const <Object>[];
      }
      return value
          .take(maxSnapshotListItems)
          .map((entry) => _sanitizeValue(entry, depth: depth + 1))
          .whereType<Object>()
          .toList(growable: false);
    }
    return value.toString();
  }
}
