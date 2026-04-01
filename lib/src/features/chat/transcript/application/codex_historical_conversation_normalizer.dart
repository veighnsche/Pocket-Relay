import 'package:pocket_relay/src/features/chat/transcript/application/codex_historical_conversation.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/codex_runtime_payload_support.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';

class CodexHistoricalConversationNormalizer {
  const CodexHistoricalConversationNormalizer({
    CodexRuntimePayloadSupport payloadSupport =
        const CodexRuntimePayloadSupport(),
  }) : _payloadSupport = payloadSupport;

  final CodexRuntimePayloadSupport _payloadSupport;

  CodexHistoricalConversation normalize(AgentAdapterThreadHistory thread) {
    final fallbackCreatedAt =
        thread.createdAt ?? thread.updatedAt ?? DateTime.now();
    return CodexHistoricalConversation(
      threadId: thread.id,
      createdAt: fallbackCreatedAt,
      updatedAt: thread.updatedAt,
      threadName: thread.name,
      sourceKind: thread.sourceKind,
      agentNickname: thread.agentNickname,
      agentRole: thread.agentRole,
      turns: thread.turns
          .map(
            (turn) => _normalizeTurn(
              turn,
              threadId: thread.id,
              fallbackCreatedAt: fallbackCreatedAt,
            ),
          )
          .toList(growable: false),
    );
  }

  CodexHistoricalTurn _normalizeTurn(
    AgentAdapterHistoryTurn turn, {
    required String threadId,
    required DateTime fallbackCreatedAt,
  }) {
    final effectiveThreadId = turn.threadId ?? threadId;
    final createdAt = _eventTimestamp(turn.raw, fallback: fallbackCreatedAt);
    final completionState = _payloadSupport.historicalTurnCompletionState(
      turn.status,
    );
    final completedAt = completionState == null
        ? null
        : _eventTimestamp(turn.raw, fallback: createdAt);
    return CodexHistoricalTurn(
      id: turn.id,
      threadId: effectiveThreadId,
      createdAt: createdAt,
      completedAt: completedAt,
      state: completionState,
      model: turn.model,
      effort: turn.effort,
      stopReason: turn.stopReason,
      usage: _payloadSupport.turnUsage(turn.usage),
      modelUsage: turn.modelUsage,
      totalCostUsd: turn.totalCostUsd,
      errorMessage: _payloadSupport.asString(turn.error?['message']),
      snapshot: turn.raw,
      entries: turn.items
          .map(
            (item) => _normalizeEntry(
              item,
              threadId: effectiveThreadId,
              turnId: turn.id,
              fallbackCreatedAt: createdAt,
            ),
          )
          .whereType<CodexHistoricalEntry>()
          .toList(growable: false),
    );
  }

  CodexHistoricalEntry? _normalizeEntry(
    AgentAdapterHistoryItem item, {
    required String threadId,
    required String turnId,
    required DateTime fallbackCreatedAt,
  }) {
    final itemType = _payloadSupport.canonicalItemType(item.type);
    return CodexHistoricalEntry(
      id: item.id,
      threadId: threadId,
      turnId: turnId,
      createdAt: _eventTimestamp(item.raw, fallback: fallbackCreatedAt),
      itemType: itemType,
      status: _payloadSupport.itemStatus(
        item.status,
        TranscriptRuntimeItemStatus.completed,
      ),
      title: transcriptItemTitle(itemType),
      detail: _payloadSupport.itemDetail(item.raw),
      snapshot: item.raw,
      collaboration: _payloadSupport.collaborationDetails(itemType, item.raw),
    );
  }

  DateTime _eventTimestamp(
    Map<String, dynamic> payload, {
    required DateTime fallback,
  }) {
    return _parseUnixTimestamp(
          payload['createdAt'] ??
              payload['updatedAt'] ??
              payload['completedAt'] ??
              payload['timestamp'],
        ) ??
        fallback;
  }

  DateTime? _parseUnixTimestamp(Object? raw) {
    if (raw is! num) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      raw.toInt() * 1000,
      isUtc: true,
    ).toLocal();
  }
}
