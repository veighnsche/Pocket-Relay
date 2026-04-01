part of 'transcript_reducer.dart';

TranscriptSessionState _reduceSessionExitedImpl(
  TranscriptReducer reducer,
  TranscriptSessionState state,
  TranscriptRuntimeSessionExitedEvent event,
) {
  var nextState = state.copyWith(
    connectionStatus: event.exitKind == TranscriptRuntimeSessionExitKind.error
        ? TranscriptRuntimeSessionState.error
        : TranscriptRuntimeSessionState.stopped,
  );

  final orderedThreadIds = nextState.timelinesByThreadId.keys.toList(
    growable: false,
  );
  for (final threadId in orderedThreadIds) {
    nextState = _reduceTimelineStateImpl(
      reducer,
      nextState,
      threadId: threadId,
      event: event,
      reducerFn: (projectedState) => _reduceSessionTranscriptRuntimeEventImpl(
        reducer,
        projectedState,
        event,
      ),
      lifecycleOverride: TranscriptAgentLifecycleState.closed,
    );
  }

  final nextRegistry = <String, TranscriptThreadRegistryEntry>{};
  for (final entry in nextState.threadRegistry.entries) {
    nextRegistry[entry.key] = entry.value.copyWith(isClosed: true);
  }
  return nextState.copyWith(threadRegistry: nextRegistry);
}

TranscriptSessionState _upsertThreadStartedImpl(
  TranscriptSessionState state,
  TranscriptRuntimeThreadStartedEvent event,
) {
  final threadId = event.providerThreadId;
  final nextTimelines = <String, TranscriptTimelineState>{
    ...state.timelinesByThreadId,
  };
  final existingTimeline = nextTimelines[threadId];
  nextTimelines[threadId] =
      existingTimeline ??
      TranscriptTimelineState(
        threadId: threadId,
        connectionStatus: state.connectionStatus,
        lifecycleState: TranscriptAgentLifecycleState.idle,
      );

  final nextRegistry = <String, TranscriptThreadRegistryEntry>{
    ...state.threadRegistry,
  };
  nextRegistry[threadId] = _upsertRegistryEntryImpl(
    nextRegistry[threadId],
    threadId: threadId,
    isPrimary: state.rootThreadId == null
        ? true
        : nextRegistry[threadId]?.isPrimary == true,
    threadName: event.threadName,
    sourceKind: event.sourceKind,
    agentNickname: event.agentNickname,
    agentRole: event.agentRole,
    isClosed: false,
    parentThreadId: nextRegistry[threadId]?.parentThreadId,
    spawnItemId: nextRegistry[threadId]?.spawnItemId,
    displayOrder:
        nextRegistry[threadId]?.displayOrder ??
        (state.rootThreadId == null ? 0 : _nextDisplayOrderImpl(nextRegistry)),
    childThreadIds: nextRegistry[threadId]?.childThreadIds,
  );

  return state.copyWith(
    connectionStatus: state.connectionStatus,
    rootThreadId: state.rootThreadId ?? threadId,
    selectedThreadId: state.selectedThreadId ?? threadId,
    timelinesByThreadId: nextTimelines,
    threadRegistry: nextRegistry,
    requestOwnerById: _rebuildRequestOwnerByIdImpl(nextTimelines),
  );
}

TranscriptSessionState _reduceThreadStateChangedImpl(
  TranscriptReducer reducer,
  TranscriptSessionState state,
  TranscriptRuntimeThreadStateChangedEvent event,
) {
  final threadId = event.threadId;
  if (threadId == null || threadId.isEmpty) {
    return state;
  }

  if (event.state == TranscriptRuntimeThreadState.closed) {
    final nextState = _reduceTimelineStateImpl(
      reducer,
      state,
      threadId: threadId,
      event: event,
      reducerFn: (projectedState) => _reduceSessionTranscriptRuntimeEventImpl(
        reducer,
        projectedState,
        event,
      ),
      lifecycleOverride: TranscriptAgentLifecycleState.closed,
    );
    final nextRegistry = <String, TranscriptThreadRegistryEntry>{
      ...nextState.threadRegistry,
    };
    final existingEntry = nextRegistry[threadId];
    if (existingEntry != null) {
      nextRegistry[threadId] = existingEntry.copyWith(isClosed: true);
    }
    return nextState.copyWith(threadRegistry: nextRegistry);
  }

  final nextTimelines = <String, TranscriptTimelineState>{
    ...state.timelinesByThreadId,
  };
  final timeline =
      nextTimelines[threadId] ??
      TranscriptTimelineState(
        threadId: threadId,
        connectionStatus: state.connectionStatus,
      );
  nextTimelines[threadId] = timeline.copyWith(
    lifecycleState: _lifecycleForThreadStateImpl(
      event.state,
      fallback: timeline.lifecycleState,
    ),
  );

  return state.copyWith(
    timelinesByThreadId: nextTimelines,
    requestOwnerById: _rebuildRequestOwnerByIdImpl(nextTimelines),
  );
}

