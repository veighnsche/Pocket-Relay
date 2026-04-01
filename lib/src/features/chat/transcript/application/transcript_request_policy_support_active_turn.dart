part of 'transcript_request_policy.dart';

TranscriptActiveTurnState? _activeTurnForPendingApproval(
  TranscriptActiveTurnState? activeTurn, {
  required String requestId,
  required TranscriptSessionPendingRequest pendingRequest,
  required TranscriptSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null || activeTurn.turnId != pendingRequest.turnId) {
    return activeTurn;
  }

  return activeTurn.copyWith(
    timer: turnTimer,
    status: TranscriptActiveTurnStatus.blocked,
    pendingApprovalRequests: <String, TranscriptSessionPendingRequest>{
      ...activeTurn.pendingApprovalRequests,
      requestId: pendingRequest,
    },
  );
}

TranscriptActiveTurnState? _activeTurnForPendingInput(
  TranscriptActiveTurnState? activeTurn, {
  required String requestId,
  required TranscriptSessionPendingUserInputRequest pendingRequest,
  required TranscriptSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null || activeTurn.turnId != pendingRequest.turnId) {
    return activeTurn;
  }

  return activeTurn.copyWith(
    timer: turnTimer,
    status: TranscriptActiveTurnStatus.blocked,
    pendingUserInputRequests:
        <String, TranscriptSessionPendingUserInputRequest>{
          ...activeTurn.pendingUserInputRequests,
          requestId: pendingRequest,
        },
  );
}

TranscriptActiveTurnState? _activeTurnAfterRequestResolved(
  TranscriptActiveTurnState? activeTurn, {
  required String requestId,
  required TranscriptSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null) {
    return null;
  }

  final nextApprovals = <String, TranscriptSessionPendingRequest>{
    ...activeTurn.pendingApprovalRequests,
  }..remove(requestId);
  final nextInputs = <String, TranscriptSessionPendingUserInputRequest>{
    ...activeTurn.pendingUserInputRequests,
  }..remove(requestId);

  return activeTurn.copyWith(
    timer: turnTimer,
    status: nextApprovals.isNotEmpty || nextInputs.isNotEmpty
        ? TranscriptActiveTurnStatus.blocked
        : TranscriptActiveTurnStatus.running,
    pendingApprovalRequests: nextApprovals,
    pendingUserInputRequests: nextInputs,
  );
}

TranscriptActiveTurnState? _activeTurnAfterUserInputResolved(
  TranscriptActiveTurnState? activeTurn, {
  required String requestId,
  required TranscriptSessionTurnTimer? turnTimer,
}) {
  if (activeTurn == null) {
    return null;
  }

  final nextInputs = <String, TranscriptSessionPendingUserInputRequest>{
    ...activeTurn.pendingUserInputRequests,
  }..remove(requestId);

  return activeTurn.copyWith(
    timer: turnTimer,
    status:
        activeTurn.pendingApprovalRequests.isNotEmpty || nextInputs.isNotEmpty
        ? TranscriptActiveTurnStatus.blocked
        : TranscriptActiveTurnStatus.running,
    pendingUserInputRequests: nextInputs,
  );
}

TranscriptActiveTurnState? _ensureActiveTurn(
  TranscriptActiveTurnState? activeTurn, {
  required String? turnId,
  required String? threadId,
  required DateTime createdAt,
}) {
  if (activeTurn != null || turnId == null) {
    return activeTurn;
  }

  return TranscriptActiveTurnState(
    turnId: turnId,
    threadId: threadId,
    timer: TranscriptSessionTurnTimer(
      turnId: turnId,
      startedAt: createdAt,
      activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
    ),
  );
}

TranscriptActiveTurnState _appendTurnBlock(
  TranscriptActiveTurnState activeTurn,
  TranscriptUiBlock block,
) {
  return activeTurn.copyWith(
    artifacts: appendTranscriptTurnArtifact(
      activeTurn.artifacts,
      TranscriptTurnBlockArtifact(block: block),
    ),
  );
}

TranscriptActiveTurnState? _freezeTailArtifact(
  TranscriptActiveTurnState? activeTurn,
) {
  if (activeTurn == null || activeTurn.artifacts.isEmpty) {
    return activeTurn;
  }

  final frozenTail = freezeTranscriptTurnArtifact(activeTurn.artifacts.last);
  if (identical(frozenTail, activeTurn.artifacts.last)) {
    return activeTurn;
  }

  final nextArtifacts = List<TranscriptTurnArtifact>.from(activeTurn.artifacts);
  nextArtifacts[nextArtifacts.length - 1] = frozenTail;
  return activeTurn.copyWith(artifacts: nextArtifacts);
}

TranscriptActiveTurnState? _freezeArtifactsForRequest(
  TranscriptActiveTurnState? activeTurn, {
  required String? itemId,
}) {
  return _freezeCommandArtifact(
    _freezeTailArtifact(activeTurn),
    itemId: itemId,
  );
}

TranscriptActiveTurnState? _freezeCommandArtifact(
  TranscriptActiveTurnState? activeTurn, {
  required String? itemId,
}) {
  if (activeTurn == null || itemId == null) {
    return activeTurn;
  }

  final item = activeTurn.itemsById[itemId];
  if (item?.itemType != TranscriptCanonicalItemType.commandExecution) {
    return activeTurn;
  }

  final artifactId = activeTurn.itemArtifactIds[itemId];
  if (artifactId == null) {
    return activeTurn;
  }

  final index = activeTurn.artifacts.indexWhere(
    (artifact) => artifact.id == artifactId,
  );
  if (index == -1) {
    return activeTurn;
  }

  final artifact = activeTurn.artifacts[index];
  final frozenArtifact = freezeTranscriptTurnArtifact(artifact);
  if (identical(frozenArtifact, artifact)) {
    return activeTurn;
  }

  final nextArtifacts = List<TranscriptTurnArtifact>.from(activeTurn.artifacts);
  nextArtifacts[index] = frozenArtifact;
  return activeTurn.copyWith(artifacts: nextArtifacts);
}

TranscriptActiveTurnState _replaceTailTurnBlock(
  TranscriptActiveTurnState activeTurn,
  TranscriptUiBlock block,
) {
  final nextArtifacts = List<TranscriptTurnArtifact>.from(activeTurn.artifacts);
  nextArtifacts[nextArtifacts.length - 1] = TranscriptTurnBlockArtifact(
    block: block,
  );
  return activeTurn.copyWith(artifacts: nextArtifacts);
}
