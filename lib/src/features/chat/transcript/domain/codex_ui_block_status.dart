part of 'transcript_ui_block.dart';

final class TranscriptStatusBlock extends TranscriptUiBlock {
  const TranscriptStatusBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.body,
    this.statusKind = TranscriptStatusBlockKind.info,
    this.isTranscriptSignal = false,
  }) : super(kind: TranscriptUiBlockKind.status);

  final String title;
  final String body;
  final TranscriptStatusBlockKind statusKind;
  final bool isTranscriptSignal;
}

enum TranscriptStatusBlockKind { info, warning, review, compaction, auth }

final class TranscriptErrorBlock extends TranscriptUiBlock {
  const TranscriptErrorBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.body,
  }) : super(kind: TranscriptUiBlockKind.error);

  final String title;
  final String body;
}

final class TranscriptUsageBlock extends TranscriptUiBlock {
  const TranscriptUsageBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.body,
  }) : super(kind: TranscriptUiBlockKind.usage);

  final String title;
  final String body;
}

final class TranscriptTurnBoundaryBlock extends TranscriptUiBlock {
  const TranscriptTurnBoundaryBlock({
    required super.id,
    required super.createdAt,
    this.label = 'end',
    this.elapsed,
    this.usage,
  }) : super(kind: TranscriptUiBlockKind.turnBoundary);

  final String label;
  final Duration? elapsed;
  final TranscriptUsageBlock? usage;
}
