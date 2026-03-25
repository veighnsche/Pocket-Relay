part of 'transcript_reducer.dart';

CodexSessionState _reduceSessionTranscriptRuntimeEventImpl(
  TranscriptReducer reducer,
  CodexSessionState state,
  CodexRuntimeEvent event,
) {
  final normalizedState = _normalizeTurnStateImpl(reducer, state, event);
  switch (event) {
    case CodexRuntimeSessionStateChangedEvent():
      return normalizedState.copyWith(connectionStatus: event.state);
    case CodexRuntimeSessionExitedEvent():
      return reducer._policy.applySessionExited(normalizedState, event);
    case CodexRuntimeThreadStartedEvent():
      return normalizedState.copyWithProjectedTranscript(
        threadId: event.providerThreadId,
      );
    case CodexRuntimeThreadStateChangedEvent():
      final isClosed = event.state == CodexRuntimeThreadState.closed;
      if (!isClosed) {
        return normalizedState;
      }
      return reducer._policy.applyThreadClosed(normalizedState, event);
    case CodexRuntimeTurnStartedEvent():
      final nextActiveTurn = reducer._support.activeTurnForStartedEvent(
        normalizedState.activeTurn,
        turnId: event.turnId,
        threadId: event.threadId,
        fallbackThreadId: normalizedState.threadId,
        createdAt: event.createdAt,
      );
      final nextState = normalizedState
          .copyWith(connectionStatus: CodexRuntimeSessionState.running)
          .copyWithProjectedTranscript(
            threadId: event.threadId ?? normalizedState.threadId,
            activeTurn: nextActiveTurn,
          );
      return _withUpdatedHeaderMetadataForTurnStartedImpl(nextState, event);
    case CodexRuntimeTurnCompletedEvent():
      return reducer._policy.applyTurnCompleted(normalizedState, event);
    case CodexRuntimeTurnAbortedEvent():
      return reducer._policy.applyTurnAborted(normalizedState, event);
    case CodexRuntimeTurnPlanUpdatedEvent():
      return reducer._policy.applyTurnPlanUpdated(normalizedState, event);
    case CodexRuntimeItemStartedEvent():
      return reducer._policy.applyItemLifecycle(
        normalizedState,
        event,
        removeAfterUpsert: false,
      );
    case CodexRuntimeItemUpdatedEvent():
      return reducer._policy.applyItemLifecycle(
        normalizedState,
        event,
        removeAfterUpsert: false,
      );
    case CodexRuntimeItemCompletedEvent():
      return reducer._policy.applyItemLifecycle(
        normalizedState,
        event,
        removeAfterUpsert: true,
      );
    case CodexRuntimeContentDeltaEvent():
      return reducer._policy.applyContentDelta(normalizedState, event);
    case CodexRuntimeRequestOpenedEvent():
      return reducer._policy.applyRequestOpened(normalizedState, event);
    case CodexRuntimeRequestResolvedEvent():
      return reducer._policy.applyRequestResolved(normalizedState, event);
    case CodexRuntimeUserInputRequestedEvent():
      return reducer._policy.applyUserInputRequested(normalizedState, event);
    case CodexRuntimeUserInputResolvedEvent():
      return reducer._policy.applyUserInputResolved(normalizedState, event);
    case CodexRuntimeWarningEvent():
      return reducer._policy.applyWarning(normalizedState, event);
    case CodexRuntimeSshConnectFailedEvent():
      return reducer._policy.applySshConnectFailed(normalizedState, event);
    case CodexRuntimeUnpinnedHostKeyEvent():
      return reducer._policy.applyUnpinnedHostKey(normalizedState, event);
    case CodexRuntimeSshHostKeyMismatchEvent():
      return reducer._policy.applySshHostKeyMismatch(normalizedState, event);
    case CodexRuntimeSshAuthenticationFailedEvent():
      return reducer._policy.applySshAuthenticationFailed(
        normalizedState,
        event,
      );
    case CodexRuntimeSshAuthenticatedEvent():
      return normalizedState;
    case CodexRuntimeStatusEvent():
      return reducer._policy.applyStatus(normalizedState, event);
    case CodexRuntimeErrorEvent():
      return reducer._policy.applyRuntimeError(normalizedState, event);
  }
}

CodexSessionState _withUpdatedHeaderMetadataForTurnStartedImpl(
  CodexSessionState state,
  CodexRuntimeTurnStartedEvent event,
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
  CodexSessionState state,
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

CodexSessionState _normalizeTurnStateImpl(
  TranscriptReducer reducer,
  CodexSessionState state,
  CodexRuntimeEvent event,
) {
  return switch (event) {
    CodexRuntimeSessionStateChangedEvent() ||
    CodexRuntimeSessionExitedEvent() ||
    CodexRuntimeThreadStartedEvent() ||
    CodexRuntimeThreadStateChangedEvent() ||
    CodexRuntimeTurnCompletedEvent() ||
    CodexRuntimeTurnAbortedEvent() => state,
    CodexRuntimeSshConnectFailedEvent() ||
    CodexRuntimeSshHostKeyMismatchEvent() ||
    CodexRuntimeSshAuthenticationFailedEvent() ||
    CodexRuntimeSshAuthenticatedEvent() => state,
    _ => reducer._policy.rolloverTurnIfNeeded(
      state,
      turnId: event.turnId,
      threadId: event.threadId,
      createdAt: event.createdAt,
    ),
  };
}
