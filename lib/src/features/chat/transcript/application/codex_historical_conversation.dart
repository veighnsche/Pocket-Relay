import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';

class CodexHistoricalConversation {
  const CodexHistoricalConversation({
    required this.threadId,
    required this.createdAt,
    this.updatedAt,
    this.threadName,
    this.sourceKind,
    this.agentNickname,
    this.agentRole,
    this.turns = const <CodexHistoricalTurn>[],
  });

  final String threadId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? threadName;
  final String? sourceKind;
  final String? agentNickname;
  final String? agentRole;
  final List<CodexHistoricalTurn> turns;
}

class CodexHistoricalTurn {
  const CodexHistoricalTurn({
    required this.id,
    required this.threadId,
    required this.createdAt,
    this.completedAt,
    this.state,
    this.model,
    this.effort,
    this.stopReason,
    this.usage,
    this.modelUsage,
    this.totalCostUsd,
    this.errorMessage,
    this.snapshot,
    this.entries = const <CodexHistoricalEntry>[],
  });

  final String id;
  final String threadId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final TranscriptRuntimeTurnState? state;
  final String? model;
  final String? effort;
  final String? stopReason;
  final TranscriptRuntimeTurnUsage? usage;
  final Map<String, dynamic>? modelUsage;
  final double? totalCostUsd;
  final String? errorMessage;
  final Map<String, dynamic>? snapshot;
  final List<CodexHistoricalEntry> entries;

  bool get isCompleted => completedAt != null && state != null;
}

class CodexHistoricalEntry {
  const CodexHistoricalEntry({
    required this.id,
    required this.threadId,
    required this.turnId,
    required this.createdAt,
    required this.itemType,
    required this.status,
    required this.title,
    this.detail,
    this.snapshot,
    this.collaboration,
  });

  final String id;
  final String threadId;
  final String turnId;
  final DateTime createdAt;
  final TranscriptCanonicalItemType itemType;
  final TranscriptRuntimeItemStatus status;
  final String title;
  final String? detail;
  final Map<String, dynamic>? snapshot;
  final TranscriptRuntimeCollabAgentToolCall? collaboration;
}
