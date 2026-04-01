part of 'transcript_ui_block.dart';

final class TranscriptTextBlock extends TranscriptUiBlock {
  const TranscriptTextBlock({
    required super.id,
    required super.kind,
    required super.createdAt,
    required this.title,
    required this.body,
    this.turnId,
    this.isRunning = false,
  });

  final String title;
  final String body;
  final String? turnId;
  final bool isRunning;

  TranscriptTextBlock copyWith({
    String? title,
    String? body,
    String? turnId,
    bool? isRunning,
  }) {
    return TranscriptTextBlock(
      id: id,
      kind: kind,
      createdAt: createdAt,
      title: title ?? this.title,
      body: body ?? this.body,
      turnId: turnId ?? this.turnId,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

final class TranscriptPlanUpdateBlock extends TranscriptUiBlock {
  const TranscriptPlanUpdateBlock({
    required super.id,
    required super.createdAt,
    this.explanation,
    this.steps = const <TranscriptRuntimePlanStep>[],
  }) : super(kind: TranscriptUiBlockKind.plan);

  final String? explanation;
  final List<TranscriptRuntimePlanStep> steps;

  TranscriptPlanUpdateBlock copyWith({
    String? explanation,
    List<TranscriptRuntimePlanStep>? steps,
  }) {
    return TranscriptPlanUpdateBlock(
      id: id,
      createdAt: createdAt,
      explanation: explanation ?? this.explanation,
      steps: steps ?? this.steps,
    );
  }
}

final class TranscriptProposedPlanBlock extends TranscriptUiBlock {
  const TranscriptProposedPlanBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.markdown,
    this.turnId,
    this.isStreaming = false,
  }) : super(kind: TranscriptUiBlockKind.proposedPlan);

  final String title;
  final String markdown;
  final String? turnId;
  final bool isStreaming;

  TranscriptProposedPlanBlock copyWith({
    String? title,
    String? markdown,
    String? turnId,
    bool? isStreaming,
  }) {
    return TranscriptProposedPlanBlock(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      turnId: turnId ?? this.turnId,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
