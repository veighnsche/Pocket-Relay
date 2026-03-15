enum CodexRuntimeSessionState {
  starting,
  ready,
  running,
  waiting,
  stopped,
  error,
}

enum CodexRuntimeThreadState {
  active,
  idle,
  archived,
  closed,
  compacted,
  error,
}

enum CodexRuntimeTurnState { completed, failed, interrupted, cancelled }

enum CodexRuntimePlanStepStatus { pending, inProgress, completed }

enum CodexRuntimeItemStatus { inProgress, completed, failed, declined }

enum CodexRuntimeContentStreamKind {
  assistantText,
  reasoningText,
  reasoningSummaryText,
  planText,
  commandOutput,
  fileChangeOutput,
  unknown,
}

enum CodexRuntimeSessionExitKind { graceful, error }

enum CodexRuntimeErrorClass {
  providerError,
  transportError,
  permissionError,
  validationError,
  unknown,
}

enum CodexCanonicalItemType {
  userMessage,
  assistantMessage,
  reasoning,
  plan,
  commandExecution,
  fileChange,
  mcpToolCall,
  dynamicToolCall,
  collabAgentToolCall,
  webSearch,
  imageView,
  imageGeneration,
  reviewEntered,
  reviewExited,
  contextCompaction,
  error,
  unknown,
}

enum CodexCanonicalRequestType {
  commandExecutionApproval,
  fileChangeApproval,
  applyPatchApproval,
  execCommandApproval,
  permissionsRequestApproval,
  toolUserInput,
  mcpServerElicitation,
  unknown,
}

String codexItemTitle(CodexCanonicalItemType itemType) {
  return switch (itemType) {
    CodexCanonicalItemType.userMessage => 'You',
    CodexCanonicalItemType.assistantMessage => 'Codex',
    CodexCanonicalItemType.reasoning => 'Reasoning',
    CodexCanonicalItemType.plan => 'Proposed plan',
    CodexCanonicalItemType.commandExecution => 'Command',
    CodexCanonicalItemType.fileChange => 'Changed files',
    CodexCanonicalItemType.mcpToolCall => 'MCP tool call',
    CodexCanonicalItemType.dynamicToolCall => 'Tool call',
    CodexCanonicalItemType.collabAgentToolCall => 'Agent tool call',
    CodexCanonicalItemType.webSearch => 'Web search',
    CodexCanonicalItemType.imageView => 'Image view',
    CodexCanonicalItemType.imageGeneration => 'Image generation',
    CodexCanonicalItemType.reviewEntered => 'Review started',
    CodexCanonicalItemType.reviewExited => 'Review finished',
    CodexCanonicalItemType.contextCompaction => 'Context compacted',
    CodexCanonicalItemType.error => 'Error',
    CodexCanonicalItemType.unknown => 'Codex',
  };
}

class CodexRuntimeTurnUsage {
  const CodexRuntimeTurnUsage({
    this.inputTokens,
    this.cachedInputTokens,
    this.outputTokens,
    this.raw,
  });

  final int? inputTokens;
  final int? cachedInputTokens;
  final int? outputTokens;
  final Map<String, dynamic>? raw;
}

class CodexRuntimePlanStep {
  const CodexRuntimePlanStep({required this.step, required this.status});

  final String step;
  final CodexRuntimePlanStepStatus status;
}

