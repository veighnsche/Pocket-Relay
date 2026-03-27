import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

class ChatWorkLogTerminalContract {
  const ChatWorkLogTerminalContract({
    required this.id,
    required this.activityLabel,
    required this.commandText,
    required this.isRunning,
    required this.isWaiting,
    this.isFailed = false,
    this.itemId,
    this.threadId,
    this.turnId,
    this.exitCode,
    this.processId,
    this.terminalInput,
    this.terminalOutput,
  });

  factory ChatWorkLogTerminalContract.fromEntry(
    ChatShellWorkLogEntryContract entry,
  ) {
    return ChatWorkLogTerminalContract(
      id: entry.id,
      activityLabel: switch (entry) {
        ChatCommandExecutionWorkLogEntryContract commandEntry =>
          commandEntry.activityLabel,
        ChatCommandWaitWorkLogEntryContract waitEntry =>
          waitEntry.activityLabel,
        ChatFileReadWorkLogEntryContract readEntry => readEntry.summaryLabel,
        ChatContentSearchWorkLogEntryContract searchEntry =>
          searchEntry.summaryLabel,
        ChatGitWorkLogEntryContract gitEntry => gitEntry.summaryLabel,
      },
      commandText: entry.commandText,
      isRunning: entry.isRunning,
      isWaiting: entry is ChatCommandWaitWorkLogEntryContract,
      isFailed: entry.exitCode != null && entry.exitCode != 0,
      itemId: entry.itemId,
      threadId: entry.threadId,
      turnId: entry.turnId,
      exitCode: entry.exitCode,
      processId: entry.processId,
      terminalInput: entry.terminalInput,
      terminalOutput: entry.terminalOutput,
    );
  }

  final String id;
  final String activityLabel;
  final String commandText;
  final bool isRunning;
  final bool isWaiting;
  final bool isFailed;
  final String? itemId;
  final String? threadId;
  final String? turnId;
  final int? exitCode;
  final String? processId;
  final String? terminalInput;
  final String? terminalOutput;

  ChatWorkLogTerminalContract copyWith({
    String? activityLabel,
    String? commandText,
    bool? isRunning,
    bool? isWaiting,
    bool? isFailed,
    String? itemId,
    String? threadId,
    String? turnId,
    int? exitCode,
    String? processId,
    String? terminalInput,
    String? terminalOutput,
  }) {
    return ChatWorkLogTerminalContract(
      id: id,
      activityLabel: activityLabel ?? this.activityLabel,
      commandText: commandText ?? this.commandText,
      isRunning: isRunning ?? this.isRunning,
      isWaiting: isWaiting ?? this.isWaiting,
      isFailed: isFailed ?? this.isFailed,
      itemId: itemId ?? this.itemId,
      threadId: threadId ?? this.threadId,
      turnId: turnId ?? this.turnId,
      exitCode: exitCode ?? this.exitCode,
      processId: processId ?? this.processId,
      terminalInput: terminalInput ?? this.terminalInput,
      terminalOutput: terminalOutput ?? this.terminalOutput,
    );
  }

  bool get hasTerminalInput => terminalInput != null;
  bool get hasTerminalOutput => terminalOutput != null;

  String get statusBadgeLabel {
    if (isWaiting) {
      return 'waiting';
    }
    if (isRunning) {
      return 'running';
    }
    final code = exitCode;
    if (code != null && code != 0) {
      return 'exit $code';
    }
    if (isFailed) {
      return 'failed';
    }
    return 'completed';
  }
}
