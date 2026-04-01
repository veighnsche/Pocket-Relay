part of 'transcript_policy.dart';

TranscriptSessionState _resetTranscriptStateImpl(
  TranscriptSessionState state, {
  List<TranscriptUiBlock>? blocks,
}) {
  return state.copyWithProjectedTranscript(
    clearThreadId: true,
    clearActiveTurn: true,
    blocks: blocks,
    clearPendingLocalUserMessageBlockIds: true,
    clearLocalUserMessageProviderBindings: true,
  );
}

TranscriptSessionState _rolloverTurnIfNeededImpl(
  TranscriptPolicy policy,
  TranscriptSessionState state, {
  required String? turnId,
  required String? threadId,
  required DateTime createdAt,
}) {
  if (turnId == null) {
    return state;
  }

  final currentTurn = state.activeTurn;
  if (currentTurn == null || currentTurn.turnId == turnId) {
    return state;
  }

  final finalizedTurn = _finalizeCommittedTurnImpl(
    policy,
    currentTurn,
    createdAt,
  );
  final finalizedState = policy._support.appendBlock(
    _commitActiveTurnImpl(
      policy,
      _clearLocalUserMessageCorrelationStateImpl(
        state.copyWithProjectedTranscript(clearActiveTurn: true),
      ),
      activeTurn: finalizedTurn.$1,
    ),
    _turnBoundaryBlockImpl(
      policy,
      createdAt: createdAt,
      elapsed: finalizedTurn.$2,
      usage: finalizedTurn.$1?.pendingThreadTokenUsageBlock,
    ),
  );
  return finalizedState.copyWithProjectedTranscript(
    activeTurn: policy._support.startActiveTurn(
      turnId: turnId,
      threadId: threadId ?? state.threadId,
      createdAt: createdAt,
    ),
  );
}

TranscriptSessionState _applyThreadClosedImpl(
  TranscriptPolicy policy,
  TranscriptSessionState state,
  TranscriptRuntimeThreadStateChangedEvent event,
) {
  final finalizedTurn = _finalizeCommittedTurnImpl(
    policy,
    state.activeTurn,
    event.createdAt,
  );
  final nextState = _commitActiveTurnImpl(
    policy,
    _clearLocalUserMessageCorrelationStateImpl(
      state.copyWithProjectedTranscript(
        clearThreadId: true,
        clearActiveTurn: true,
      ),
    ),
    activeTurn: finalizedTurn.$1,
  );
  if (finalizedTurn.$1 == null) {
    return nextState;
  }
  return policy._support.appendBlock(
    nextState,
    _turnBoundaryBlockImpl(
      policy,
      createdAt: event.createdAt,
      elapsed: finalizedTurn.$2,
      usage: finalizedTurn.$1?.pendingThreadTokenUsageBlock,
    ),
  );
}

TranscriptSessionState _applySessionExitedImpl(
  TranscriptPolicy policy,
  TranscriptSessionState state,
  TranscriptRuntimeSessionExitedEvent event,
) {
  final completedTimer = policy._support.completeTurnTimer(
    state.activeTurn?.timer,
    event.createdAt,
  );
  final elapsed = state.activeTurn == null
      ? null
      : completedTimer.elapsedAt(event.createdAt);
  final nextState = _commitActiveTurnImpl(
    policy,
    _clearLocalUserMessageCorrelationStateImpl(
      state.copyWithProjectedTranscript(
        connectionStatus:
            event.exitKind == TranscriptRuntimeSessionExitKind.error
            ? TranscriptRuntimeSessionState.error
            : TranscriptRuntimeSessionState.stopped,
        clearThreadId: true,
        clearActiveTurn: true,
      ),
    ),
    activeTurn: state.activeTurn,
    includePendingUsage: true,
  );
  if (event.exitKind != TranscriptRuntimeSessionExitKind.error) {
    return nextState;
  }
  return policy._support.appendBlock(
    nextState,
    TranscriptErrorBlock(
      id: policy._support.eventEntryId('session-exit', event.createdAt),
      createdAt: event.createdAt,
      title: 'Session exited',
      body: elapsed == null
          ? (event.reason ?? 'The Codex session ended.')
          : '${event.reason ?? 'The Codex session ended.'}\n\nElapsed ${formatElapsedDuration(elapsed)}.',
    ),
  );
}

TranscriptSessionState _applyTurnCompletedImpl(
  TranscriptPolicy policy,
  TranscriptSessionState state,
  TranscriptRuntimeTurnCompletedEvent event,
) {
  if (_hasMismatchedActiveTurnImpl(state, event.turnId)) {
    return state;
  }

  final finalizedTurn = _finalizeCommittedTurnImpl(
    policy,
    state.activeTurn,
    event.createdAt,
  );
  final nextState = _commitActiveTurnImpl(
    policy,
    _clearLocalUserMessageCorrelationStateImpl(
      state.copyWithProjectedTranscript(
        connectionStatus: TranscriptRuntimeSessionState.ready,
        clearActiveTurn: true,
      ),
    ),
    activeTurn: finalizedTurn.$1,
  );
  return policy._support.appendBlock(
    nextState,
    _turnBoundaryBlockImpl(
      policy,
      createdAt: event.createdAt,
      elapsed: finalizedTurn.$2,
      usage: finalizedTurn.$1?.pendingThreadTokenUsageBlock,
    ),
  );
}

TranscriptSessionState _applyTurnAbortedImpl(
  TranscriptPolicy policy,
  TranscriptSessionState state,
  TranscriptRuntimeTurnAbortedEvent event,
) {
  if (_hasMismatchedActiveTurnImpl(state, event.turnId)) {
    return state;
  }

  final finalizedTurn = _finalizeCommittedTurnImpl(
    policy,
    state.activeTurn,
    event.createdAt,
  );
  return policy._support.appendBlock(
    _commitActiveTurnImpl(
      policy,
      _clearLocalUserMessageCorrelationStateImpl(
        state.copyWithProjectedTranscript(
          connectionStatus: TranscriptRuntimeSessionState.ready,
          clearActiveTurn: true,
        ),
      ),
      activeTurn: finalizedTurn.$1,
      includePendingUsage: true,
    ),
    TranscriptStatusBlock(
      id: policy._support.eventEntryId('status', event.createdAt),
      createdAt: event.createdAt,
      title: 'Turn aborted',
      body: finalizedTurn.$2 == null
          ? (event.reason ?? 'The active turn was aborted.')
          : '${event.reason ?? 'The active turn was aborted.'}\n\nElapsed ${formatElapsedDuration(finalizedTurn.$2!)}.',
      statusKind: TranscriptStatusBlockKind.info,
      isTranscriptSignal: true,
    ),
  );
}
