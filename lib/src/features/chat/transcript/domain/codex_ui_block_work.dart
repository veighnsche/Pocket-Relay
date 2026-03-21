part of 'codex_ui_block.dart';

final class CodexWorkLogGroupBlock extends CodexUiBlock {
  const CodexWorkLogGroupBlock({
    required super.id,
    required super.createdAt,
    required this.entries,
  }) : super(kind: CodexUiBlockKind.workLogGroup);

  final List<CodexWorkLogEntry> entries;

  CodexWorkLogGroupBlock copyWith({List<CodexWorkLogEntry>? entries}) {
    return CodexWorkLogGroupBlock(
      id: id,
      createdAt: createdAt,
      entries: entries ?? this.entries,
    );
  }
}

final class CodexChangedFilesBlock extends CodexUiBlock {
  const CodexChangedFilesBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    this.files = const <CodexChangedFile>[],
    this.unifiedDiff,
    this.turnId,
    this.isRunning = false,
  }) : super(kind: CodexUiBlockKind.changedFiles);

  final String title;
  final List<CodexChangedFile> files;
  final String? unifiedDiff;
  final String? turnId;
  final bool isRunning;

  CodexChangedFilesBlock copyWith({
    String? title,
    List<CodexChangedFile>? files,
    String? unifiedDiff,
    String? turnId,
    bool? isRunning,
  }) {
    return CodexChangedFilesBlock(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      files: files ?? this.files,
      unifiedDiff: unifiedDiff ?? this.unifiedDiff,
      turnId: turnId ?? this.turnId,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}