TranscriptSessionState _promoteSessionTranscriptToWorkspaceImpl(
  TranscriptSessionState state,
  TranscriptRuntimeThreadStartedEvent event,
) {
  final rootThreadId = event.providerThreadId;
  final rootTimeline = TranscriptTimelineState(
    threadId: rootThreadId,
    connectionStatus: state.connectionStatus,
    lifecycleState: state.activeTurn == null
        ? TranscriptAgentLifecycleState.idle
        : TranscriptAgentLifecycleState.running,
    activeTurn: state.activeTurn?.copyWith(threadId: rootThreadId),
    blocks: state.blocks,
    pendingLocalUserMessageBlockIds: state.pendingLocalUserMessageBlockIds,
    localUserMessageProviderBindings: state.localUserMessageProviderBindings,
  );
  final threadRegistry = <String, TranscriptThreadRegistryEntry>{
    rootThreadId: TranscriptThreadRegistryEntry(
      threadId: rootThreadId,
      displayOrder: 0,
      threadName: event.threadName,
      agentNickname: event.agentNickname,
      agentRole: event.agentRole,
      sourceKind: event.sourceKind,
      isPrimary: true,
    ),
  };
  final timelinesByThreadId = <String, TranscriptTimelineState>{
    rootThreadId: rootTimeline,
  };

  return TranscriptSessionState(
    connectionStatus: state.connectionStatus,
    rootThreadId: rootThreadId,
    selectedThreadId: rootThreadId,
    timelinesByThreadId: timelinesByThreadId,
    threadRegistry: threadRegistry,
    requestOwnerById: _rebuildRequestOwnerByIdImpl(timelinesByThreadId),
    headerMetadata: state.headerMetadata,
  );
}

TranscriptSessionState _applyCollaborationMetadataImpl(
  TranscriptSessionState state,
  TranscriptRuntimeEvent event, {
  required String targetThreadId,
}) {
  final collaboration = switch (event) {
    TranscriptRuntimeItemLifecycleEvent(:final collaboration) => collaboration,
    _ => null,
  };
  if (collaboration == null) {
    return state;
  }

  final nextRegistry = <String, TranscriptThreadRegistryEntry>{
    ...state.threadRegistry,
  };
  final nextTimelines = <String, TranscriptTimelineState>{
    ...state.timelinesByThreadId,
  };

  final senderThreadId = collaboration.senderThreadId;
  final senderEntry = _upsertRegistryEntryImpl(
    nextRegistry[senderThreadId],
    threadId: senderThreadId,
    isPrimary: state.rootThreadId == senderThreadId,
    threadName: nextRegistry[senderThreadId]?.threadName,
    sourceKind: nextRegistry[senderThreadId]?.sourceKind,
    agentNickname: nextRegistry[senderThreadId]?.agentNickname,
    agentRole: nextRegistry[senderThreadId]?.agentRole,
    isClosed: nextRegistry[senderThreadId]?.isClosed ?? false,
    parentThreadId: nextRegistry[senderThreadId]?.parentThreadId,
    spawnItemId: nextRegistry[senderThreadId]?.spawnItemId,
    displayOrder:
        nextRegistry[senderThreadId]?.displayOrder ??
        (state.rootThreadId == senderThreadId
            ? 0
            : _nextDisplayOrderImpl(nextRegistry)),
    childThreadIds: _mergedChildThreadIdsImpl(
      nextRegistry[senderThreadId]?.childThreadIds,
      collaboration.receiverThreadIds,
    ),
  );
  nextRegistry[senderThreadId] = senderEntry;

  for (final receiverThreadId in collaboration.receiverThreadIds) {
    final existingEntry = nextRegistry[receiverThreadId];
    nextRegistry[receiverThreadId] = _upsertRegistryEntryImpl(
      existingEntry,
      threadId: receiverThreadId,
      isPrimary: false,
      threadName: existingEntry?.threadName,
      sourceKind: existingEntry?.sourceKind,
      agentNickname: existingEntry?.agentNickname,
      agentRole: existingEntry?.agentRole,
      isClosed: existingEntry?.isClosed ?? false,
      parentThreadId: senderThreadId,
      spawnItemId: event.itemId,
      displayOrder:
          existingEntry?.displayOrder ?? _nextDisplayOrderImpl(nextRegistry),
      childThreadIds: existingEntry?.childThreadIds,
    );

    final existingTimeline = nextTimelines[receiverThreadId];
    nextTimelines[receiverThreadId] =
        existingTimeline ??
        TranscriptTimelineState(
          threadId: receiverThreadId,
          connectionStatus: state.connectionStatus,
          lifecycleState: _lifecycleFromCollaborationImpl(
            collaboration,
            receiverThreadId,
          ),
        );
    if (existingTimeline != null) {
      nextTimelines[receiverThreadId] = existingTimeline.copyWith(
        lifecycleState: _lifecycleFromCollaborationImpl(
          collaboration,
          receiverThreadId,
        ),
      );
    }
  }

  final targetTimeline = nextTimelines[targetThreadId];
  if (collaboration.tool == TranscriptRuntimeCollabAgentTool.wait &&
      collaboration.status ==
          TranscriptRuntimeCollabAgentToolCallStatus.inProgress &&
      targetTimeline != null) {
    nextTimelines[targetThreadId] = targetTimeline.copyWith(
      lifecycleState: TranscriptAgentLifecycleState.waitingOnChild,
    );
  }

  return state.copyWith(
    timelinesByThreadId: nextTimelines,
    threadRegistry: nextRegistry,
    requestOwnerById: _rebuildRequestOwnerByIdImpl(nextTimelines),
  );
}
