part of 'codex_ui_block.dart';

final class CodexStatusBlock extends CodexUiBlock {
  const CodexStatusBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.body,
    this.statusKind = CodexStatusBlockKind.info,
    this.isTranscriptSignal = false,
  }) : super(kind: CodexUiBlockKind.status);

  final String title;
  final String body;
  final CodexStatusBlockKind statusKind;
  final bool isTranscriptSignal;
}

enum CodexStatusBlockKind {
  info,
  warning,
  review,
  compaction,
  auth,
}

final class CodexErrorBlock extends CodexUiBlock {
  const CodexErrorBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.body,
  }) : super(kind: CodexUiBlockKind.error);

  final String title;
  final String body;
}

final class CodexUsageBlock extends CodexUiBlock {
  const CodexUsageBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.body,
  }) : super(kind: CodexUiBlockKind.usage);

  final String title;
  final String body;
}

final class CodexTurnBoundaryBlock extends CodexUiBlock {
  const CodexTurnBoundaryBlock({
    required super.id,
    required super.createdAt,
    this.label = 'end',
    this.elapsed,
    this.usage,
  }) : super(kind: CodexUiBlockKind.turnBoundary);

  final String label;
  final Duration? elapsed;
  final CodexUsageBlock? usage;
}
