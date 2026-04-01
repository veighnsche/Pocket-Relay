part of 'transcript_runtime_event.dart';

final class TranscriptRuntimeSessionStateChangedEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeSessionStateChangedEvent({
    required super.createdAt,
    required this.state,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.reason,
  });

  final TranscriptRuntimeSessionState state;
  final String? reason;
}

final class TranscriptRuntimeSessionExitedEvent extends TranscriptRuntimeEvent {
  const TranscriptRuntimeSessionExitedEvent({
    required super.createdAt,
    required this.exitKind,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.reason,
    this.exitCode,
  });

  final TranscriptRuntimeSessionExitKind exitKind;
  final String? reason;
  final int? exitCode;
}

final class TranscriptRuntimeThreadStartedEvent extends TranscriptRuntimeEvent {
  const TranscriptRuntimeThreadStartedEvent({
    required super.createdAt,
    required this.providerThreadId,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.threadName,
    this.sourceKind,
    this.agentNickname,
    this.agentRole,
  });

  final String providerThreadId;
  final String? threadName;
  final String? sourceKind;
  final String? agentNickname;
  final String? agentRole;
}

final class TranscriptRuntimeThreadStateChangedEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeThreadStateChangedEvent({
    required super.createdAt,
    required this.state,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.detail,
  });

  final TranscriptRuntimeThreadState state;
  final Object? detail;
}

final class TranscriptRuntimeTurnStartedEvent extends TranscriptRuntimeEvent {
  const TranscriptRuntimeTurnStartedEvent({
    required super.createdAt,
    super.threadId,
    super.turnId,
    super.rawMethod,
    super.rawPayload,
    this.model,
    this.effort,
  });

  final String? model;
  final String? effort;
}

final class TranscriptRuntimeTurnCompletedEvent extends TranscriptRuntimeEvent {
  const TranscriptRuntimeTurnCompletedEvent({
    required super.createdAt,
    required this.state,
    super.threadId,
    super.turnId,
    super.rawMethod,
    super.rawPayload,
    this.stopReason,
    this.usage,
    this.modelUsage,
    this.totalCostUsd,
    this.errorMessage,
  });

  final TranscriptRuntimeTurnState state;
  final String? stopReason;
  final TranscriptRuntimeTurnUsage? usage;
  final Map<String, dynamic>? modelUsage;
  final double? totalCostUsd;
  final String? errorMessage;
}

final class TranscriptRuntimeTurnAbortedEvent extends TranscriptRuntimeEvent {
  const TranscriptRuntimeTurnAbortedEvent({
    required super.createdAt,
    super.threadId,
    super.turnId,
    super.rawMethod,
    super.rawPayload,
    this.reason,
  });

  final String? reason;
}

final class TranscriptRuntimeTurnPlanUpdatedEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeTurnPlanUpdatedEvent({
    required super.createdAt,
    required this.steps,
    super.threadId,
    super.turnId,
    super.rawMethod,
    super.rawPayload,
    this.explanation,
  });

  final String? explanation;
  final List<TranscriptRuntimePlanStep> steps;
}

sealed class TranscriptRuntimeItemLifecycleEvent
    extends TranscriptRuntimeEvent {
  const TranscriptRuntimeItemLifecycleEvent({
    required super.createdAt,
    required this.itemType,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required this.status,
    super.rawMethod,
    super.rawPayload,
    this.title,
    this.detail,
    this.snapshot,
    this.collaboration,
  });

  final TranscriptCanonicalItemType itemType;
  final TranscriptRuntimeItemStatus status;
  final String? title;
  final String? detail;
  final Map<String, dynamic>? snapshot;
  final TranscriptRuntimeCollabAgentToolCall? collaboration;
}

final class TranscriptRuntimeItemStartedEvent
    extends TranscriptRuntimeItemLifecycleEvent {
  const TranscriptRuntimeItemStartedEvent({
    required super.createdAt,
    required super.itemType,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required super.status,
    super.rawMethod,
    super.rawPayload,
    super.title,
    super.detail,
    super.snapshot,
    super.collaboration,
  });
}

final class TranscriptRuntimeItemUpdatedEvent
    extends TranscriptRuntimeItemLifecycleEvent {
  const TranscriptRuntimeItemUpdatedEvent({
    required super.createdAt,
    required super.itemType,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required super.status,
    super.rawMethod,
    super.rawPayload,
    super.title,
    super.detail,
    super.snapshot,
    super.collaboration,
  });
}

final class TranscriptRuntimeItemCompletedEvent
    extends TranscriptRuntimeItemLifecycleEvent {
  const TranscriptRuntimeItemCompletedEvent({
    required super.createdAt,
    required super.itemType,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required super.status,
    super.rawMethod,
    super.rawPayload,
    super.title,
    super.detail,
    super.snapshot,
    super.collaboration,
  });
}

final class TranscriptRuntimeContentDeltaEvent extends TranscriptRuntimeEvent {
  const TranscriptRuntimeContentDeltaEvent({
    required super.createdAt,
    required this.streamKind,
    required this.delta,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    super.rawMethod,
    super.rawPayload,
    this.contentIndex,
    this.summaryIndex,
  });

  final TranscriptRuntimeContentStreamKind streamKind;
  final String delta;
  final int? contentIndex;
  final int? summaryIndex;
}
