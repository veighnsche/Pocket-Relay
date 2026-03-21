import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptItemBlockFactory {
  const TranscriptItemBlockFactory();

  static final RegExp _shellCommandWrapperPattern = RegExp(
    r'^(?:\S*\/)?(?:bash|zsh|sh)\s+-(?:lc|c)\s+',
    caseSensitive: false,
  );

  CodexUiBlockKind blockKindForItemType(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.userMessage => CodexUiBlockKind.userMessage,
      CodexCanonicalItemType.commandExecution ||
      CodexCanonicalItemType.webSearch ||
      CodexCanonicalItemType.imageView ||
      CodexCanonicalItemType.imageGeneration ||
      CodexCanonicalItemType.mcpToolCall ||
      CodexCanonicalItemType.dynamicToolCall ||
      CodexCanonicalItemType.collabAgentToolCall =>
        CodexUiBlockKind.workLogEntry,
      CodexCanonicalItemType.reasoning => CodexUiBlockKind.reasoning,
      CodexCanonicalItemType.plan => CodexUiBlockKind.proposedPlan,
      CodexCanonicalItemType.fileChange => CodexUiBlockKind.changedFiles,
      CodexCanonicalItemType.reviewEntered ||
      CodexCanonicalItemType.reviewExited ||
      CodexCanonicalItemType.contextCompaction ||
      CodexCanonicalItemType.unknown => CodexUiBlockKind.status,
      CodexCanonicalItemType.error => CodexUiBlockKind.error,
      _ => CodexUiBlockKind.assistantMessage,
    };
  }

  CodexStatusBlockKind statusKindForItemType(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.reviewEntered ||
      CodexCanonicalItemType.reviewExited => CodexStatusBlockKind.review,
      CodexCanonicalItemType.contextCompaction =>
        CodexStatusBlockKind.compaction,
      _ => CodexStatusBlockKind.info,
    };
  }

  String defaultItemTitle(CodexCanonicalItemType itemType) {
    return codexItemTitle(itemType);
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

  CodexWorkLogEntryKind workLogEntryKindFor(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.commandExecution =>
        CodexWorkLogEntryKind.commandExecution,
      CodexCanonicalItemType.webSearch => CodexWorkLogEntryKind.webSearch,
      CodexCanonicalItemType.imageView => CodexWorkLogEntryKind.imageView,
      CodexCanonicalItemType.imageGeneration =>
        CodexWorkLogEntryKind.imageGeneration,
      CodexCanonicalItemType.mcpToolCall => CodexWorkLogEntryKind.mcpToolCall,
      CodexCanonicalItemType.dynamicToolCall =>
        CodexWorkLogEntryKind.dynamicToolCall,
      CodexCanonicalItemType.collabAgentToolCall =>
        CodexWorkLogEntryKind.collabAgentToolCall,
      _ => CodexWorkLogEntryKind.unknown,
    };
  }

  String? workLogPreview(CodexSessionActiveItem item) {
    final body = item.body.trim();
    if (body.isEmpty) {
      return null;
    }

    if (item.itemType == CodexCanonicalItemType.commandExecution) {
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
