import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';

class TranscriptItemBlockFactory {
  const TranscriptItemBlockFactory();

  static final RegExp _shellCommandWrapperPattern = RegExp(
    r'^(?:\S*\/)?(?:bash|zsh|sh)\s+-(?:lc|c)\s+',
    caseSensitive: false,
  );

  TranscriptUiBlockKind blockKindForItemType(
    TranscriptCanonicalItemType itemType,
  ) {
    return switch (itemType) {
      TranscriptCanonicalItemType.userMessage =>
        TranscriptUiBlockKind.userMessage,
      TranscriptCanonicalItemType.commandExecution ||
      TranscriptCanonicalItemType.webSearch ||
      TranscriptCanonicalItemType.imageView ||
      TranscriptCanonicalItemType.imageGeneration ||
      TranscriptCanonicalItemType.mcpToolCall ||
      TranscriptCanonicalItemType.dynamicToolCall ||
      TranscriptCanonicalItemType.collabAgentToolCall =>
        TranscriptUiBlockKind.workLogEntry,
      TranscriptCanonicalItemType.reasoning => TranscriptUiBlockKind.reasoning,
      TranscriptCanonicalItemType.plan => TranscriptUiBlockKind.proposedPlan,
      TranscriptCanonicalItemType.fileChange =>
        TranscriptUiBlockKind.changedFiles,
      TranscriptCanonicalItemType.reviewEntered ||
      TranscriptCanonicalItemType.reviewExited ||
      TranscriptCanonicalItemType.contextCompaction ||
      TranscriptCanonicalItemType.unknown => TranscriptUiBlockKind.status,
      TranscriptCanonicalItemType.error => TranscriptUiBlockKind.error,
      _ => TranscriptUiBlockKind.assistantMessage,
    };
  }

  TranscriptStatusBlockKind statusKindForItemType(
    TranscriptCanonicalItemType itemType,
  ) {
    return switch (itemType) {
      TranscriptCanonicalItemType.reviewEntered ||
      TranscriptCanonicalItemType.reviewExited =>
        TranscriptStatusBlockKind.review,
      TranscriptCanonicalItemType.contextCompaction =>
        TranscriptStatusBlockKind.compaction,
      _ => TranscriptStatusBlockKind.info,
    };
  }

  String defaultItemTitle(TranscriptCanonicalItemType itemType) {
    return transcriptItemTitle(itemType);
  }

  String normalizeCommandExecutionTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    final match = _shellCommandWrapperPattern.firstMatch(trimmed);
    if (match == null) {
      final powerShellCommand = _unwrapPowerShellWrappedCommand(trimmed);
      return powerShellCommand == null || powerShellCommand.isEmpty
          ? trimmed
          : powerShellCommand;
    }

    final normalized = _unwrapShellWrappedCommand(
      trimmed.substring(match.end).trim(),
    ).trim();
    return normalized.isEmpty ? trimmed : normalized;
  }

  TranscriptWorkLogEntryKind workLogEntryKindFor(
    TranscriptCanonicalItemType itemType,
  ) {
    return switch (itemType) {
      TranscriptCanonicalItemType.commandExecution =>
        TranscriptWorkLogEntryKind.commandExecution,
      TranscriptCanonicalItemType.webSearch =>
        TranscriptWorkLogEntryKind.webSearch,
      TranscriptCanonicalItemType.imageView =>
        TranscriptWorkLogEntryKind.imageView,
      TranscriptCanonicalItemType.imageGeneration =>
        TranscriptWorkLogEntryKind.imageGeneration,
      TranscriptCanonicalItemType.mcpToolCall =>
        TranscriptWorkLogEntryKind.mcpToolCall,
      TranscriptCanonicalItemType.dynamicToolCall =>
        TranscriptWorkLogEntryKind.dynamicToolCall,
      TranscriptCanonicalItemType.collabAgentToolCall =>
        TranscriptWorkLogEntryKind.collabAgentToolCall,
      _ => TranscriptWorkLogEntryKind.unknown,
    };
  }

  String? workLogPreview(TranscriptSessionActiveItem item) {
    final body = item.body.trim();
    if (body.isEmpty) {
      return null;
    }

    if (item.itemType == TranscriptCanonicalItemType.commandExecution) {
      final lines = body
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      return lines.isEmpty ? null : lines.last;
    }

    return body.split(RegExp(r'\r?\n')).first.trim();
  }

  String _unwrapShellWrappedCommand(String value) {
    if (value.length < 2) {
      return value;
    }

    final quote = value[0];
    if ((quote != "'" && quote != '"') || value[value.length - 1] != quote) {
      return value;
    }

    final inner = value.substring(1, value.length - 1);
    if (quote == "'") {
      return inner.replaceAll("'\"'\"'", "'").replaceAll(r"'\''", "'");
    }

    return inner.replaceAll(r'\"', '"');
  }

  String? _unwrapPowerShellWrappedCommand(String value) {
    final tokens = _tokenizeCommand(value);
    if (tokens == null || tokens.length < 3) {
      return null;
    }

    final commandName = _commandName(tokens.first);
    if (commandName != 'pwsh' && commandName != 'powershell') {
      return null;
    }

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

  List<String>? _tokenizeCommand(String commandText) {
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

  String _commandName(String executableToken) {
    final normalizedToken = executableToken.replaceAll('\\', '/');
    final segments = normalizedToken
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final fileName = segments.isEmpty ? executableToken : segments.last;
    return fileName.toLowerCase().replaceFirst(RegExp(r'\.exe$'), '');
  }
}
