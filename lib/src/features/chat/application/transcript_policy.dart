import 'package:pocket_relay/src/features/chat/application/transcript_changed_files_parser.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_item_policy.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_request_policy.dart';
import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/core/utils/duration_utils.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptPolicy {
  const TranscriptPolicy({
    TranscriptChangedFilesParser changedFilesParser =
        const TranscriptChangedFilesParser(),
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
    TranscriptItemPolicy itemPolicy = const TranscriptItemPolicy(),
    TranscriptRequestPolicy requestPolicy = const TranscriptRequestPolicy(),
  }) : _changedFilesParser = changedFilesParser,
       _support = support,
       _itemPolicy = itemPolicy,
       _requestPolicy = requestPolicy;

  final TranscriptChangedFilesParser _changedFilesParser;
  final TranscriptPolicySupport _support;
  final TranscriptItemPolicy _itemPolicy;
  final TranscriptRequestPolicy _requestPolicy;

  CodexSessionState addUserMessage(
    CodexSessionState state, {
    required String text,
    DateTime? createdAt,
  }) {
    final block = CodexUserMessageBlock(
      id: _support.eventEntryId('user', createdAt ?? DateTime.now()),
      createdAt: createdAt ?? DateTime.now(),
      text: text,
      deliveryState: CodexUserMessageDeliveryState.localEcho,
    );

    return _support.upsertBlock(
      state.copyWith(connectionStatus: CodexRuntimeSessionState.running),
      block,
    );
  }

  CodexSessionState startFreshThread(
    CodexSessionState state, {
    String? message,
    DateTime? createdAt,
  }) {
    final cleared = state.copyWith(clearThreadId: true, clearActiveTurn: true);
    if (message == null || message.trim().isEmpty) {
      return cleared;
    }

    final eventTime = createdAt ?? DateTime.now();
    return _support.upsertBlock(
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
      clearLatestUsageSummary: true,
    );
  }

  CodexSessionState detachThread(CodexSessionState state) {
    return state.copyWith(clearThreadId: true, clearActiveTurn: true);
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
    final finalizedState = _support.upsertBlock(
      _commitActiveTurn(
        state.copyWith(clearActiveTurn: true),
        activeTurn: finalizedTurn.$1,
      ),
      _turnBoundaryBlock(
        createdAt: createdAt,
        elapsed: finalizedTurn.$2,
        usage: finalizedTurn.$1?.pendingThreadTokenUsageBlock,
      ),
    );
    return finalizedState.copyWith(
      activeTurn: CodexActiveTurnState(
        turnId: turnId,
        threadId: threadId ?? state.threadId,
        timer: CodexSessionTurnTimer(
          turnId: turnId,
          startedAt: createdAt,
          activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
        ),
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
      state.copyWith(clearThreadId: true, clearActiveTurn: true),
      activeTurn: finalizedTurn.$1,
    );
    if (finalizedTurn.$1 == null) {
      return nextState;
    }
    return _support.upsertBlock(
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
      state.copyWith(
        connectionStatus: event.exitKind == CodexRuntimeSessionExitKind.error
            ? CodexRuntimeSessionState.error
            : CodexRuntimeSessionState.stopped,
        clearThreadId: true,
        clearActiveTurn: true,
      ),
      activeTurn: state.activeTurn,
      includePendingUsage: true,
    );
    if (event.exitKind != CodexRuntimeSessionExitKind.error) {
      return nextState;
    }
    return _support.upsertBlock(
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
      state.copyWith(
        connectionStatus: CodexRuntimeSessionState.ready,
        clearActiveTurn: true,
        latestUsageSummary: _support.buildRuntimeUsageSummary(event),
      ),
      activeTurn: finalizedTurn.$1,
    );
    return _support.upsertBlock(
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
    return _support.upsertBlock(
      _commitActiveTurn(
        state.copyWith(
          connectionStatus: CodexRuntimeSessionState.ready,
          clearActiveTurn: true,
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
    return _stateWithTranscriptBlock(
      state,
      CodexPlanUpdateBlock(
        id: 'turn_plan_${event.turnId ?? event.createdAt.toIso8601String()}',
        createdAt: event.createdAt,
        explanation: event.explanation,
        steps: event.steps,
      ),
      turnId: event.turnId,
      threadId: event.threadId,
    );
  }

  CodexSessionState applyTurnDiffUpdated(
    CodexSessionState state,
    CodexRuntimeTurnDiffUpdatedEvent event,
  ) {
    return _stateWithTranscriptBlock(
      state,
      CodexChangedFilesBlock(
        id: 'turn_diff_${event.turnId ?? event.createdAt.toIso8601String()}',
        createdAt: event.createdAt,
        title: 'Changed files',
        files: _changedFilesParser.changedFilesFromSources(
          snapshot: null,
          body: event.unifiedDiff,
          rawPayload: event.rawPayload,
        ),
        unifiedDiff: event.unifiedDiff,
        turnId: event.turnId,
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
      final activeTurn = _ensureActiveTurn(
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

  CodexActiveTurnState? _ensureActiveTurn(
    CodexActiveTurnState? activeTurn, {
    required String? turnId,
    required String? threadId,
    required DateTime createdAt,
  }) {
    if (activeTurn != null || turnId == null) {
      return activeTurn;
    }

    return CodexActiveTurnState(
      turnId: turnId,
      threadId: threadId,
      timer: CodexSessionTurnTimer(
        turnId: turnId,
        startedAt: createdAt,
        activeSegmentStartedMonotonicAt: CodexMonotonicClock.now(),
      ),
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
    for (final block in projectCodexTurnSegments(activeTurn.segments)) {
      nextState = _support.upsertBlock(nextState, block);
    }
    if (includePendingUsage &&
        activeTurn.pendingThreadTokenUsageBlock != null) {
      nextState = _support.upsertBlock(
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
    final activeTurn = _ensureActiveTurn(
      state.activeTurn,
      turnId: turnId,
      threadId: threadId,
      createdAt: block.createdAt,
    );
    if (activeTurn == null) {
      return _support.upsertBlock(state, block);
    }

    return state.copyWith(activeTurn: _upsertTurnBlock(activeTurn, block));
  }

  CodexActiveTurnState _upsertTurnBlock(
    CodexActiveTurnState activeTurn,
    CodexUiBlock block,
  ) {
    final segment = CodexTurnBlockSegment(block: block);
    final nextSegments = List<CodexTurnSegment>.from(activeTurn.segments);
    final index = nextSegments.indexWhere(
      (existing) => existing.id == block.id,
    );
    if (index == -1) {
      nextSegments.add(segment);
    } else {
      nextSegments[index] = segment;
    }

    return activeTurn.copyWith(segments: nextSegments);
  }
}
