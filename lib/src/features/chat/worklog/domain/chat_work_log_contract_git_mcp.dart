part of 'chat_work_log_contract.dart';

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
