part of 'transcript_reducer.dart';

TranscriptSessionState _reduceTimelineStateImpl(
  TranscriptReducer reducer,
  TranscriptSessionState state, {
  required String threadId,
  required TranscriptRuntimeEvent? event,
  required TranscriptSessionState Function(
    TranscriptSessionState projectedState,
  )
  reducerFn,
  TranscriptAgentLifecycleState? lifecycleOverride,
}) {
  final existingTimeline =
      state.timelineForThread(threadId) ??
      TranscriptTimelineState(
        threadId: threadId,
        connectionStatus: state.connectionStatus,
        lifecycleState: TranscriptAgentLifecycleState.starting,
      );
  final projectedState = TranscriptSessionState.transcript(
    connectionStatus: existingTimeline.connectionStatus,
    threadId: existingTimeline.threadId,
    activeTurn: existingTimeline.activeTurn,
    blocks: existingTimeline.blocks,
    pendingLocalUserMessageBlockIds:
        existingTimeline.pendingLocalUserMessageBlockIds,
    localUserMessageProviderBindings:
        existingTimeline.localUserMessageProviderBindings,
    headerMetadata: state.headerMetadata,
  );
  final reducedProjectedState = reducerFn(projectedState);
  final nextTimelines = <String, TranscriptTimelineState>{
    ...state.timelinesByThreadId,
    threadId: existingTimeline.copyWith(
      connectionStatus: reducedProjectedState.connectionStatus,
      lifecycleState:
          lifecycleOverride ??
          _inferLifecycleStateImpl(
            existingTimeline,
            reducedProjectedState,
            event,
          ),
      activeTurn: reducedProjectedState.activeTurn,
      clearActiveTurn: reducedProjectedState.activeTurn == null,
      blocks: reducedProjectedState.blocks,
      pendingLocalUserMessageBlockIds:
          reducedProjectedState.pendingLocalUserMessageBlockIds,
      localUserMessageProviderBindings:
          reducedProjectedState.localUserMessageProviderBindings,
      hasUnreadActivity: threadId == state.currentThreadId ? false : true,
    ),
  };

  return state.copyWith(
    connectionStatus: reducedProjectedState.connectionStatus,
    timelinesByThreadId: nextTimelines,
    requestOwnerById: _rebuildRequestOwnerByIdImpl(nextTimelines),
    headerMetadata: reducedProjectedState.headerMetadata,
  );
}
