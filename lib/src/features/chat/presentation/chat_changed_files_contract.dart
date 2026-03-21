enum ChatChangedFileDiffLineKind { meta, hunk, addition, deletion, context }

enum ChatChangedFileOperationKind { created, modified, deleted }

class ChatChangedFileStatsContract {
  const ChatChangedFileStatsContract({
    required this.additions,
    required this.deletions,
  });

  final int additions;
  final int deletions;

  bool get hasChanges => additions > 0 || deletions > 0;
}

class ChatChangedFileDiffLineContract {
  const ChatChangedFileDiffLineContract({
    required this.text,
    required this.kind,
  });

  final String text;
  final ChatChangedFileDiffLineKind kind;
}

class ChatChangedFileDiffContract {
  const ChatChangedFileDiffContract({
    required this.id,
    required this.displayPathLabel,
    required this.stats,
    required this.lines,
    this.statusLabel,
    this.previewLineLimit = 320,
  });

  final String id;
  final String displayPathLabel;
  final ChatChangedFileStatsContract stats;
  final List<ChatChangedFileDiffLineContract> lines;
  final String? statusLabel;
  final int previewLineLimit;

  int get lineCount => lines.length;
  bool get hasPreviewLimit => lines.length > previewLineLimit;
}

class ChatChangedFileRowContract {
  const ChatChangedFileRowContract({
    required this.id,
    required this.displayPathLabel,
    required this.operationKind,
    required this.operationLabel,
    required this.stats,
    required this.actionLabel,
    this.diff,
  });

  final String id;
  final String displayPathLabel;
  final ChatChangedFileOperationKind operationKind;
  final String operationLabel;
  final ChatChangedFileStatsContract stats;
  final String actionLabel;
  final ChatChangedFileDiffContract? diff;

  bool get canOpenDiff => diff != null;
}
