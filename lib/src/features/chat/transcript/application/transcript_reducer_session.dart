part of 'transcript_reducer.dart';

TranscriptSessionState _reduceSessionTranscriptRuntimeEventImpl(
  TranscriptReducer reducer,
  TranscriptSessionState state,
  TranscriptRuntimeEvent event,
) {
  final normalizedState = _normalizeTurnStateImpl(reducer, state, event);
  switch (event) {
    case TranscriptRuntimeSessionStateChangedEvent():
      return normalizedState.copyWith(connectionStatus: event.state);
    case TranscriptRuntimeSessionExitedEvent():
      return reducer._policy.applySessionExited(normalizedState, event);
    case TranscriptRuntimeThreadStartedEvent():
      return normalizedState.copyWithProjectedTranscript(
        threadId: event.providerThreadId,
      );
    case TranscriptRuntimeThreadStateChangedEvent():
      final isClosed = event.state == TranscriptRuntimeThreadState.closed;
      if (!isClosed) {
        return normalizedState;
      }
      return reducer._policy.applyThreadClosed(normalizedState, event);
    case TranscriptRuntimeTurnStartedEvent():
      final nextActiveTurn = reducer._support.activeTurnForStartedEvent(
        normalizedState.activeTurn,
        turnId: event.turnId,
        threadId: event.threadId,
        fallbackThreadId: normalizedState.threadId,
        createdAt: event.createdAt,
      );
      final nextState = normalizedState
          .copyWith(connectionStatus: TranscriptRuntimeSessionState.running)
          .copyWithProjectedTranscript(
            threadId: event.threadId ?? normalizedState.threadId,
            activeTurn: nextActiveTurn,
          );
      return _withUpdatedHeaderMetadataForTurnStartedImpl(nextState, event);
    case TranscriptRuntimeTurnCompletedEvent():
      return reducer._policy.applyTurnCompleted(normalizedState, event);
    case TranscriptRuntimeTurnAbortedEvent():
      return reducer._policy.applyTurnAborted(normalizedState, event);
    case TranscriptRuntimeTurnPlanUpdatedEvent():
      return reducer._policy.applyTurnPlanUpdated(normalizedState, event);
    case TranscriptRuntimeItemStartedEvent():
      return reducer._policy.applyItemLifecycle(
        normalizedState,
        event,
        removeAfterUpsert: false,
      );
    case TranscriptRuntimeItemUpdatedEvent():
      return reducer._policy.applyItemLifecycle(
        normalizedState,
        event,
        removeAfterUpsert: false,
      );
    case TranscriptRuntimeItemCompletedEvent():
      return reducer._policy.applyItemLifecycle(
        normalizedState,
        event,
        removeAfterUpsert: true,
      );
    case TranscriptRuntimeContentDeltaEvent():
      return reducer._policy.applyContentDelta(normalizedState, event);
    case TranscriptRuntimeRequestOpenedEvent():
      return reducer._policy.applyRequestOpened(normalizedState, event);
    case TranscriptRuntimeRequestResolvedEvent():
      return reducer._policy.applyRequestResolved(normalizedState, event);
    case TranscriptRuntimeUserInputRequestedEvent():
      return reducer._policy.applyUserInputRequested(normalizedState, event);
    case TranscriptRuntimeUserInputResolvedEvent():
      return reducer._policy.applyUserInputResolved(normalizedState, event);
    case TranscriptRuntimeWarningEvent():
      return reducer._policy.applyWarning(normalizedState, event);
    case TranscriptRuntimeSshConnectFailedEvent():
      return reducer._policy.applySshConnectFailed(normalizedState, event);
    case TranscriptRuntimeUnpinnedHostKeyEvent():
      return reducer._policy.applyUnpinnedHostKey(normalizedState, event);
    case TranscriptRuntimeSshHostKeyMismatchEvent():
      return reducer._policy.applySshHostKeyMismatch(normalizedState, event);
    case TranscriptRuntimeSshAuthenticationFailedEvent():
      return reducer._policy.applySshAuthenticationFailed(
        normalizedState,
        event,
      );
    case TranscriptRuntimeSshAuthenticatedEvent():
      return normalizedState;
    case TranscriptRuntimeStatusEvent():
      return reducer._policy.applyStatus(normalizedState, event);
    case TranscriptRuntimeErrorEvent():
      return reducer._policy.applyRuntimeError(normalizedState, event);
  }
}

TranscriptSessionState _withUpdatedHeaderMetadataForTurnStartedImpl(
  TranscriptSessionState state,
  TranscriptRuntimeTurnStartedEvent event,
) {
  if (!_shouldUpdateHeaderMetadataForThreadImpl(state, event.threadId)) {
    return state;
  }

  final nextModel = event.model?.trim();
  final nextEffort = event.effort?.trim();
  if ((nextModel == null || nextModel.isEmpty) &&
      (nextEffort == null || nextEffort.isEmpty)) {
    return state;
  }

  return state.copyWith(
    headerMetadata: state.headerMetadata.copyWith(
      model: nextModel == null || nextModel.isEmpty ? null : nextModel,
      reasoningEffort: nextEffort == null || nextEffort.isEmpty
          ? null
          : nextEffort,
    ),
  );
}

bool _shouldUpdateHeaderMetadataForThreadImpl(
  TranscriptSessionState state,
  String? threadId,
) {
  final normalizedThreadId = threadId?.trim();
  if (normalizedThreadId == null || normalizedThreadId.isEmpty) {
    return state.rootThreadId == null;
  }

  final rootThreadId = state.rootThreadId?.trim();
  if (rootThreadId == null || rootThreadId.isEmpty) {
    return true;
  }

  return normalizedThreadId == rootThreadId;
}

TranscriptSessionState _normalizeTurnStateImpl(
  TranscriptReducer reducer,
  TranscriptSessionState state,
  TranscriptRuntimeEvent event,
) {
  return switch (event) {
    TranscriptRuntimeSessionStateChangedEvent() ||
    TranscriptRuntimeSessionExitedEvent() ||
    TranscriptRuntimeThreadStartedEvent() ||
    TranscriptRuntimeThreadStateChangedEvent() ||
    TranscriptRuntimeTurnCompletedEvent() ||
    TranscriptRuntimeTurnAbortedEvent() => state,
    TranscriptRuntimeSshConnectFailedEvent() ||
    TranscriptRuntimeSshHostKeyMismatchEvent() ||
    TranscriptRuntimeSshAuthenticationFailedEvent() ||
    TranscriptRuntimeSshAuthenticatedEvent() => state,
    _ => reducer._policy.rolloverTurnIfNeeded(
      state,
      turnId: event.turnId,
      threadId: event.threadId,
      createdAt: event.createdAt,
    ),
  };
}
