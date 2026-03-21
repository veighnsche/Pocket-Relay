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