class CodexRuntimeUserInputOption {
  const CodexRuntimeUserInputOption({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;
}

class CodexRuntimeUserInputQuestion {
  const CodexRuntimeUserInputQuestion({
    required this.id,
    required this.header,
    required this.question,
    this.options = const <CodexRuntimeUserInputOption>[],
    this.isOther = false,
    this.isSecret = false,
  });

  final String id;
  final String header;
  final String question;
  final List<CodexRuntimeUserInputOption> options;
  final bool isOther;
  final bool isSecret;
}

sealed class CodexRuntimeEvent {
  const CodexRuntimeEvent({
    required this.createdAt,
    this.threadId,
    this.turnId,
    this.itemId,
    this.requestId,
    this.rawMethod,
    this.rawPayload,
  });

  final DateTime createdAt;
  final String? threadId;
  final String? turnId;
  final String? itemId;
  final String? requestId;
  final String? rawMethod;
  final Object? rawPayload;
}

final class CodexRuntimeSessionStateChangedEvent extends CodexRuntimeEvent {
  const CodexRuntimeSessionStateChangedEvent({
    required super.createdAt,
    required this.state,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.reason,
  });

  final CodexRuntimeSessionState state;
  final String? reason;
}

final class CodexRuntimeSessionExitedEvent extends CodexRuntimeEvent {
  const CodexRuntimeSessionExitedEvent({
    required super.createdAt,
    required this.exitKind,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.reason,
    this.exitCode,
  });

  final CodexRuntimeSessionExitKind exitKind;
  final String? reason;
  final int? exitCode;
}

final class CodexRuntimeThreadStartedEvent extends CodexRuntimeEvent {
  const CodexRuntimeThreadStartedEvent({
    required super.createdAt,
    required this.providerThreadId,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
  });

  final String providerThreadId;
}

final class CodexRuntimeThreadStateChangedEvent extends CodexRuntimeEvent {
  const CodexRuntimeThreadStateChangedEvent({
    required super.createdAt,
    required this.state,
    super.threadId,
    super.rawMethod,
    super.rawPayload,
    this.detail,
  });

  final CodexRuntimeThreadState state;
  final Object? detail;
}

final class CodexRuntimeTurnStartedEvent extends CodexRuntimeEvent {
  const CodexRuntimeTurnStartedEvent({
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

final class CodexRuntimeTurnCompletedEvent extends CodexRuntimeEvent {
  const CodexRuntimeTurnCompletedEvent({
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

  final CodexRuntimeTurnState state;
  final String? stopReason;
  final CodexRuntimeTurnUsage? usage;
  final Map<String, dynamic>? modelUsage;
  final double? totalCostUsd;
  final String? errorMessage;
}

final class CodexRuntimeTurnAbortedEvent extends CodexRuntimeEvent {
  const CodexRuntimeTurnAbortedEvent({
    required super.createdAt,
    super.threadId,
    super.turnId,
    super.rawMethod,
    super.rawPayload,
    this.reason,
  });

  final String? reason;
}

final class CodexRuntimeTurnPlanUpdatedEvent extends CodexRuntimeEvent {
  const CodexRuntimeTurnPlanUpdatedEvent({
    required super.createdAt,
    required this.steps,
    super.threadId,
    super.turnId,
    super.rawMethod,
    super.rawPayload,
    this.explanation,
  });

  final String? explanation;
  final List<CodexRuntimePlanStep> steps;
}

sealed class CodexRuntimeItemLifecycleEvent extends CodexRuntimeEvent {
  const CodexRuntimeItemLifecycleEvent({
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
  });

  final CodexCanonicalItemType itemType;
  final CodexRuntimeItemStatus status;
  final String? title;
  final String? detail;
  final Map<String, dynamic>? snapshot;
}

final class CodexRuntimeItemStartedEvent
    extends CodexRuntimeItemLifecycleEvent {
  const CodexRuntimeItemStartedEvent({
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
  });
}

final class CodexRuntimeItemUpdatedEvent
    extends CodexRuntimeItemLifecycleEvent {
  const CodexRuntimeItemUpdatedEvent({
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
  });
}

final class CodexRuntimeItemCompletedEvent
    extends CodexRuntimeItemLifecycleEvent {
  const CodexRuntimeItemCompletedEvent({
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
  });
}

final class CodexRuntimeContentDeltaEvent extends CodexRuntimeEvent {
  const CodexRuntimeContentDeltaEvent({
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

  final CodexRuntimeContentStreamKind streamKind;
  final String delta;
  final int? contentIndex;
  final int? summaryIndex;
}

final class CodexRuntimeRequestOpenedEvent extends CodexRuntimeEvent {
  const CodexRuntimeRequestOpenedEvent({
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

  final CodexCanonicalRequestType requestType;
  final String? detail;
  final Object? args;
}

final class CodexRuntimeRequestResolvedEvent extends CodexRuntimeEvent {
  const CodexRuntimeRequestResolvedEvent({
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

  final CodexCanonicalRequestType requestType;
  final Object? resolution;
}

final class CodexRuntimeUserInputRequestedEvent extends CodexRuntimeEvent {
  const CodexRuntimeUserInputRequestedEvent({
    required super.createdAt,
    required this.questions,
    required super.threadId,
    required super.turnId,
    required super.itemId,
    required super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final List<CodexRuntimeUserInputQuestion> questions;
}

final class CodexRuntimeUserInputResolvedEvent extends CodexRuntimeEvent {
  const CodexRuntimeUserInputResolvedEvent({
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

final class CodexRuntimeWarningEvent extends CodexRuntimeEvent {
  const CodexRuntimeWarningEvent({
    required super.createdAt,
    required this.summary,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
    this.details,
  });

  final String summary;
  final String? details;
}

final class CodexRuntimeUnpinnedHostKeyEvent extends CodexRuntimeEvent {
  const CodexRuntimeUnpinnedHostKeyEvent({
    required super.createdAt,
    required this.host,
    required this.port,
    required this.keyType,
    required this.fingerprint,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final String host;
  final int port;
  final String keyType;
  final String fingerprint;
}

final class CodexRuntimeStatusEvent extends CodexRuntimeEvent {
  const CodexRuntimeStatusEvent({
    required super.createdAt,
    required this.title,
    required this.message,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
  });

  final String title;
  final String message;
}

final class CodexRuntimeErrorEvent extends CodexRuntimeEvent {
  const CodexRuntimeErrorEvent({
    required super.createdAt,
    required this.message,
    required this.errorClass,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
    this.detail,
  });

  final String message;
  final CodexRuntimeErrorClass errorClass;
  final Object? detail;
}
