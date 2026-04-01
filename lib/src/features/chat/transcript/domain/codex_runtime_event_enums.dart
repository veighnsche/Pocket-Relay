part of 'transcript_runtime_event.dart';

enum TranscriptRuntimeSessionState {
  starting,
  ready,
  running,
  waiting,
  stopped,
  error,
}

enum TranscriptRuntimeThreadState {
  active,
  idle,
  archived,
  closed,
  compacted,
  error,
}

enum TranscriptRuntimeTurnState { completed, failed, interrupted, cancelled }

enum TranscriptRuntimePlanStepStatus { pending, inProgress, completed }

enum TranscriptRuntimeItemStatus { inProgress, completed, failed, declined }

enum TranscriptRuntimeContentStreamKind {
  assistantText,
  reasoningText,
  reasoningSummaryText,
  planText,
  commandOutput,
  fileChangeOutput,
  unknown,
}

enum TranscriptRuntimeSessionExitKind { graceful, error }

enum TranscriptRuntimeErrorClass {
  providerError,
  transportError,
  permissionError,
  validationError,
  unknown,
}

enum TranscriptRuntimeCollabAgentTool {
  spawnAgent,
  sendInput,
  resumeAgent,
  wait,
  closeAgent,
  unknown,
}

enum TranscriptRuntimeCollabAgentToolCallStatus {
  inProgress,
  completed,
  failed,
  unknown,
}

enum TranscriptRuntimeCollabAgentStatus {
  pendingInit,
  running,
  completed,
  errored,
  shutdown,
  notFound,
  unknown,
}

enum TranscriptCanonicalItemType {
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

enum TranscriptCanonicalRequestType {
  commandExecutionApproval,
  fileChangeApproval,
  applyPatchApproval,
  execCommandApproval,
  permissionsRequestApproval,
  toolUserInput,
  mcpServerElicitation,
  unknown,
}

String transcriptItemTitle(TranscriptCanonicalItemType itemType) {
  return switch (itemType) {
    TranscriptCanonicalItemType.userMessage => 'You',
    TranscriptCanonicalItemType.assistantMessage => 'Codex',
    TranscriptCanonicalItemType.reasoning => 'Reasoning',
    TranscriptCanonicalItemType.plan => 'Proposed plan',
    TranscriptCanonicalItemType.commandExecution => 'Command',
    TranscriptCanonicalItemType.fileChange => 'Changed files',
    TranscriptCanonicalItemType.mcpToolCall => 'MCP tool call',
    TranscriptCanonicalItemType.dynamicToolCall => 'Tool call',
    TranscriptCanonicalItemType.collabAgentToolCall => 'Agent tool call',
    TranscriptCanonicalItemType.webSearch => 'Web search',
    TranscriptCanonicalItemType.imageView => 'Image view',
    TranscriptCanonicalItemType.imageGeneration => 'Image generation',
    TranscriptCanonicalItemType.reviewEntered => 'Review started',
    TranscriptCanonicalItemType.reviewExited => 'Review finished',
    TranscriptCanonicalItemType.contextCompaction => 'Context compacted',
    TranscriptCanonicalItemType.error => 'Error',
    TranscriptCanonicalItemType.unknown => 'Codex',
  };
}
