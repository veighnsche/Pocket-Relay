part of 'transcript_runtime_event.dart';

class TranscriptRuntimeTurnUsage {
  const TranscriptRuntimeTurnUsage({
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

class TranscriptRuntimePlanStep {
  const TranscriptRuntimePlanStep({required this.step, required this.status});

  final String step;
  final TranscriptRuntimePlanStepStatus status;
}

class TranscriptRuntimeUserInputOption {
  const TranscriptRuntimeUserInputOption({
    required this.label,
    required this.description,
  });

  final String label;
  final String description;
}

class TranscriptRuntimeUserInputQuestion {
  const TranscriptRuntimeUserInputQuestion({
    required this.id,
    required this.header,
    required this.question,
    this.options = const <TranscriptRuntimeUserInputOption>[],
    this.isOther = false,
    this.isSecret = false,
  });

  final String id;
  final String header;
  final String question;
  final List<TranscriptRuntimeUserInputOption> options;
  final bool isOther;
  final bool isSecret;
}

class TranscriptRuntimeCollabAgentState {
  const TranscriptRuntimeCollabAgentState({required this.status, this.message});

  final TranscriptRuntimeCollabAgentStatus status;
  final String? message;
}

class TranscriptRuntimeCollabAgentToolCall {
  const TranscriptRuntimeCollabAgentToolCall({
    required this.tool,
    required this.status,
    required this.senderThreadId,
    required this.receiverThreadIds,
    this.prompt,
    this.model,
    this.reasoningEffort,
    this.agentsStates = const <String, TranscriptRuntimeCollabAgentState>{},
  });

  final TranscriptRuntimeCollabAgentTool tool;
  final TranscriptRuntimeCollabAgentToolCallStatus status;
  final String senderThreadId;
  final List<String> receiverThreadIds;
  final String? prompt;
  final String? model;
  final String? reasoningEffort;
  final Map<String, TranscriptRuntimeCollabAgentState> agentsStates;
}
