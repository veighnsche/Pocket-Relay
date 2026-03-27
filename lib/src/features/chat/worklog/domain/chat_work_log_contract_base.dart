part of 'chat_work_log_contract.dart';

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

sealed class ChatShellWorkLogEntryContract extends ChatWorkLogEntryContract {
  const ChatShellWorkLogEntryContract({
    required super.id,
    required this.commandText,
    this.processId,
    this.terminalInput,
    this.terminalOutput,
    super.turnId,
    required super.isRunning,
    super.exitCode,
  }) : super(entryKind: CodexWorkLogEntryKind.commandExecution);

  final String commandText;
  final String? processId;
  final String? terminalInput;
  final String? terminalOutput;
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
    extends ChatShellWorkLogEntryContract {
  const ChatCommandExecutionWorkLogEntryContract({
    required super.id,
    required super.commandText,
    this.outputPreview,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  final String? outputPreview;

  String get activityLabel => isRunning ? 'Running command' : 'Ran command';
}

final class ChatCommandWaitWorkLogEntryContract
    extends ChatShellWorkLogEntryContract {
  const ChatCommandWaitWorkLogEntryContract({
    required super.id,
    required super.commandText,
    this.outputPreview,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
    super.turnId,
    super.isRunning = true,
    super.exitCode,
  });

  final String? outputPreview;

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
