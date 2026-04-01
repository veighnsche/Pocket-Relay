part of 'transcript_reducer.dart';

TranscriptAgentLifecycleState? _lifecycleOverrideForEventImpl(
  TranscriptTimelineState? timeline,
  TranscriptRuntimeEvent event,
) {
  return switch (event) {
    TranscriptRuntimeTurnStartedEvent() =>
      TranscriptAgentLifecycleState.running,
    TranscriptRuntimeTurnCompletedEvent(:final state) => switch (state) {
      TranscriptRuntimeTurnState.completed =>
        TranscriptAgentLifecycleState.completed,
      TranscriptRuntimeTurnState.failed => TranscriptAgentLifecycleState.failed,
      TranscriptRuntimeTurnState.interrupted ||
      TranscriptRuntimeTurnState.cancelled =>
        TranscriptAgentLifecycleState.aborted,
    },
    TranscriptRuntimeTurnAbortedEvent() =>
      TranscriptAgentLifecycleState.aborted,
    TranscriptRuntimeRequestOpenedEvent(:final requestType) =>
      requestType == TranscriptCanonicalRequestType.toolUserInput ||
              requestType == TranscriptCanonicalRequestType.mcpServerElicitation
          ? TranscriptAgentLifecycleState.blockedOnInput
          : TranscriptAgentLifecycleState.blockedOnApproval,
    TranscriptRuntimeUserInputRequestedEvent() =>
      TranscriptAgentLifecycleState.blockedOnInput,
    TranscriptRuntimeThreadStateChangedEvent(:final state) =>
      _lifecycleForThreadStateImpl(
        state,
        fallback:
            timeline?.lifecycleState ?? TranscriptAgentLifecycleState.unknown,
      ),
    TranscriptRuntimeItemLifecycleEvent(:final collaboration?) =>
      _lifecycleOverrideForCollaborationImpl(timeline, collaboration),
    _ => null,
  };
}

TranscriptAgentLifecycleState _inferLifecycleStateImpl(
  TranscriptTimelineState existingTimeline,
  TranscriptSessionState reducedProjectedState,
  TranscriptRuntimeEvent? event,
) {
  final override = event == null
      ? null
      : _lifecycleOverrideForEventImpl(existingTimeline, event);
  if (override != null) {
    return override;
  }

  if (reducedProjectedState.pendingUserInputRequests.isNotEmpty) {
    return TranscriptAgentLifecycleState.blockedOnInput;
  }
  if (reducedProjectedState.pendingApprovalRequests.isNotEmpty) {
    return TranscriptAgentLifecycleState.blockedOnApproval;
  }
  if (reducedProjectedState.activeTurn != null) {
    return switch (existingTimeline.lifecycleState) {
      TranscriptAgentLifecycleState.waitingOnChild =>
        TranscriptAgentLifecycleState.waitingOnChild,
      _ => TranscriptAgentLifecycleState.running,
    };
  }
  return switch (existingTimeline.lifecycleState) {
    TranscriptAgentLifecycleState.completed ||
    TranscriptAgentLifecycleState.failed ||
    TranscriptAgentLifecycleState.aborted ||
    TranscriptAgentLifecycleState.closed => existingTimeline.lifecycleState,
    _ => TranscriptAgentLifecycleState.idle,
  };
}

TranscriptAgentLifecycleState _lifecycleForThreadStateImpl(
  TranscriptRuntimeThreadState threadState, {
  required TranscriptAgentLifecycleState fallback,
}) {
  return switch (threadState) {
    TranscriptRuntimeThreadState.active =>
      TranscriptAgentLifecycleState.running,
    TranscriptRuntimeThreadState.idle => TranscriptAgentLifecycleState.idle,
    TranscriptRuntimeThreadState.archived => fallback,
    TranscriptRuntimeThreadState.closed => TranscriptAgentLifecycleState.closed,
    TranscriptRuntimeThreadState.compacted => fallback,
    TranscriptRuntimeThreadState.error => TranscriptAgentLifecycleState.failed,
  };
}

