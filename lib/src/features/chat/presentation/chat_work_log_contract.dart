import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

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
  return segments.length > 1 ? List<String>.unmodifiable(segments) : <String>[trimmedQuery];
}
