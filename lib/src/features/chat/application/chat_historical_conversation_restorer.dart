import 'package:pocket_relay/src/features/chat/application/codex_historical_conversation.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';

class ChatHistoricalConversationRestorer {
  const ChatHistoricalConversationRestorer({
    TranscriptReducer reducer = const TranscriptReducer(),
  }) : _reducer = reducer;

  final TranscriptReducer _reducer;

  CodexSessionState restore(
    CodexHistoricalConversation conversation, {
    CodexRuntimeSessionState connectionStatus = CodexRuntimeSessionState.ready,
  }) {
    var nextState = CodexSessionState.transcript(
      connectionStatus: connectionStatus,
    );

    nextState = _reducer.reduceRuntimeEvent(
      nextState,
      CodexRuntimeThreadStartedEvent(
        createdAt: conversation.createdAt,
        threadId: conversation.threadId,
        providerThreadId: conversation.threadId,
        rawMethod: 'thread/read(response)',
        threadName: conversation.threadName,
        sourceKind: conversation.sourceKind,
        agentNickname: conversation.agentNickname,
        agentRole: conversation.agentRole,
      ),
    );

    for (final turn in conversation.turns) {
      nextState = _reducer.reduceRuntimeEvent(
        nextState,
        CodexRuntimeTurnStartedEvent(
          createdAt: turn.createdAt,
          threadId: turn.threadId,
          turnId: turn.id,
          rawMethod: 'thread/read(turn)',
          rawPayload: turn.snapshot,
          model: turn.model,
          effort: turn.effort,
        ),
      );

      for (final entry in turn.entries) {
        final rawPayload = <String, Object?>{
          'threadId': entry.threadId,
          'turnId': entry.turnId,
          'itemId': entry.id,
          'item': entry.snapshot,
        };
        nextState = _reducer.reduceRuntimeEvent(
          nextState,
          _buildLifecycleEvent(entry, rawPayload: rawPayload),
        );
      }

      nextState = _reducer.reduceRuntimeEvent(
        nextState,
        CodexRuntimeTurnCompletedEvent(
          createdAt: turn.completedAt,
          threadId: turn.threadId,
          turnId: turn.id,
          rawMethod: 'thread/read(turn)',
          rawPayload: turn.snapshot,
          state: turn.state,
          stopReason: turn.stopReason,
          usage: turn.usage,
          modelUsage: turn.modelUsage,
          totalCostUsd: turn.totalCostUsd,
          errorMessage: turn.errorMessage,
        ),
      );
    }

    return nextState;
  }

  CodexRuntimeItemLifecycleEvent _buildLifecycleEvent(
    CodexHistoricalEntry entry, {
    required Object? rawPayload,
  }) {
    if (entry.status == CodexRuntimeItemStatus.inProgress) {
      return CodexRuntimeItemStartedEvent(
        createdAt: entry.createdAt,
        itemType: entry.itemType,
        threadId: entry.threadId,
        turnId: entry.turnId,
        itemId: entry.id,
        status: entry.status,
        rawMethod: 'thread/read(item)',
        rawPayload: rawPayload,
        title: entry.title,
        detail: entry.detail,
        snapshot: entry.snapshot,
        collaboration: entry.collaboration,
      );
    }

    return CodexRuntimeItemCompletedEvent(
      createdAt: entry.createdAt,
      itemType: entry.itemType,
      threadId: entry.threadId,
      turnId: entry.turnId,
      itemId: entry.id,
      status: entry.status,
      rawMethod: 'thread/read(item)',
      rawPayload: rawPayload,
      title: entry.title,
      detail: entry.detail,
      snapshot: entry.snapshot,
      collaboration: entry.collaboration,
    );
  }
}
