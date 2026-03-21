part of 'codex_ui_block.dart';

final class CodexApprovalRequestBlock extends CodexUiBlock {
  const CodexApprovalRequestBlock({
    required super.id,
    required super.createdAt,
    required this.requestId,
    required this.requestType,
    required this.title,
    required this.body,
    this.isResolved = false,
    this.resolutionLabel,
  }) : super(kind: CodexUiBlockKind.approvalRequest);

  final String requestId;
  final CodexCanonicalRequestType requestType;
  final String title;
  final String body;
  final bool isResolved;
  final String? resolutionLabel;

  CodexApprovalRequestBlock copyWith({
    String? title,
    String? body,
    bool? isResolved,
    String? resolutionLabel,
  }) {
    return CodexApprovalRequestBlock(
      id: id,
      createdAt: createdAt,
      requestId: requestId,
      requestType: requestType,
      title: title ?? this.title,
      body: body ?? this.body,
      isResolved: isResolved ?? this.isResolved,
      resolutionLabel: resolutionLabel ?? this.resolutionLabel,
    );
  }
}

final class CodexUserInputRequestBlock extends CodexUiBlock {
  const CodexUserInputRequestBlock({
    required super.id,
    required super.createdAt,
    required this.requestId,
    required this.requestType,
    required this.title,
    required this.body,
    this.questions = const <CodexRuntimeUserInputQuestion>[],
    this.isResolved = false,
    this.answers = const <String, List<String>>{},
  }) : super(kind: CodexUiBlockKind.userInputRequest);

  final String requestId;
  final CodexCanonicalRequestType requestType;
  final String title;
  final String body;
  final List<CodexRuntimeUserInputQuestion> questions;
  final bool isResolved;
  final Map<String, List<String>> answers;

  CodexUserInputRequestBlock copyWith({
    String? title,
    String? body,
    List<CodexRuntimeUserInputQuestion>? questions,
    bool? isResolved,
    Map<String, List<String>>? answers,
  }) {
    return CodexUserInputRequestBlock(
      id: id,
      createdAt: createdAt,
      requestId: requestId,
      requestType: requestType,
      title: title ?? this.title,
      body: body ?? this.body,
      questions: questions ?? this.questions,
      isResolved: isResolved ?? this.isResolved,
      answers: answers ?? this.answers,
    );
  }
}
