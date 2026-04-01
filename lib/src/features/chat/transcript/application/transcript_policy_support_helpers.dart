part of 'transcript_policy.dart';

TranscriptSessionState _commitActiveTurnImpl(
  TranscriptPolicy policy,
  TranscriptSessionState state, {
  required TranscriptActiveTurnState? activeTurn,
  bool includePendingUsage = false,
}) {
  if (activeTurn == null) {
    return state;
  }

  var nextState = state;
  for (final block in projectTranscriptTurnArtifacts(activeTurn.artifacts)) {
    nextState = policy._support.appendBlock(nextState, block);
  }
  if (includePendingUsage && activeTurn.pendingThreadTokenUsageBlock != null) {
    nextState = policy._support.appendBlock(
      nextState,
      activeTurn.pendingThreadTokenUsageBlock!,
    );
  }
  return nextState;
}

bool _hasMismatchedActiveTurnImpl(
  TranscriptSessionState state,
  String? turnId,
) {
  final activeTurn = state.activeTurn;
  return activeTurn != null && turnId != null && activeTurn.turnId != turnId;
}

(TranscriptActiveTurnState?, Duration?) _finalizeCommittedTurnImpl(
  TranscriptPolicy policy,
  TranscriptActiveTurnState? activeTurn,
  DateTime createdAt,
) {
  if (activeTurn == null) {
    return (null, null);
  }

  final completedTimer = policy._support.completeTurnTimer(
    activeTurn.timer,
    createdAt,
  );
  return (
    activeTurn.copyWith(
      timer: completedTimer,
      status: TranscriptActiveTurnStatus.completing,
    ),
    completedTimer.elapsedAt(createdAt),
  );
}

TranscriptTurnBoundaryBlock _turnBoundaryBlockImpl(
  TranscriptPolicy policy, {
  required DateTime createdAt,
  required Duration? elapsed,
  TranscriptUsageBlock? usage,
}) {
  return TranscriptTurnBoundaryBlock(
    id: policy._support.eventEntryId('turn-end', createdAt),
    createdAt: createdAt,
    elapsed: elapsed,
    usage: usage,
  );
}

TranscriptSessionState _stateWithTranscriptBlockImpl(
  TranscriptPolicy policy,
  TranscriptSessionState state,
  TranscriptUiBlock block, {
  required String? turnId,
  required String? threadId,
}) {
  final activeTurn = policy._support.ensureActiveTurn(
    state.activeTurn,
    turnId: turnId,
    threadId: threadId,
    createdAt: block.createdAt,
  );
  if (activeTurn == null) {
    return _upsertTopLevelTranscriptBlockImpl(policy, state, block);
  }

  return state.copyWithProjectedTranscript(
    activeTurn: _upsertTurnBlockImpl(activeTurn, block),
  );
}

TranscriptSessionState _stateWithAppendedTranscriptBlockImpl(
  TranscriptPolicy policy,
  TranscriptSessionState state,
  TranscriptUiBlock block, {
  required String? turnId,
  required String? threadId,
}) {
  final activeTurn = policy._support.ensureActiveTurn(
    state.activeTurn,
    turnId: turnId,
    threadId: threadId,
    createdAt: block.createdAt,
  );
  if (activeTurn == null) {
    return policy._support.appendBlock(state, block);
  }

  return state.copyWithProjectedTranscript(
    activeTurn: _appendTurnBlockImpl(activeTurn, block),
  );
}

TranscriptActiveTurnState _upsertTurnBlockImpl(
  TranscriptActiveTurnState activeTurn,
  TranscriptUiBlock block,
) {
  final artifact = TranscriptTurnBlockArtifact(block: block);
  var nextArtifacts = List<TranscriptTurnArtifact>.from(activeTurn.artifacts);
  final index = nextArtifacts.indexWhere((existing) => existing.id == block.id);
  if (index == -1) {
    nextArtifacts = appendTranscriptTurnArtifact(nextArtifacts, artifact);
  } else {
    nextArtifacts[index] = artifact;
  }

  return activeTurn.copyWith(artifacts: nextArtifacts);
}

TranscriptActiveTurnState _appendTurnBlockImpl(
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

TranscriptSessionState _upsertTopLevelTranscriptBlockImpl(
  TranscriptPolicy policy,
  TranscriptSessionState state,
  TranscriptUiBlock block,
) {
  final existingIndex = state.blocks.indexWhere(
    (existing) => existing.id == block.id,
  );
  if (existingIndex == -1) {
    return policy._support.appendBlock(state, block);
  }

  final nextBlocks = List<TranscriptUiBlock>.from(state.blocks);
  nextBlocks[existingIndex] = block;
  return state.copyWithProjectedTranscript(blocks: nextBlocks);
}

String _nextTranscriptEventBlockIdImpl(
  TranscriptPolicy policy,
  TranscriptSessionState state, {
  required String prefix,
  required DateTime createdAt,
}) {
  final usedIds = <String>{
    ...transcriptUiBlockIds(state.blocks),
    if (state.activeTurn != null)
      ...transcriptTurnArtifactIds(state.activeTurn!.artifacts),
  };
  final baseId = policy._support.eventEntryId(prefix, createdAt);
  if (!usedIds.contains(baseId)) {
    return baseId;
  }

  var ordinal = 2;
  var candidate = '$baseId-$ordinal';
  while (usedIds.contains(candidate)) {
    ordinal += 1;
    candidate = '$baseId-$ordinal';
  }
  return candidate;
}

TranscriptSessionState _clearLocalUserMessageCorrelationStateImpl(
  TranscriptSessionState state,
) {
  return state.copyWithProjectedTranscript(
    clearPendingLocalUserMessageBlockIds: true,
    clearLocalUserMessageProviderBindings: true,
  );
}
