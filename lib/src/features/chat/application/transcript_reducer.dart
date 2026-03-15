import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_policy.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';

class TranscriptReducer {
  const TranscriptReducer({TranscriptPolicy policy = const TranscriptPolicy()})
    : _policy = policy;

  final TranscriptPolicy _policy;

  CodexSessionState addUserMessage(
    CodexSessionState state, {
    required String text,
    DateTime? createdAt,
  }) {
    return _policy.addUserMessage(state, text: text, createdAt: createdAt);
  }

  CodexSessionState startFreshThread(
    CodexSessionState state, {
    String? message,
    DateTime? createdAt,
  }) {
    return _policy.startFreshThread(
      state,
      message: message,
      createdAt: createdAt,
    );
  }

  CodexSessionState clearTranscript(CodexSessionState state) {
    return _policy.clearTranscript(state);
  }

  CodexSessionState detachThread(CodexSessionState state) {
    return _policy.detachThread(state);
  }

  CodexSessionState reduceRuntimeEvent(
    CodexSessionState state,
    CodexRuntimeEvent event,
  ) {
    final normalizedState = _normalizeTurnState(state, event);
    switch (event) {
      case CodexRuntimeSessionStartedEvent():
        return normalizedState;
      case CodexRuntimeSessionStateChangedEvent():
        return normalizedState.copyWith(connectionStatus: event.state);
      case CodexRuntimeSessionExitedEvent():
        return _policy.applySessionExited(normalizedState, event);
      case CodexRuntimeThreadStartedEvent():
        return normalizedState.copyWith(threadId: event.providerThreadId);
      case CodexRuntimeThreadStateChangedEvent():
        final isClosed = event.state == CodexRuntimeThreadState.closed;
        final activeTurn = isClosed && normalizedState.activeTurn != null
            ? normalizedState.activeTurn!.copyWith(
                timer: normalizedState.activeTurn!.timer.complete(
                  completedAt: event.createdAt,
                  monotonicAt: CodexMonotonicClock.now(),
                ),
              )
            : normalizedState.activeTurn;
        return normalizedState.copyWith(
          clearThreadId: isClosed,
          activeTurn: isClosed ? activeTurn : normalizedState.activeTurn,
          clearActiveTurn: isClosed,
        );
      case CodexRuntimeTurnStartedEvent():
        final nextTimer = event.turnId == null
            ? null
            : CodexSessionTurnTimer(
                turnId: event.turnId!,
                startedAt: event.createdAt,
                activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
              );
        return normalizedState.copyWith(
          connectionStatus: CodexRuntimeSessionState.running,
          threadId: event.threadId ?? normalizedState.threadId,
          activeTurn: event.turnId == null
              ? normalizedState.activeTurn
              : CodexActiveTurnState(
                  turnId: event.turnId!,
                  threadId: event.threadId ?? normalizedState.threadId,
                  timer: nextTimer!,
                ),
        );
      case CodexRuntimeTurnCompletedEvent():
        return _policy.applyTurnCompleted(normalizedState, event);
      case CodexRuntimeTurnAbortedEvent():
        return _policy.applyTurnAborted(normalizedState, event);
      case CodexRuntimeTurnPlanUpdatedEvent():
        return _policy.applyTurnPlanUpdated(normalizedState, event);
      case CodexRuntimeTurnDiffUpdatedEvent():
        return _policy.applyTurnDiffUpdated(normalizedState, event);
      case CodexRuntimeItemStartedEvent():
        return _policy.applyItemLifecycle(
          normalizedState,
          event,
          removeAfterUpsert: false,
        );
      case CodexRuntimeItemUpdatedEvent():
        return _policy.applyItemLifecycle(
          normalizedState,
          event,
          removeAfterUpsert: false,
        );
      case CodexRuntimeItemCompletedEvent():
        return _policy.applyItemLifecycle(
          normalizedState,
          event,
          removeAfterUpsert: true,
        );
      case CodexRuntimeContentDeltaEvent():
        return _policy.applyContentDelta(normalizedState, event);
      case CodexRuntimeRequestOpenedEvent():
        return _policy.applyRequestOpened(normalizedState, event);
      case CodexRuntimeRequestResolvedEvent():
        return _policy.applyRequestResolved(normalizedState, event);
      case CodexRuntimeUserInputRequestedEvent():
        return _policy.applyUserInputRequested(normalizedState, event);
      case CodexRuntimeUserInputResolvedEvent():
        return _policy.applyUserInputResolved(normalizedState, event);
      case CodexRuntimeWarningEvent():
        return _policy.applyWarning(normalizedState, event);
      case CodexRuntimeStatusEvent():
        return _policy.applyStatus(normalizedState, event);
      case CodexRuntimeErrorEvent():
        return _policy.applyRuntimeError(normalizedState, event);
    }
  }

  CodexSessionState _normalizeTurnState(
    CodexSessionState state,
    CodexRuntimeEvent event,
  ) {
    return switch (event) {
      CodexRuntimeSessionStartedEvent() ||
      CodexRuntimeSessionStateChangedEvent() ||
      CodexRuntimeSessionExitedEvent() ||
      CodexRuntimeThreadStartedEvent() ||
      CodexRuntimeThreadStateChangedEvent() ||
      CodexRuntimeTurnCompletedEvent() ||
      CodexRuntimeTurnAbortedEvent() => state,
      _ => _policy.rolloverTurnIfNeeded(
        state,
        turnId: event.turnId,
        threadId: event.threadId,
        createdAt: event.createdAt,
      ),
    };
  }
}
