import 'package:pocket_relay/src/features/chat/application/transcript_item_policy.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_request_policy.dart';
import 'package:pocket_relay/src/core/utils/duration_utils.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptPolicy {
  const TranscriptPolicy({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
    TranscriptItemPolicy itemPolicy = const TranscriptItemPolicy(),
    TranscriptRequestPolicy requestPolicy = const TranscriptRequestPolicy(),
  }) : _support = support,
       _itemPolicy = itemPolicy,
       _requestPolicy = requestPolicy;

  final TranscriptPolicySupport _support;
  final TranscriptItemPolicy _itemPolicy;
  final TranscriptRequestPolicy _requestPolicy;

  CodexSessionState addUserMessage(
    CodexSessionState state, {
    required String text,
    DateTime? createdAt,
  }) {
    final eventTime = createdAt ?? DateTime.now();
    final block = CodexUserMessageBlock(
      id: _support.eventEntryId('user', eventTime),
      createdAt: eventTime,
      text: text,
      deliveryState: CodexUserMessageDeliveryState.sent,
    );

    return _support.appendBlock(
      state.copyWith(
        connectionStatus: CodexRuntimeSessionState.running,
        pendingLocalUserMessageBlockIds: <String>[
          ...state.pendingLocalUserMessageBlockIds,
          block.id,
        ],
      ),
      block,
    );
  }

  CodexSessionState startFreshThread(
    CodexSessionState state, {
    String? message,
    DateTime? createdAt,
  }) {
    final cleared = state.copyWith(
      clearThreadId: true,
      clearActiveTurn: true,
      clearPendingLocalUserMessageBlockIds: true,
      clearLocalUserMessageProviderBindings: true,
    );
    if (message == null || message.trim().isEmpty) {
      return cleared;
    }

    final eventTime = createdAt ?? DateTime.now();
    return _support.appendBlock(
      cleared,
      CodexStatusBlock(
        id: _support.eventEntryId('status', eventTime),
        createdAt: eventTime,
        title: 'New thread',
        body: message,
        isTranscriptSignal: true,
      ),
    );
  }

  CodexSessionState clearTranscript(CodexSessionState state) {
    return state.copyWith(
      clearThreadId: true,
      clearActiveTurn: true,
      blocks: const <CodexUiBlock>[],
      clearPendingLocalUserMessageBlockIds: true,
      clearLocalUserMessageProviderBindings: true,
    );
  }

  CodexSessionState detachThread(CodexSessionState state) {
    return state.copyWith(
      clearThreadId: true,
      clearActiveTurn: true,
      clearPendingLocalUserMessageBlockIds: true,
      clearLocalUserMessageProviderBindings: true,
    );
  }

  CodexSessionState clearLocalUserMessageCorrelationState(
    CodexSessionState state,
  ) {
    return _clearLocalUserMessageCorrelationState(state);
  }

  CodexSessionState rolloverTurnIfNeeded(
    CodexSessionState state, {
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

    final finalizedTurn = _finalizeCommittedTurn(currentTurn, createdAt);
    final finalizedState = _support.appendBlock(
      _commitActiveTurn(
        _clearLocalUserMessageCorrelationState(
          state.copyWith(clearActiveTurn: true),
        ),
        activeTurn: finalizedTurn.$1,
      ),
      _turnBoundaryBlock(
        createdAt: createdAt,
        elapsed: finalizedTurn.$2,
        usage: finalizedTurn.$1?.pendingThreadTokenUsageBlock,
      ),
    );
    return finalizedState.copyWith(
      activeTurn: _support.startActiveTurn(
        turnId: turnId,
        threadId: threadId ?? state.threadId,
        createdAt: createdAt,
      ),
    );
  }

  CodexSessionState applyThreadClosed(
    CodexSessionState state,
    CodexRuntimeThreadStateChangedEvent event,
  ) {
    final finalizedTurn = _finalizeCommittedTurn(
      state.activeTurn,
      event.createdAt,
    );
    final nextState = _commitActiveTurn(
      _clearLocalUserMessageCorrelationState(
        state.copyWith(clearThreadId: true, clearActiveTurn: true),
      ),
      activeTurn: finalizedTurn.$1,
    );
    if (finalizedTurn.$1 == null) {
      return nextState;
    }
    return _support.appendBlock(
      nextState,
      _turnBoundaryBlock(
        createdAt: event.createdAt,
        elapsed: finalizedTurn.$2,
        usage: finalizedTurn.$1?.pendingThreadTokenUsageBlock,
      ),
    );
  }

  CodexSessionState applySessionExited(
    CodexSessionState state,
    CodexRuntimeSessionExitedEvent event,
  ) {
    final completedTimer = _support.completeTurnTimer(
      state.activeTurn?.timer,
      event.createdAt,
    );
    final elapsed = state.activeTurn == null
        ? null
        : completedTimer.elapsedAt(event.createdAt);
    final nextState = _commitActiveTurn(
      _clearLocalUserMessageCorrelationState(
        state.copyWith(
          connectionStatus: event.exitKind == CodexRuntimeSessionExitKind.error
              ? CodexRuntimeSessionState.error
              : CodexRuntimeSessionState.stopped,
          clearThreadId: true,
          clearActiveTurn: true,
        ),
      ),
      activeTurn: state.activeTurn,
      includePendingUsage: true,
    );
    if (event.exitKind != CodexRuntimeSessionExitKind.error) {
      return nextState;
    }
    return _support.appendBlock(
      nextState,
      CodexErrorBlock(
        id: _support.eventEntryId('session-exit', event.createdAt),
        createdAt: event.createdAt,
        title: 'Session exited',
        body: elapsed == null
            ? (event.reason ?? 'The Codex session ended.')
            : '${event.reason ?? 'The Codex session ended.'}\n\nElapsed ${formatElapsedDuration(elapsed)}.',
      ),
    );
  }

  CodexSessionState applyTurnCompleted(
    CodexSessionState state,
    CodexRuntimeTurnCompletedEvent event,
  ) {
    if (_hasMismatchedActiveTurn(state, event.turnId)) {
      return state;
    }

    final finalizedTurn = _finalizeCommittedTurn(
      state.activeTurn,
      event.createdAt,
    );
    final nextState = _commitActiveTurn(
      _clearLocalUserMessageCorrelationState(
        state.copyWith(
          connectionStatus: CodexRuntimeSessionState.ready,
          clearActiveTurn: true,
        ),
      ),
      activeTurn: finalizedTurn.$1,
    );
    return _support.appendBlock(
      nextState,
      _turnBoundaryBlock(
        createdAt: event.createdAt,
        elapsed: finalizedTurn.$2,
        usage: finalizedTurn.$1?.pendingThreadTokenUsageBlock,
      ),
    );
  }

  CodexSessionState applyTurnAborted(
    CodexSessionState state,
    CodexRuntimeTurnAbortedEvent event,
  ) {
    if (_hasMismatchedActiveTurn(state, event.turnId)) {
      return state;
    }

    final finalizedTurn = _finalizeCommittedTurn(
      state.activeTurn,
      event.createdAt,
    );
    return _support.appendBlock(
      _commitActiveTurn(
        _clearLocalUserMessageCorrelationState(
          state.copyWith(
            connectionStatus: CodexRuntimeSessionState.ready,
            clearActiveTurn: true,
          ),
        ),
        activeTurn: finalizedTurn.$1,
        includePendingUsage: true,
      ),
      CodexStatusBlock(
        id: _support.eventEntryId('status', event.createdAt),
        createdAt: event.createdAt,
        title: 'Turn aborted',
        body: finalizedTurn.$2 == null
            ? (event.reason ?? 'The active turn was aborted.')
            : '${event.reason ?? 'The active turn was aborted.'}\n\nElapsed ${formatElapsedDuration(finalizedTurn.$2!)}.',
        isTranscriptSignal: true,
      ),
    );
  }

  CodexSessionState applyTurnPlanUpdated(
    CodexSessionState state,
    CodexRuntimeTurnPlanUpdatedEvent event,
  ) {
    return _stateWithAppendedTranscriptBlock(
      state,
      CodexPlanUpdateBlock(
        id: _nextTranscriptEventBlockId(
          state,
          prefix: 'turn-plan',
          createdAt: event.createdAt,
        ),
        createdAt: event.createdAt,
        explanation: event.explanation,
        steps: event.steps,
      ),
      turnId: event.turnId,
      threadId: event.threadId,
    );
  }

  CodexSessionState applyItemLifecycle(
    CodexSessionState state,
    CodexRuntimeItemLifecycleEvent event, {
    required bool removeAfterUpsert,
  }) {
    return _itemPolicy.applyItemLifecycle(
      state,
      event,
      removeAfterUpsert: removeAfterUpsert,
    );
  }

  CodexSessionState applyContentDelta(
    CodexSessionState state,
    CodexRuntimeContentDeltaEvent event,
  ) {
    return _itemPolicy.applyContentDelta(state, event);
  }

  CodexSessionState applyRequestOpened(
    CodexSessionState state,
    CodexRuntimeRequestOpenedEvent event,
  ) {
    return _requestPolicy.applyRequestOpened(state, event);
  }

  CodexSessionState applyRequestResolved(
    CodexSessionState state,
    CodexRuntimeRequestResolvedEvent event,
  ) {
    return _requestPolicy.applyRequestResolved(state, event);
  }

  CodexSessionState applyUserInputRequested(
    CodexSessionState state,
    CodexRuntimeUserInputRequestedEvent event,
  ) {
    return _requestPolicy.applyUserInputRequested(state, event);
  }

  CodexSessionState applyUserInputResolved(
    CodexSessionState state,
    CodexRuntimeUserInputResolvedEvent event,
  ) {
    return _requestPolicy.applyUserInputResolved(state, event);
  }

  CodexSessionState applyWarning(
    CodexSessionState state,
    CodexRuntimeWarningEvent event,
  ) {
    return _stateWithTranscriptBlock(
      state,
      _support.statusEntry(
        prefix: 'warning',
        title: 'Warning',
        body: event.details == null || event.details!.trim().isEmpty
            ? event.summary
            : '${event.summary}\n\n${event.details}',
        createdAt: event.createdAt,
        isTranscriptSignal: true,
      ),
      turnId: event.turnId,
      threadId: event.threadId,
    );
  }

  CodexSessionState applyStatus(
    CodexSessionState state,
    CodexRuntimeStatusEvent event,
  ) {
    if (event.rawMethod == 'thread/tokenUsage/updated') {
      final usageBlock = CodexUsageBlock(
        id: _support.eventEntryId('thread-usage', event.createdAt),
        createdAt: event.createdAt,
        title: event.title,
        body: event.message,
      );
      final activeTurn = _support.ensureActiveTurn(
        state.activeTurn,
        turnId: event.turnId,
        threadId: event.threadId,
        createdAt: event.createdAt,
      );
      return state.copyWith(
        activeTurn: activeTurn?.copyWith(
          pendingThreadTokenUsageBlock: usageBlock,
        ),
      );
    }
    if (!_support.isTranscriptStatusSignal(event)) {
      return state;
    }
    return _stateWithTranscriptBlock(
      state,
      CodexStatusBlock(
        id: _support.eventEntryId('status', event.createdAt),
        createdAt: event.createdAt,
        title: event.title,
        body: event.message,
        isTranscriptSignal: true,
      ),
      turnId: event.turnId,
      threadId: event.threadId,
    );
  }

  CodexSessionState applyRuntimeError(
    CodexSessionState state,
    CodexRuntimeErrorEvent event,
  ) {
    return _stateWithTranscriptBlock(
      state,
      CodexErrorBlock(
        id: _support.eventEntryId('error', event.createdAt),
        createdAt: event.createdAt,
        title: 'Runtime error',
        body: event.message,
      ),
      turnId: event.turnId,
      threadId: event.threadId,
    );
  }

  CodexSessionState _commitActiveTurn(
    CodexSessionState state, {
    required CodexActiveTurnState? activeTurn,
    bool includePendingUsage = false,
  }) {
    if (activeTurn == null) {
      return state;
    }

    var nextState = state;
    for (final block in projectCodexTurnArtifacts(activeTurn.artifacts)) {
      nextState = _support.appendBlock(nextState, block);
    }
    if (includePendingUsage &&
        activeTurn.pendingThreadTokenUsageBlock != null) {
      nextState = _support.appendBlock(
        nextState,
        activeTurn.pendingThreadTokenUsageBlock!,
      );
    }
    return nextState;
  }

  bool _hasMismatchedActiveTurn(CodexSessionState state, String? turnId) {
    final activeTurn = state.activeTurn;
    return activeTurn != null && turnId != null && activeTurn.turnId != turnId;
  }

  (CodexActiveTurnState?, Duration?) _finalizeCommittedTurn(
    CodexActiveTurnState? activeTurn,
    DateTime createdAt,
  ) {
    if (activeTurn == null) {
      return (null, null);
    }

    final completedTimer = _support.completeTurnTimer(
      activeTurn.timer,
      createdAt,
    );
    return (
      activeTurn.copyWith(
        timer: completedTimer,
        status: CodexActiveTurnStatus.completing,
      ),
      completedTimer.elapsedAt(createdAt),
    );
  }

  CodexTurnBoundaryBlock _turnBoundaryBlock({
    required DateTime createdAt,
    required Duration? elapsed,
    CodexUsageBlock? usage,
  }) {
    return CodexTurnBoundaryBlock(
      id: _support.eventEntryId('turn-end', createdAt),
      createdAt: createdAt,
      elapsed: elapsed,
      usage: usage,
    );
  }

  CodexSessionState _stateWithTranscriptBlock(
    CodexSessionState state,
    CodexUiBlock block, {
    required String? turnId,
    required String? threadId,
  }) {
    final activeTurn = _support.ensureActiveTurn(
      state.activeTurn,
      turnId: turnId,
      threadId: threadId,
      createdAt: block.createdAt,
    );
    if (activeTurn == null) {
      return _support.appendBlock(state, block);
    }

    return state.copyWith(activeTurn: _upsertTurnBlock(activeTurn, block));
  }

  CodexSessionState _stateWithAppendedTranscriptBlock(
    CodexSessionState state,
    CodexUiBlock block, {
    required String? turnId,
    required String? threadId,
  }) {
    final activeTurn = _support.ensureActiveTurn(
      state.activeTurn,
      turnId: turnId,
      threadId: threadId,
      createdAt: block.createdAt,
    );
    if (activeTurn == null) {
      return _support.appendBlock(state, block);
    }

    return state.copyWith(activeTurn: _appendTurnBlock(activeTurn, block));
  }

  CodexActiveTurnState _upsertTurnBlock(
    CodexActiveTurnState activeTurn,
    CodexUiBlock block,
  ) {
    final artifact = CodexTurnBlockArtifact(block: block);
    var nextArtifacts = List<CodexTurnArtifact>.from(activeTurn.artifacts);
    final index = nextArtifacts.indexWhere(
      (existing) => existing.id == block.id,
    );
    if (index == -1) {
      nextArtifacts = appendCodexTurnArtifact(nextArtifacts, artifact);
    } else {
      nextArtifacts[index] = artifact;
    }

    return activeTurn.copyWith(artifacts: nextArtifacts);
  }

  CodexActiveTurnState _appendTurnBlock(
    CodexActiveTurnState activeTurn,
    CodexUiBlock block,
  ) {
    return activeTurn.copyWith(
      artifacts: appendCodexTurnArtifact(
        activeTurn.artifacts,
        CodexTurnBlockArtifact(block: block),
      ),
    );
  }

  String _nextTranscriptEventBlockId(
    CodexSessionState state, {
    required String prefix,
    required DateTime createdAt,
  }) {
    final usedIds = <String>{
      ...codexUiBlockIds(state.blocks),
      if (state.activeTurn != null)
        ...codexTurnArtifactIds(state.activeTurn!.artifacts),
    };
    final baseId = _support.eventEntryId(prefix, createdAt);
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

  CodexSessionState _clearLocalUserMessageCorrelationState(
    CodexSessionState state,
  ) {
    return state.copyWith(
      clearPendingLocalUserMessageBlockIds: true,
      clearLocalUserMessageProviderBindings: true,
    );
  }
}