TranscriptAgentLifecycleState _lifecycleFromCollaborationImpl(
  TranscriptRuntimeCollabAgentToolCall collaboration,
  String receiverThreadId,
) {
  final agentState = collaboration.agentsStates[receiverThreadId];
  if (agentState != null) {
    return switch (agentState.status) {
      TranscriptRuntimeCollabAgentStatus.pendingInit =>
        TranscriptAgentLifecycleState.starting,
      TranscriptRuntimeCollabAgentStatus.running =>
        TranscriptAgentLifecycleState.running,
      TranscriptRuntimeCollabAgentStatus.completed =>
        TranscriptAgentLifecycleState.completed,
      TranscriptRuntimeCollabAgentStatus.errored ||
      TranscriptRuntimeCollabAgentStatus.notFound =>
        TranscriptAgentLifecycleState.failed,
      TranscriptRuntimeCollabAgentStatus.shutdown =>
        TranscriptAgentLifecycleState.closed,
      TranscriptRuntimeCollabAgentStatus.unknown =>
        TranscriptAgentLifecycleState.unknown,
    };
  }

  return switch (collaboration.tool) {
    TranscriptRuntimeCollabAgentTool.spawnAgent =>
      collaboration.status == TranscriptRuntimeCollabAgentToolCallStatus.failed
          ? TranscriptAgentLifecycleState.failed
          : TranscriptAgentLifecycleState.starting,
    TranscriptRuntimeCollabAgentTool.closeAgent =>
      collaboration.status ==
              TranscriptRuntimeCollabAgentToolCallStatus.completed
          ? TranscriptAgentLifecycleState.closed
          : TranscriptAgentLifecycleState.running,
    TranscriptRuntimeCollabAgentTool.resumeAgent ||
    TranscriptRuntimeCollabAgentTool.sendInput =>
      TranscriptAgentLifecycleState.running,
    TranscriptRuntimeCollabAgentTool.wait =>
      TranscriptAgentLifecycleState.running,
    TranscriptRuntimeCollabAgentTool.unknown =>
      TranscriptAgentLifecycleState.unknown,
  };
}

TranscriptAgentLifecycleState? _lifecycleOverrideForCollaborationImpl(
  TranscriptTimelineState? timeline,
  TranscriptRuntimeCollabAgentToolCall? collaboration,
) {
  if (collaboration == null) {
    return null;
  }

  return switch (collaboration.tool) {
    TranscriptRuntimeCollabAgentTool.wait => switch (collaboration.status) {
      TranscriptRuntimeCollabAgentToolCallStatus.inProgress =>
        TranscriptAgentLifecycleState.waitingOnChild,
      TranscriptRuntimeCollabAgentToolCallStatus.completed ||
      TranscriptRuntimeCollabAgentToolCallStatus.failed ||
      TranscriptRuntimeCollabAgentToolCallStatus.unknown =>
        _activeOrIdleLifecycleImpl(timeline),
    },
    TranscriptRuntimeCollabAgentTool.spawnAgent ||
    TranscriptRuntimeCollabAgentTool.resumeAgent ||
    TranscriptRuntimeCollabAgentTool.sendInput ||
    TranscriptRuntimeCollabAgentTool.closeAgent => _activeOrIdleLifecycleImpl(
      timeline,
    ),
    TranscriptRuntimeCollabAgentTool.unknown => null,
  };
}

TranscriptAgentLifecycleState _activeOrIdleLifecycleImpl(
  TranscriptTimelineState? timeline,
) {
  return timeline?.activeTurn != null
      ? TranscriptAgentLifecycleState.running
      : TranscriptAgentLifecycleState.idle;
}

TranscriptThreadRegistryEntry _upsertRegistryEntryImpl(
  TranscriptThreadRegistryEntry? existing, {
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
          TranscriptThreadRegistryEntry(
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

int _nextDisplayOrderImpl(Map<String, TranscriptThreadRegistryEntry> registry) {
  var maxOrder = -1;
  for (final entry in registry.values) {
    if (entry.displayOrder > maxOrder) {
      maxOrder = entry.displayOrder;
    }
  }
  return maxOrder + 1;
}

List<String> _mergedChildThreadIdsImpl(
  List<String>? existingChildThreadIds,
  List<String> nextChildThreadIds,
) {
  final merged = <String>{...?existingChildThreadIds, ...nextChildThreadIds};
  return merged.toList(growable: false);
}
