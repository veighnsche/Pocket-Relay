import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

class ChatWorkLogTerminalContract {
  const ChatWorkLogTerminalContract({
    required this.id,
    required this.activityLabel,
    required this.commandText,
    required this.isRunning,
    required this.isWaiting,
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
  final int? exitCode;
  final String? processId;
  final String? terminalInput;
  final String? terminalOutput;

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
    return 'completed';
  }
}
