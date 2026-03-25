part of 'transcript_reducer.dart';

CodexSessionState _reduceWorkspaceRuntimeEventImpl(
  TranscriptReducer reducer,
  CodexSessionState state,
  CodexRuntimeEvent event,
) {
  switch (event) {
    case CodexRuntimeSessionStateChangedEvent():
      return _withUpdatedGlobalConnectionStatusImpl(state, event.state);
    case CodexRuntimeSessionExitedEvent():
      return _reduceSessionExitedImpl(reducer, state, event);
    case CodexRuntimeThreadStartedEvent():
      return _upsertThreadStartedImpl(state, event);
    case CodexRuntimeThreadStateChangedEvent():
      return _reduceThreadStateChangedImpl(reducer, state, event);
    case CodexRuntimeSshAuthenticatedEvent():
      return state;
    default:
      break;
  }

  final targetThreadId = _targetThreadIdForEventImpl(state, event);
  if (targetThreadId == null) {
    return state;
  }

  var nextState = _applyCollaborationMetadataImpl(
    state,
    event,
    targetThreadId: targetThreadId,
  );
  nextState = _reduceTimelineStateImpl(
    reducer,
    nextState,
    threadId: targetThreadId,
    event: event,
    reducerFn: (projectedState) => _reduceSessionTranscriptRuntimeEventImpl(
      reducer,
      projectedState,
      event,
    ),
    lifecycleOverride: _lifecycleOverrideForEventImpl(
      nextState.timelineForThread(targetThreadId),
      event,
    ),
  );
  return nextState;
}

CodexSessionState _withUpdatedGlobalConnectionStatusImpl(
  CodexSessionState state,
  CodexRuntimeSessionState nextStatus,
) {
  final nextTimelines = <String, CodexTimelineState>{};
  for (final entry in state.timelinesByThreadId.entries) {
    nextTimelines[entry.key] = entry.value.copyWith(
      connectionStatus: nextStatus,
    );
  }
  return state.copyWith(
    connectionStatus: nextStatus,
    timelinesByThreadId: nextTimelines,
  );
}

String? _targetThreadIdForEventImpl(
  CodexSessionState state,
  CodexRuntimeEvent event,
) {
  final eventThreadId = event.threadId;
  if (eventThreadId != null && eventThreadId.isNotEmpty) {
    return eventThreadId;
  }

  if (event.requestId case final requestId? when requestId.isNotEmpty) {
    final ownerThreadId = state.requestOwnerById[requestId];
    if (ownerThreadId != null && ownerThreadId.isNotEmpty) {
      return ownerThreadId;
    }
  }

  return state.rootThreadId ?? state.currentThreadId;
}

Map<String, String> _rebuildRequestOwnerByIdImpl(
  Map<String, CodexTimelineState> timelinesByThreadId,
) {
  final owners = <String, String>{};
  for (final entry in timelinesByThreadId.entries) {
    for (final requestId in entry.value.pendingApprovalRequests.keys) {
      owners[requestId] = entry.key;
    }
    for (final requestId in entry.value.pendingUserInputRequests.keys) {
      owners[requestId] = entry.key;
    }
  }
  return owners;
}
