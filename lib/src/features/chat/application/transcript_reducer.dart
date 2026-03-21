import 'package:pocket_relay/src/features/chat/application/transcript_policy.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';

class TranscriptReducer {
  const TranscriptReducer({
    TranscriptPolicy policy = const TranscriptPolicy(),
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
  }) : _policy = policy,
       _support = support;

  final TranscriptPolicy _policy;
  final TranscriptPolicySupport _support;

  CodexSessionState addUserMessage(
    CodexSessionState state, {
    required String text,
    DateTime? createdAt,
  }) {
    final rootThreadId = state.rootThreadId;
    if (rootThreadId == null) {
      return _policy.addUserMessage(state, text: text, createdAt: createdAt);
    }

    return _reduceTimelineState(
      state,
      threadId: rootThreadId,
      event: null,
      reducer: (projectedState) => _policy.addUserMessage(
        projectedState,
        text: text,
        createdAt: createdAt,
      ),
      lifecycleOverride: CodexAgentLifecycleState.running,
    );
  }

  CodexSessionState startFreshThread(
    CodexSessionState state, {
    String? message,
    DateTime? createdAt,
  }) {
    final cleared = _policy.startFreshThread(
      CodexSessionState.transcript(connectionStatus: state.connectionStatus),
      message: message,
      createdAt: createdAt,
    );
    return cleared;
  }

  CodexSessionState clearTranscript(CodexSessionState state) {
    return _policy.clearTranscript(
      CodexSessionState.transcript(connectionStatus: state.connectionStatus),
    );
  }

  CodexSessionState detachThread(CodexSessionState state) {
    return _policy.detachThread(
      CodexSessionState.transcript(connectionStatus: state.connectionStatus),
    );
  }

  CodexSessionState clearLocalUserMessageCorrelationState(
    CodexSessionState state,
  ) {
    final targetThreadId = state.rootThreadId;
    if (targetThreadId == null) {
      return _policy.clearLocalUserMessageCorrelationState(state);
    }
    return _reduceTimelineState(
      state,
      threadId: targetThreadId,
      event: null,
      reducer: _policy.clearLocalUserMessageCorrelationState,
    );
  }

  CodexSessionState markUnpinnedHostKeySaved(
    CodexSessionState state, {
    required String blockId,
  }) {
    final targetThreadId = state.currentThreadId;
    if (state.rootThreadId == null || targetThreadId == null) {
      return _policy.markUnpinnedHostKeySaved(state, blockId: blockId);
    }
    return _reduceTimelineState(
      state,
      threadId: targetThreadId,
      event: null,
      reducer: (projectedState) =>
          _policy.markUnpinnedHostKeySaved(projectedState, blockId: blockId),
    );
  }

  CodexSessionState reduceRuntimeEvent(
    CodexSessionState state,
    CodexRuntimeEvent event,
  ) {
    if (state.rootThreadId == null) {
      final nextState = _reduceSessionTranscriptRuntimeEvent(state, event);
      if (event is CodexRuntimeThreadStartedEvent) {
        return _promoteSessionTranscriptToWorkspace(nextState, event);
      }
      return nextState;
    }

    return _reduceWorkspaceRuntimeEvent(state, event);
  }

