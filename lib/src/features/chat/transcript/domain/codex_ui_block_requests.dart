part of 'transcript_ui_block.dart';

final class TranscriptApprovalRequestBlock extends TranscriptUiBlock {
  const TranscriptApprovalRequestBlock({
    required super.id,
    required super.createdAt,
    required this.requestId,
    required this.requestType,
    required this.title,
    required this.body,
    this.isResolved = false,
    this.resolutionLabel,
  }) : super(kind: TranscriptUiBlockKind.approvalRequest);

  final String requestId;
  final TranscriptCanonicalRequestType requestType;
  final String title;
  final String body;
  final bool isResolved;
  final String? resolutionLabel;

  TranscriptApprovalRequestBlock copyWith({
    String? title,
    String? body,
    bool? isResolved,
    String? resolutionLabel,
  }) {
    return TranscriptApprovalRequestBlock(
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

final class TranscriptUserInputRequestBlock extends TranscriptUiBlock {
  const TranscriptUserInputRequestBlock({
    required super.id,
    required super.createdAt,
    required this.requestId,
    required this.requestType,
    required this.title,
    required this.body,
    this.questions = const <TranscriptRuntimeUserInputQuestion>[],
    this.isResolved = false,
    this.answers = const <String, List<String>>{},
  }) : super(kind: TranscriptUiBlockKind.userInputRequest);

  final String requestId;
  final TranscriptCanonicalRequestType requestType;
  final String title;
  final String body;
  final List<TranscriptRuntimeUserInputQuestion> questions;
  final bool isResolved;
  final Map<String, List<String>> answers;

  TranscriptUserInputRequestBlock copyWith({
    String? title,
    String? body,
    List<TranscriptRuntimeUserInputQuestion>? questions,
    bool? isResolved,
    Map<String, List<String>>? answers,
  }) {
    return TranscriptUserInputRequestBlock(
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
