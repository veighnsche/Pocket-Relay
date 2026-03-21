part of 'codex_ui_block.dart';

final class CodexTextBlock extends CodexUiBlock {
  const CodexTextBlock({
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

  CodexTextBlock copyWith({
    String? title,
    String? body,
    String? turnId,
    bool? isRunning,
  }) {
    return CodexTextBlock(
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

final class CodexPlanUpdateBlock extends CodexUiBlock {
  const CodexPlanUpdateBlock({
    required super.id,
    required super.createdAt,
    this.explanation,
    this.steps = const <CodexRuntimePlanStep>[],
  }) : super(kind: CodexUiBlockKind.plan);

  final String? explanation;
  final List<CodexRuntimePlanStep> steps;

  CodexPlanUpdateBlock copyWith({
    String? explanation,
    List<CodexRuntimePlanStep>? steps,
  }) {
    return CodexPlanUpdateBlock(
      id: id,
      createdAt: createdAt,
      explanation: explanation ?? this.explanation,
      steps: steps ?? this.steps,
    );
  }
}

final class CodexProposedPlanBlock extends CodexUiBlock {
  const CodexProposedPlanBlock({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.markdown,
    this.turnId,
    this.isStreaming = false,
  }) : super(kind: CodexUiBlockKind.proposedPlan);

  final String title;
  final String markdown;
  final String? turnId;
  final bool isStreaming;

  CodexProposedPlanBlock copyWith({
    String? title,
    String? markdown,
    String? turnId,
    bool? isStreaming,
  }) {
    return CodexProposedPlanBlock(
      id: id,
      createdAt: createdAt,
      title: title ?? this.title,
      markdown: markdown ?? this.markdown,
      turnId: turnId ?? this.turnId,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}
