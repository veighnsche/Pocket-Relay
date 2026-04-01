part of 'transcript_ui_block.dart';

final class TranscriptWorkLogGroupBlock extends TranscriptUiBlock {
  const TranscriptWorkLogGroupBlock({
    required super.id,
    required super.createdAt,
    required this.entries,
  }) : super(kind: TranscriptUiBlockKind.workLogGroup);

  final List<TranscriptWorkLogEntry> entries;

  TranscriptWorkLogGroupBlock copyWith({
    List<TranscriptWorkLogEntry>? entries,
  }) {
    return TranscriptWorkLogGroupBlock(
      id: id,
      createdAt: createdAt,
      entries: entries ?? this.entries,
    );
  }
}

final class TranscriptChangedFilesBlock extends TranscriptUiBlock {
  const TranscriptChangedFilesBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    this.files = const <TranscriptChangedFile>[],
    this.unifiedDiff,
    this.turnId,
    this.isRunning = false,
  }) : super(kind: TranscriptUiBlockKind.changedFiles);

  final String title;
  final List<TranscriptChangedFile> files;
  final String? unifiedDiff;
  final String? turnId;
  final bool isRunning;

  TranscriptChangedFilesBlock copyWith({
    String? title,
    List<TranscriptChangedFile>? files,
    String? unifiedDiff,
    String? turnId,
    bool? isRunning,
  }) {
    return TranscriptChangedFilesBlock(
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