  CodexSessionState _reduceSessionTranscriptRuntimeEvent(
    CodexSessionState state,
    CodexRuntimeEvent event,
  ) {
    final normalizedState = _normalizeTurnState(state, event);
    switch (event) {
      case CodexRuntimeSessionStateChangedEvent():
        return normalizedState.copyWith(connectionStatus: event.state);
      case CodexRuntimeSessionExitedEvent():
        return _policy.applySessionExited(normalizedState, event);
      case CodexRuntimeThreadStartedEvent():
        return normalizedState.copyWithProjectedTranscript(
          threadId: event.providerThreadId,
        );
      case CodexRuntimeThreadStateChangedEvent():
        final isClosed = event.state == CodexRuntimeThreadState.closed;
        if (!isClosed) {
          return normalizedState;
        }
        return _policy.applyThreadClosed(normalizedState, event);
      case CodexRuntimeTurnStartedEvent():
        final nextActiveTurn = _support.activeTurnForStartedEvent(
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
        return _withUpdatedHeaderMetadataForTurnStarted(nextState, event);
      case CodexRuntimeTurnCompletedEvent():
        return _policy.applyTurnCompleted(normalizedState, event);
      case CodexRuntimeTurnAbortedEvent():
        return _policy.applyTurnAborted(normalizedState, event);
      case CodexRuntimeTurnPlanUpdatedEvent():
        return _policy.applyTurnPlanUpdated(normalizedState, event);
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
      case CodexRuntimeSshConnectFailedEvent():
        return _policy.applySshConnectFailed(normalizedState, event);
      case CodexRuntimeUnpinnedHostKeyEvent():
        return _policy.applyUnpinnedHostKey(normalizedState, event);
      case CodexRuntimeSshHostKeyMismatchEvent():
        return _policy.applySshHostKeyMismatch(normalizedState, event);
      case CodexRuntimeSshAuthenticationFailedEvent():
        return _policy.applySshAuthenticationFailed(normalizedState, event);
      case CodexRuntimeSshAuthenticatedEvent():
        return normalizedState;
      case CodexRuntimeSshRemoteLaunchFailedEvent():
        return _policy.applySshRemoteLaunchFailed(normalizedState, event);
      case CodexRuntimeSshRemoteProcessStartedEvent():
        return normalizedState;
      case CodexRuntimeStatusEvent():
        return _policy.applyStatus(normalizedState, event);
      case CodexRuntimeErrorEvent():
        return _policy.applyRuntimeError(normalizedState, event);
    }
  }

  CodexSessionState _reduceWorkspaceRuntimeEvent(
    CodexSessionState state,
    CodexRuntimeEvent event,
  ) {
    switch (event) {
      case CodexRuntimeSessionStateChangedEvent():
        return _withUpdatedGlobalConnectionStatus(state, event.state);
      case CodexRuntimeSessionExitedEvent():
        return _reduceSessionExited(state, event);
      case CodexRuntimeThreadStartedEvent():
        return _upsertThreadStarted(state, event);
      case CodexRuntimeThreadStateChangedEvent():
        return _reduceThreadStateChanged(state, event);
      case CodexRuntimeSshAuthenticatedEvent() ||
          CodexRuntimeSshRemoteProcessStartedEvent():
        return state;
      default:
        break;
    }

    final targetThreadId = _targetThreadIdForEvent(state, event);
    if (targetThreadId == null) {
      return switch (event) {
        CodexRuntimeStatusEvent() => state,
        CodexRuntimeErrorEvent() => state,
        _ => state,
      };
    }

    var nextState = _applyCollaborationMetadata(
      state,
      event,
      targetThreadId: targetThreadId,
    );
    nextState = _reduceTimelineState(
      nextState,
      threadId: targetThreadId,
      event: event,
      reducer: (projectedState) =>
          _reduceSessionTranscriptRuntimeEvent(projectedState, event),
      lifecycleOverride: _lifecycleOverrideForEvent(
        nextState.timelineForThread(targetThreadId),
        event,
      ),
    );
    return nextState;
  }

  CodexSessionState _withUpdatedGlobalConnectionStatus(
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

  CodexSessionState _reduceSessionExited(
    CodexSessionState state,
    CodexRuntimeSessionExitedEvent event,
  ) {
    var nextState = state.copyWith(
      connectionStatus: event.exitKind == CodexRuntimeSessionExitKind.error
          ? CodexRuntimeSessionState.error
          : CodexRuntimeSessionState.stopped,
    );

    final orderedThreadIds = nextState.timelinesByThreadId.keys.toList(
      growable: false,
    );
    for (final threadId in orderedThreadIds) {
      nextState = _reduceTimelineState(
        nextState,
        threadId: threadId,
        event: event,
        reducer: (projectedState) =>
            _reduceSessionTranscriptRuntimeEvent(projectedState, event),
        lifecycleOverride: CodexAgentLifecycleState.closed,
      );
    }

    final nextRegistry = <String, CodexThreadRegistryEntry>{};
    for (final entry in nextState.threadRegistry.entries) {
      nextRegistry[entry.key] = entry.value.copyWith(isClosed: true);
    }
    return nextState.copyWith(threadRegistry: nextRegistry);
  }

  CodexSessionState _upsertThreadStarted(
    CodexSessionState state,
    CodexRuntimeThreadStartedEvent event,
  ) {
    final threadId = event.providerThreadId;
    final nextTimelines = <String, CodexTimelineState>{
      ...state.timelinesByThreadId,
    };
    final existingTimeline = nextTimelines[threadId];
    nextTimelines[threadId] =
        existingTimeline ??
        CodexTimelineState(
          threadId: threadId,
          connectionStatus: state.connectionStatus,
          lifecycleState: CodexAgentLifecycleState.idle,
        );

    final nextRegistry = <String, CodexThreadRegistryEntry>{
      ...state.threadRegistry,
    };
    nextRegistry[threadId] = _upsertRegistryEntry(
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
          (state.rootThreadId == null ? 0 : _nextDisplayOrder(nextRegistry)),
      childThreadIds: nextRegistry[threadId]?.childThreadIds,
    );

    return state.copyWith(
      connectionStatus: state.connectionStatus,
      rootThreadId: state.rootThreadId ?? threadId,
      selectedThreadId: state.selectedThreadId ?? threadId,
      timelinesByThreadId: nextTimelines,
      threadRegistry: nextRegistry,
      requestOwnerById: _rebuildRequestOwnerById(nextTimelines),
    );
  }

  CodexSessionState _reduceThreadStateChanged(
    CodexSessionState state,
    CodexRuntimeThreadStateChangedEvent event,
  ) {
    final threadId = event.threadId;
    if (threadId == null || threadId.isEmpty) {
      return state;
    }

    if (event.state == CodexRuntimeThreadState.closed) {
      final nextState = _reduceTimelineState(
        state,
        threadId: threadId,
        event: event,
        reducer: (projectedState) =>
            _reduceSessionTranscriptRuntimeEvent(projectedState, event),
        lifecycleOverride: CodexAgentLifecycleState.closed,
      );
      final nextRegistry = <String, CodexThreadRegistryEntry>{
        ...nextState.threadRegistry,
      };
      final existingEntry = nextRegistry[threadId];
      if (existingEntry != null) {
        nextRegistry[threadId] = existingEntry.copyWith(isClosed: true);
      }
      return nextState.copyWith(threadRegistry: nextRegistry);
    }

    final nextTimelines = <String, CodexTimelineState>{
      ...state.timelinesByThreadId,
    };
    final timeline =
        nextTimelines[threadId] ??
        CodexTimelineState(
          threadId: threadId,
          connectionStatus: state.connectionStatus,
        );
    nextTimelines[threadId] = timeline.copyWith(
      lifecycleState: _lifecycleForThreadState(
        event.state,
        fallback: timeline.lifecycleState,
      ),
    );

    return state.copyWith(
      timelinesByThreadId: nextTimelines,
      requestOwnerById: _rebuildRequestOwnerById(nextTimelines),
    );
  }

  CodexSessionState _reduceTimelineState(
    CodexSessionState state, {
    required String threadId,
    required CodexRuntimeEvent? event,
    required CodexSessionState Function(CodexSessionState projectedState)
    reducer,
    CodexAgentLifecycleState? lifecycleOverride,
  }) {
    final existingTimeline =
        state.timelineForThread(threadId) ??
        CodexTimelineState(
          threadId: threadId,
          connectionStatus: state.connectionStatus,
          lifecycleState: CodexAgentLifecycleState.starting,
        );
    final projectedState = CodexSessionState.transcript(
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
    final reducedProjectedState = reducer(projectedState);
    final nextTimelines = <String, CodexTimelineState>{
      ...state.timelinesByThreadId,
      threadId: existingTimeline.copyWith(
        connectionStatus: reducedProjectedState.connectionStatus,
        lifecycleState:
            lifecycleOverride ??
            _inferLifecycleState(
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
      requestOwnerById: _rebuildRequestOwnerById(nextTimelines),
      headerMetadata: reducedProjectedState.headerMetadata,
    );
  }

  CodexSessionState _promoteSessionTranscriptToWorkspace(
    CodexSessionState state,
    CodexRuntimeThreadStartedEvent event,
  ) {
    final rootThreadId = event.providerThreadId;
    final rootTimeline = CodexTimelineState(
      threadId: rootThreadId,
      connectionStatus: state.connectionStatus,
      lifecycleState: state.activeTurn == null
          ? CodexAgentLifecycleState.idle
          : CodexAgentLifecycleState.running,
      activeTurn: state.activeTurn?.copyWith(threadId: rootThreadId),
      blocks: state.blocks,
      pendingLocalUserMessageBlockIds: state.pendingLocalUserMessageBlockIds,
      localUserMessageProviderBindings: state.localUserMessageProviderBindings,
    );
    final threadRegistry = <String, CodexThreadRegistryEntry>{
      rootThreadId: CodexThreadRegistryEntry(
        threadId: rootThreadId,
        displayOrder: 0,
        threadName: event.threadName,
        agentNickname: event.agentNickname,
        agentRole: event.agentRole,
        sourceKind: event.sourceKind,
        isPrimary: true,
      ),
    };
    final timelinesByThreadId = <String, CodexTimelineState>{
      rootThreadId: rootTimeline,
    };

    return CodexSessionState(
      connectionStatus: state.connectionStatus,
      rootThreadId: rootThreadId,
      selectedThreadId: rootThreadId,
      timelinesByThreadId: timelinesByThreadId,
      threadRegistry: threadRegistry,
      requestOwnerById: _rebuildRequestOwnerById(timelinesByThreadId),
      headerMetadata: state.headerMetadata,
    );
  }

  CodexSessionState _withUpdatedHeaderMetadataForTurnStarted(
    CodexSessionState state,
    CodexRuntimeTurnStartedEvent event,
  ) {
    if (!_shouldUpdateHeaderMetadataForThread(state, event.threadId)) {
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

  bool _shouldUpdateHeaderMetadataForThread(
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

  CodexSessionState _applyCollaborationMetadata(
    CodexSessionState state,
    CodexRuntimeEvent event, {
    required String targetThreadId,
  }) {
    final collaboration = switch (event) {
      CodexRuntimeItemLifecycleEvent(:final collaboration) => collaboration,
      _ => null,
    };
    if (collaboration == null) {
      return state;
    }

    final nextRegistry = <String, CodexThreadRegistryEntry>{
      ...state.threadRegistry,
    };
    final nextTimelines = <String, CodexTimelineState>{
      ...state.timelinesByThreadId,
    };

    final senderThreadId = collaboration.senderThreadId;
    final senderEntry = _upsertRegistryEntry(
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
              : _nextDisplayOrder(nextRegistry)),
      childThreadIds: _mergedChildThreadIds(
        nextRegistry[senderThreadId]?.childThreadIds,
        collaboration.receiverThreadIds,
      ),
    );
    nextRegistry[senderThreadId] = senderEntry;

    for (final receiverThreadId in collaboration.receiverThreadIds) {
      final existingEntry = nextRegistry[receiverThreadId];
      nextRegistry[receiverThreadId] = _upsertRegistryEntry(
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
            existingEntry?.displayOrder ?? _nextDisplayOrder(nextRegistry),
        childThreadIds: existingEntry?.childThreadIds,
      );

      final existingTimeline = nextTimelines[receiverThreadId];
      nextTimelines[receiverThreadId] =
          existingTimeline ??
          CodexTimelineState(
            threadId: receiverThreadId,
            connectionStatus: state.connectionStatus,
            lifecycleState: _lifecycleFromCollaboration(
              collaboration,
              receiverThreadId,
            ),
          );
      if (existingTimeline != null) {
        nextTimelines[receiverThreadId] = existingTimeline.copyWith(
          lifecycleState: _lifecycleFromCollaboration(
            collaboration,
            receiverThreadId,
          ),
        );
      }
    }

    final targetTimeline = nextTimelines[targetThreadId];
    if (collaboration.tool == CodexRuntimeCollabAgentTool.wait &&
        collaboration.status ==
            CodexRuntimeCollabAgentToolCallStatus.inProgress &&
        targetTimeline != null) {
      nextTimelines[targetThreadId] = targetTimeline.copyWith(
        lifecycleState: CodexAgentLifecycleState.waitingOnChild,
      );
    }

    return state.copyWith(
      timelinesByThreadId: nextTimelines,
      threadRegistry: nextRegistry,
      requestOwnerById: _rebuildRequestOwnerById(nextTimelines),
    );
  }

  String? _targetThreadIdForEvent(
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

  CodexAgentLifecycleState? _lifecycleOverrideForEvent(
    CodexTimelineState? timeline,
    CodexRuntimeEvent event,
  ) {
    return switch (event) {
      CodexRuntimeTurnStartedEvent() => CodexAgentLifecycleState.running,
      CodexRuntimeTurnCompletedEvent(:final state) => switch (state) {
        CodexRuntimeTurnState.completed => CodexAgentLifecycleState.completed,
        CodexRuntimeTurnState.failed => CodexAgentLifecycleState.failed,
        CodexRuntimeTurnState.interrupted ||
        CodexRuntimeTurnState.cancelled => CodexAgentLifecycleState.aborted,
      },
      CodexRuntimeTurnAbortedEvent() => CodexAgentLifecycleState.aborted,
      CodexRuntimeRequestOpenedEvent(:final requestType) =>
        requestType == CodexCanonicalRequestType.toolUserInput ||
                requestType == CodexCanonicalRequestType.mcpServerElicitation
            ? CodexAgentLifecycleState.blockedOnInput
            : CodexAgentLifecycleState.blockedOnApproval,
      CodexRuntimeUserInputRequestedEvent() =>
        CodexAgentLifecycleState.blockedOnInput,
      CodexRuntimeThreadStateChangedEvent(:final state) =>
        _lifecycleForThreadState(
          state,
          fallback:
              timeline?.lifecycleState ?? CodexAgentLifecycleState.unknown,
        ),
      CodexRuntimeItemLifecycleEvent(:final collaboration?) =>
        _lifecycleOverrideForCollaboration(timeline, collaboration),
      _ => null,
    };
  }

  CodexAgentLifecycleState _inferLifecycleState(
    CodexTimelineState existingTimeline,
    CodexSessionState reducedProjectedState,
    CodexRuntimeEvent? event,
  ) {
    final override = event == null
        ? null
        : _lifecycleOverrideForEvent(existingTimeline, event);
    if (override != null) {
      return override;
    }

    if (reducedProjectedState.pendingUserInputRequests.isNotEmpty) {
      return CodexAgentLifecycleState.blockedOnInput;
    }
    if (reducedProjectedState.pendingApprovalRequests.isNotEmpty) {
      return CodexAgentLifecycleState.blockedOnApproval;
    }
    if (reducedProjectedState.activeTurn != null) {
      return switch (existingTimeline.lifecycleState) {
        CodexAgentLifecycleState.waitingOnChild =>
          CodexAgentLifecycleState.waitingOnChild,
        _ => CodexAgentLifecycleState.running,
      };
    }
    return switch (existingTimeline.lifecycleState) {
      CodexAgentLifecycleState.completed ||
      CodexAgentLifecycleState.failed ||
      CodexAgentLifecycleState.aborted ||
      CodexAgentLifecycleState.closed => existingTimeline.lifecycleState,
      _ => CodexAgentLifecycleState.idle,
    };
  }

  CodexAgentLifecycleState _lifecycleForThreadState(
    CodexRuntimeThreadState threadState, {
    required CodexAgentLifecycleState fallback,
  }) {
    return switch (threadState) {
      CodexRuntimeThreadState.active => CodexAgentLifecycleState.running,
      CodexRuntimeThreadState.idle => CodexAgentLifecycleState.idle,
      CodexRuntimeThreadState.archived => fallback,
      CodexRuntimeThreadState.closed => CodexAgentLifecycleState.closed,
      CodexRuntimeThreadState.compacted => fallback,
      CodexRuntimeThreadState.error => CodexAgentLifecycleState.failed,
    };
  }

  CodexAgentLifecycleState _lifecycleFromCollaboration(
    CodexRuntimeCollabAgentToolCall collaboration,
    String receiverThreadId,
  ) {
    final agentState = collaboration.agentsStates[receiverThreadId];
    if (agentState != null) {
      return switch (agentState.status) {
        CodexRuntimeCollabAgentStatus.pendingInit =>
          CodexAgentLifecycleState.starting,
        CodexRuntimeCollabAgentStatus.running =>
          CodexAgentLifecycleState.running,
        CodexRuntimeCollabAgentStatus.completed =>
          CodexAgentLifecycleState.completed,
        CodexRuntimeCollabAgentStatus.errored ||
        CodexRuntimeCollabAgentStatus.notFound =>
          CodexAgentLifecycleState.failed,
        CodexRuntimeCollabAgentStatus.shutdown =>
          CodexAgentLifecycleState.closed,
        CodexRuntimeCollabAgentStatus.unknown =>
          CodexAgentLifecycleState.unknown,
      };
    }

    return switch (collaboration.tool) {
      CodexRuntimeCollabAgentTool.spawnAgent =>
        collaboration.status == CodexRuntimeCollabAgentToolCallStatus.failed
            ? CodexAgentLifecycleState.failed
            : CodexAgentLifecycleState.starting,
      CodexRuntimeCollabAgentTool.closeAgent =>
        collaboration.status == CodexRuntimeCollabAgentToolCallStatus.completed
            ? CodexAgentLifecycleState.closed
            : CodexAgentLifecycleState.running,
      CodexRuntimeCollabAgentTool.resumeAgent ||
      CodexRuntimeCollabAgentTool.sendInput => CodexAgentLifecycleState.running,
      CodexRuntimeCollabAgentTool.wait => CodexAgentLifecycleState.running,
      CodexRuntimeCollabAgentTool.unknown => CodexAgentLifecycleState.unknown,
    };
  }

  CodexAgentLifecycleState? _lifecycleOverrideForCollaboration(
    CodexTimelineState? timeline,
    CodexRuntimeCollabAgentToolCall? collaboration,
  ) {
    if (collaboration == null) {
      return null;
    }

    return switch (collaboration.tool) {
      CodexRuntimeCollabAgentTool.wait => switch (collaboration.status) {
        CodexRuntimeCollabAgentToolCallStatus.inProgress =>
          CodexAgentLifecycleState.waitingOnChild,
        CodexRuntimeCollabAgentToolCallStatus.completed ||
        CodexRuntimeCollabAgentToolCallStatus.failed ||
        CodexRuntimeCollabAgentToolCallStatus.unknown => _activeOrIdleLifecycle(
          timeline,
        ),
      },
      CodexRuntimeCollabAgentTool.spawnAgent ||
      CodexRuntimeCollabAgentTool.resumeAgent ||
      CodexRuntimeCollabAgentTool.sendInput ||
      CodexRuntimeCollabAgentTool.closeAgent => _activeOrIdleLifecycle(
        timeline,
      ),
      CodexRuntimeCollabAgentTool.unknown => null,
    };
  }

  CodexAgentLifecycleState _activeOrIdleLifecycle(
    CodexTimelineState? timeline,
  ) {
    return timeline?.activeTurn != null
        ? CodexAgentLifecycleState.running
        : CodexAgentLifecycleState.idle;
  }

  CodexThreadRegistryEntry _upsertRegistryEntry(
    CodexThreadRegistryEntry? existing, {
    required String threadId,
    required int displayOrder,
    required bool isPrimary,
    required String? threadName,
    required String? sourceKind,
    required String? agentNickname,
    required String? agentRole,
    required bool isClosed,
    required String? parentThreadId,
    required String? spawnItemId,
    required List<String>? childThreadIds,
  }) {
    return (existing ??
            CodexThreadRegistryEntry(
              threadId: threadId,
              displayOrder: displayOrder,
            ))
        .copyWith(
          displayOrder: displayOrder,
          isPrimary: isPrimary,
          threadName: threadName,
          sourceKind: sourceKind,
          agentNickname: agentNickname,
          agentRole: agentRole,
          isClosed: isClosed,
          parentThreadId: parentThreadId,
          spawnItemId: spawnItemId,
          childThreadIds: childThreadIds,
        );
  }

  int _nextDisplayOrder(Map<String, CodexThreadRegistryEntry> registry) {
    var maxOrder = -1;
    for (final entry in registry.values) {
      if (entry.displayOrder > maxOrder) {
        maxOrder = entry.displayOrder;
      }
    }
    return maxOrder + 1;
  }

  List<String> _mergedChildThreadIds(
    List<String>? existingChildThreadIds,
    List<String> nextChildThreadIds,
  ) {
    final merged = <String>{...?existingChildThreadIds, ...nextChildThreadIds};
    return merged.toList(growable: false);
  }

  Map<String, String> _rebuildRequestOwnerById(
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

  CodexSessionState _normalizeTurnState(
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
      CodexRuntimeSshAuthenticatedEvent() ||
      CodexRuntimeSshRemoteLaunchFailedEvent() ||
      CodexRuntimeSshRemoteProcessStartedEvent() => state,
      _ => _policy.rolloverTurnIfNeeded(
        state,
        turnId: event.turnId,
        threadId: event.threadId,
        createdAt: event.createdAt,
      ),
    };
  }
}
