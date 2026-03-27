part of 'chat_work_log_contract.dart';

sealed class ChatFileReadWorkLogEntryContract
    extends ChatShellWorkLogEntryContract {
  const ChatFileReadWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required this.fileName,
    required this.filePath,
    super.itemId,
    super.threadId,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

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
    super.itemId,
    super.threadId,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
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
    super.itemId,
    super.threadId,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  @override
  String get commandLabel => 'cat';

  @override
  String get summaryLabel => 'Reading full file';
}

final class ChatTypeReadWorkLogEntryContract
    extends ChatFileReadWorkLogEntryContract {
  const ChatTypeReadWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.fileName,
    required super.filePath,
    super.itemId,
    super.threadId,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  @override
  String get commandLabel => 'type';

  @override
  String get summaryLabel => 'Reading full file';
}

final class ChatMoreReadWorkLogEntryContract
    extends ChatFileReadWorkLogEntryContract {
  const ChatMoreReadWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.fileName,
    required super.filePath,
    super.itemId,
    super.threadId,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  @override
  String get commandLabel => 'more';

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
    super.itemId,
    super.threadId,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
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
    super.itemId,
    super.threadId,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
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

final class ChatAwkReadWorkLogEntryContract
    extends ChatFileReadWorkLogEntryContract {
  const ChatAwkReadWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.fileName,
    required super.filePath,
    required this.lineStart,
    required this.lineEnd,
    super.itemId,
    super.threadId,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  final int lineStart;
  final int lineEnd;

  bool get isSingleLine => lineStart == lineEnd;

  @override
  String get commandLabel => 'awk';

  @override
  String get summaryLabel => isSingleLine
      ? 'Reading line $lineStart'
      : 'Reading lines $lineStart to $lineEnd';
}

enum ChatGetContentReadMode { fullFile, firstLines, lastLines, lineRange }

final class ChatGetContentReadWorkLogEntryContract
    extends ChatFileReadWorkLogEntryContract {
  const ChatGetContentReadWorkLogEntryContract({
    required super.id,
    required super.commandText,
    required super.fileName,
    required super.filePath,
    required this.mode,
    this.lineCount,
    this.lineStart,
    this.lineEnd,
    super.itemId,
    super.threadId,
    super.processId,
    super.terminalInput,
    super.terminalOutput,
    super.turnId,
    super.isRunning = false,
    super.exitCode,
  });

  final ChatGetContentReadMode mode;
  final int? lineCount;
  final int? lineStart;
  final int? lineEnd;

  @override
  String get commandLabel => 'Get-Content';

  @override
  String get summaryLabel => switch (mode) {
    ChatGetContentReadMode.fullFile => 'Reading full file',
    ChatGetContentReadMode.firstLines =>
      lineCount == 1 ? 'Reading first line' : 'Reading first $lineCount lines',
    ChatGetContentReadMode.lastLines =>
      lineCount == 1 ? 'Reading last line' : 'Reading last $lineCount lines',
    ChatGetContentReadMode.lineRange =>
      lineStart == lineEnd
          ? 'Reading line $lineStart'
          : 'Reading lines $lineStart to $lineEnd',
  };
}
