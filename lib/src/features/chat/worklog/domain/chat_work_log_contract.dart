import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

sealed class ChatWorkLogEntryContract {
  const ChatWorkLogEntryContract({
    required this.id,
    required this.entryKind,
    required this.isRunning,
    required this.exitCode,
    this.turnId,
  });

  final String id;
  final CodexWorkLogEntryKind entryKind;
  final bool isRunning;
  final int? exitCode;
  final String? turnId;
}

final class ChatGenericWorkLogEntryContract extends ChatWorkLogEntryContract {
  const ChatGenericWorkLogEntryContract({
    required super.id,
    required super.entryKind,
    required this.title,
    this.preview,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  final String title;
  final String? preview;
}

final class ChatCommandExecutionWorkLogEntryContract
    extends ChatWorkLogEntryContract {
  const ChatCommandExecutionWorkLogEntryContract({
    required super.id,
    required this.commandText,
    this.outputPreview,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  }) : super(entryKind: CodexWorkLogEntryKind.commandExecution);

  final String commandText;
  final String? outputPreview;

  String get activityLabel => isRunning ? 'Running command' : 'Ran command';
}

final class ChatCommandWaitWorkLogEntryContract
    extends ChatWorkLogEntryContract {
  const ChatCommandWaitWorkLogEntryContract({
    required super.id,
    required this.commandText,
    this.outputPreview,
    this.processId,
    super.turnId,
    super.isRunning = true,
    super.exitCode,
  }) : super(entryKind: CodexWorkLogEntryKind.commandExecution);

  final String commandText;
  final String? outputPreview;
  final String? processId;

  String get activityLabel => 'Waiting for background terminal';
}

final class ChatWebSearchWorkLogEntryContract extends ChatWorkLogEntryContract {
  const ChatWebSearchWorkLogEntryContract({
    required super.id,
    required this.queryText,
    this.resultSummary,
    this.queryCount,
    super.turnId,
    super.isRunning = false,
  }) : super(entryKind: CodexWorkLogEntryKind.webSearch, exitCode: null);

  final String queryText;
  final String? resultSummary;
  final int? queryCount;

  String get activityLabel => isRunning ? 'Searching' : 'Searched';

  String get scopeLabel {
    final count = queryCount;
    if (count == null || count <= 1) {
      return 'Web search';
    }
    return '$count queries';
  }
}

sealed class ChatFileReadWorkLogEntryContract extends ChatWorkLogEntryContract {
  const ChatFileReadWorkLogEntryContract({
    required super.id,
    required this.commandText,
    required this.fileName,
    required this.filePath,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  }) : super(entryKind: CodexWorkLogEntryKind.commandExecution);

  final String commandText;
  final String fileName;
  final String filePath;

  String get commandLabel;
  String get summaryLabel;
}

final class ChatSedReadWorkLogEntryContract
    extends ChatFileReadWorkLogEntryContract {
  const ChatSedReadWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.fileName,
    required super.filePath,
    required this.lineStart,
    required this.lineEnd,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  final int lineStart;
  final int lineEnd;

  bool get isSingleLine => lineStart == lineEnd;

  @override
  String get commandLabel => 'sed';

  @override
  String get summaryLabel => isSingleLine
      ? 'Reading line $lineStart'
      : 'Reading lines $lineStart to $lineEnd';
}

final class ChatCatReadWorkLogEntryContract
    extends ChatFileReadWorkLogEntryContract {
  const ChatCatReadWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.fileName,
    required super.filePath,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  @override
  String get commandLabel => 'cat';

  @override
  String get summaryLabel => 'Reading full file';
}

final class ChatHeadReadWorkLogEntryContract
    extends ChatFileReadWorkLogEntryContract {
  const ChatHeadReadWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.fileName,
    required super.filePath,
    required this.lineCount,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  final int lineCount;

  @override
  String get commandLabel => 'head';

  @override
  String get summaryLabel =>
      lineCount == 1 ? 'Reading first line' : 'Reading first $lineCount lines';
}

final class ChatTailReadWorkLogEntryContract
    extends ChatFileReadWorkLogEntryContract {
  const ChatTailReadWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.fileName,
    required super.filePath,
    required this.lineCount,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  final int lineCount;

  @override
  String get commandLabel => 'tail';

  @override
  String get summaryLabel =>
      lineCount == 1 ? 'Reading last line' : 'Reading last $lineCount lines';
}

enum ChatGetContentReadMode { fullFile, firstLines, lastLines }

final class ChatGetContentReadWorkLogEntryContract
    extends ChatFileReadWorkLogEntryContract {
  const ChatGetContentReadWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.fileName,
    required super.filePath,
    required this.mode,
    this.lineCount,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  final ChatGetContentReadMode mode;
  final int? lineCount;

  @override
  String get commandLabel => 'Get-Content';

  @override
  String get summaryLabel => switch (mode) {
    ChatGetContentReadMode.fullFile => 'Reading full file',
    ChatGetContentReadMode.firstLines =>
      lineCount == 1 ? 'Reading first line' : 'Reading first $lineCount lines',
    ChatGetContentReadMode.lastLines =>
      lineCount == 1 ? 'Reading last line' : 'Reading last $lineCount lines',
  };
}

sealed class ChatContentSearchWorkLogEntryContract
    extends ChatWorkLogEntryContract {
  const ChatContentSearchWorkLogEntryContract({
    required super.id,
    required this.commandText,
    required this.queryText,
    required this.scopeTargets,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  }) : super(entryKind: CodexWorkLogEntryKind.commandExecution);

  final String commandText;
  final String queryText;
  final List<String> scopeTargets;

  String get commandLabel;

  String get summaryLabel => 'Searching for';

  List<String> get querySegments => _splitSimpleSearchAlternation(queryText);

  String get displayQueryText => querySegments.join(' | ');

  String get scopeLabel {
    if (scopeTargets.isEmpty) {
      return 'In current workspace';
    }
    if (scopeTargets.length == 1) {
      return 'In ${scopeTargets.single}';
    }
    if (scopeTargets.length == 2) {
      return 'In ${scopeTargets[0]}, ${scopeTargets[1]}';
    }
    return 'In ${scopeTargets[0]}, ${scopeTargets[1]}, +${scopeTargets.length - 2} more';
  }
}

final class ChatRipgrepSearchWorkLogEntryContract
    extends ChatContentSearchWorkLogEntryContract {
  const ChatRipgrepSearchWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.queryText,
    required super.scopeTargets,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  @override
  String get commandLabel => 'rg';
}

final class ChatGrepSearchWorkLogEntryContract
    extends ChatContentSearchWorkLogEntryContract {
  const ChatGrepSearchWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.queryText,
    required super.scopeTargets,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  @override
  String get commandLabel => 'grep';
}

final class ChatSelectStringSearchWorkLogEntryContract
    extends ChatContentSearchWorkLogEntryContract {
  const ChatSelectStringSearchWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.queryText,
    required super.scopeTargets,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  @override
  String get commandLabel => 'Select-String';
}

final class ChatFindStrSearchWorkLogEntryContract
    extends ChatContentSearchWorkLogEntryContract {
  const ChatFindStrSearchWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.queryText,
    required super.scopeTargets,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  @override
  String get commandLabel => 'findstr';
}

final class ChatGitWorkLogEntryContract extends ChatWorkLogEntryContract {
  const ChatGitWorkLogEntryContract({
    required super.id,
    required this.commandText,
    required this.subcommandLabel,
    required this.summaryLabel,
    required this.primaryLabel,
    this.secondaryLabel,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  }) : super(entryKind: CodexWorkLogEntryKind.commandExecution);

  final String commandText;
  final String subcommandLabel;
  final String summaryLabel;
  final String primaryLabel;
  final String? secondaryLabel;

  String get commandLabel => 'git';
}

enum ChatMcpToolCallStatus { running, completed, failed }

final class ChatMcpToolCallWorkLogEntryContract
    extends ChatWorkLogEntryContract {
  const ChatMcpToolCallWorkLogEntryContract({
    required super.id,
    required this.serverName,
    required this.toolName,
    required this.status,
    this.argumentsSummary,
    this.progressSummary,
    this.resultSummary,
    this.errorSummary,
    this.durationMs,
    this.rawArguments,
    this.rawResult,
    this.rawError,
    super.turnId,
    super.isRunning = false,
  }) : super(entryKind: CodexWorkLogEntryKind.mcpToolCall, exitCode: null);

  final String serverName;
  final String toolName;
  final ChatMcpToolCallStatus status;
  final String? argumentsSummary;
  final String? progressSummary;
  final String? resultSummary;
  final String? errorSummary;
  final int? durationMs;
  final Object? rawArguments;
  final Object? rawResult;
  final Object? rawError;

  String get identityLabel => '$serverName.$toolName';

  String get statusLabel => switch (status) {
    ChatMcpToolCallStatus.running => 'running',
    ChatMcpToolCallStatus.completed => 'completed',
    ChatMcpToolCallStatus.failed => 'failed',
  };

  String? get durationLabel {
    final value = durationMs;
    if (value == null || value < 0) {
      return null;
    }
    if (value < 1000) {
      return '$value ms';
    }
    final seconds = value / 1000;
    if (seconds < 10) {
      return '${seconds.toStringAsFixed(1)} s';
    }
    if (seconds < 60) {
      return '${seconds.round()} s';
    }
    final minutes = seconds ~/ 60;
    final remainingSeconds = (seconds % 60).round();
    return remainingSeconds == 0
        ? '$minutes min'
        : '$minutes min $remainingSeconds s';
  }

  String? get argumentsLabel {
    final summary = argumentsSummary?.trim();
    if (summary == null || summary.isEmpty) {
      return null;
    }
    return 'args: $summary';
  }

  String? get outcomeLabel {
    final summary = switch (status) {
      ChatMcpToolCallStatus.failed => errorSummary?.trim(),
      ChatMcpToolCallStatus.running => progressSummary?.trim(),
      ChatMcpToolCallStatus.completed => resultSummary?.trim(),
    };
    final parts = <String>[statusLabel];
    if (summary != null && summary.isNotEmpty) {
      parts.add(summary);
    }
    final duration = durationLabel;
    if (duration != null) {
      parts.add(duration);
    }
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

List<String> _splitSimpleSearchAlternation(String queryText) {
  final trimmedQuery = queryText.trim();
  if (!trimmedQuery.contains('|')) {
    return <String>[trimmedQuery];
  }

  final segments = <String>[];
  final buffer = StringBuffer();
  var escaping = false;
  var charClassDepth = 0;
  var groupDepth = 0;
  var isInvalid = false;

  void flushSegment() {
    final segment = buffer.toString().trim();
    if (segment.isEmpty) {
      isInvalid = true;
      buffer.clear();
      return;
    }
    segments.add(segment);
    buffer.clear();
  }

  for (var index = 0; index < trimmedQuery.length; index++) {
    final char = trimmedQuery[index];
    if (escaping) {
      buffer.write(char);
      escaping = false;
      continue;
    }

    if (char == r'\') {
      buffer.write(char);
      escaping = true;
      continue;
    }

    if (char == '[') {
      charClassDepth++;
      buffer.write(char);
      continue;
    }
    if (char == ']' && charClassDepth > 0) {
      charClassDepth--;
      buffer.write(char);
      continue;
    }

    if (charClassDepth == 0) {
      if (char == '(') {
        groupDepth++;
        buffer.write(char);
        continue;
      }
      if (char == ')' && groupDepth > 0) {
        groupDepth--;
        buffer.write(char);
        continue;
      }
      if (char == '|' && groupDepth == 0) {
        flushSegment();
        if (isInvalid) {
          return <String>[trimmedQuery];
        }
        continue;
      }
    }

    buffer.write(char);
  }

  if (isInvalid || escaping || charClassDepth != 0 || groupDepth != 0) {
    return <String>[trimmedQuery];
  }

  flushSegment();
  if (isInvalid) {
    return <String>[trimmedQuery];
  }
  return segments.length > 1
      ? List<String>.unmodifiable(segments)
      : <String>[trimmedQuery];
}
