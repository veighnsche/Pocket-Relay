part of 'transcript_runtime_event.dart';

final class TranscriptRuntimeRequestOpenedEvent extends TranscriptRuntimeEvent {
  const TranscriptRuntimeRequestOpenedEvent({
    required super.createdAt,
    required this.requestType,
    required super.threadId,
    required super.requestId,
    super.turnId,
    super.itemId,
    super.rawMethod,
    super.rawPayload,
    this.detail,
    this.args,
  });

  final TranscriptCanonicalRequestType requestType;
  final String? detail;
  final Object? args;
}

final class TranscriptRuntimeRequestResolvedEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeRequestResolvedEvent({
    required super.createdAt,
    required this.requestType,
    required super.threadId,
    required super.requestId,
    super.turnId,
    super.itemId,
    super.rawMethod,
    super.rawPayload,
    this.resolution,
  });

  final TranscriptCanonicalRequestType requestType;
  final Object? resolution;
}

final class TranscriptRuntimeUserInputRequestedEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeUserInputRequestedEvent({
    required super.createdAt,
    required this.questions,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final List<TranscriptRuntimeUserInputQuestion> questions;
}

final class TranscriptRuntimeUserInputResolvedEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeUserInputResolvedEvent({
    required super.createdAt,
    required this.answers,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final Map<String, List<String>> answers;
}
