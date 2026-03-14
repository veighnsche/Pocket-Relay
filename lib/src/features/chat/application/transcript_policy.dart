import 'package:pocket_relay/src/features/chat/application/transcript_item_policy.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_request_policy.dart';
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
    final block = CodexUserMessageBlock(
      id: _support.eventEntryId('user', createdAt ?? DateTime.now()),
      createdAt: createdAt ?? DateTime.now(),
      text: text,
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
    final cleared = state.copyWith(
      clearThreadId: true,
      clearTurnId: true,
      activeItems: const <String, CodexSessionActiveItem>{},
      pendingApprovalRequests: const <String, CodexSessionPendingRequest>{},
      pendingUserInputRequests:
          const <String, CodexSessionPendingUserInputRequest>{},
    );
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
      clearTurnId: true,
      blocks: const <CodexUiBlock>[],
      activeItems: const <String, CodexSessionActiveItem>{},
      pendingApprovalRequests: const <String, CodexSessionPendingRequest>{},
      pendingUserInputRequests:
          const <String, CodexSessionPendingUserInputRequest>{},
      clearLatestUsageSummary: true,
    );
  }

  CodexSessionState detachThread(CodexSessionState state) {
    return state.copyWith(clearThreadId: true, clearTurnId: true);
  }

  CodexSessionState applySessionExited(
    CodexSessionState state,
    CodexRuntimeSessionExitedEvent event,
  ) {
    final nextState = state.copyWith(
      connectionStatus: event.exitKind == CodexRuntimeSessionExitKind.error
          ? CodexRuntimeSessionState.error
          : CodexRuntimeSessionState.stopped,
      clearThreadId: true,
      clearTurnId: true,
      activeItems: const <String, CodexSessionActiveItem>{},
      pendingApprovalRequests: const <String, CodexSessionPendingRequest>{},
      pendingUserInputRequests:
          const <String, CodexSessionPendingUserInputRequest>{},
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
        body: event.reason ?? 'The Codex session ended.',
      ),
    );
  }

  CodexSessionState applyTurnCompleted(
    CodexSessionState state,
    CodexRuntimeTurnCompletedEvent event,
  ) {
    final nextState = state.copyWith(
      connectionStatus: CodexRuntimeSessionState.ready,
      clearTurnId: true,
      latestUsageSummary: _support.buildRuntimeUsageSummary(event),
    );
    final usageSummary = nextState.latestUsageSummary;
    if (usageSummary == null || usageSummary.isEmpty) {
      return nextState;
    }
    return _support.upsertBlock(
      nextState,
      CodexUsageBlock(
        id: _support.eventEntryId('usage', event.createdAt),
        createdAt: event.createdAt,
        title: 'Turn complete',
        body: usageSummary,
      ),
    );
  }

  CodexSessionState applyTurnAborted(
    CodexSessionState state,
    CodexRuntimeTurnAbortedEvent event,
  ) {
    return _support.upsertBlock(
      state.copyWith(
        connectionStatus: CodexRuntimeSessionState.ready,
        clearTurnId: true,
      ),
      CodexStatusBlock(
        id: _support.eventEntryId('status', event.createdAt),
        createdAt: event.createdAt,
        title: 'Turn aborted',
        body: event.reason ?? 'The active turn was aborted.',
        isTranscriptSignal: true,
      ),
    );
  }

  CodexSessionState applyTurnPlanUpdated(
    CodexSessionState state,
    CodexRuntimeTurnPlanUpdatedEvent event,
  ) {
    return _support.upsertBlock(
      state,
      CodexPlanUpdateBlock(
        id: 'turn_plan_${event.turnId ?? event.createdAt.toIso8601String()}',
        createdAt: event.createdAt,
        explanation: event.explanation,
        steps: event.steps,
      ),
    );
  }

  CodexSessionState applyTurnDiffUpdated(
    CodexSessionState state,
    CodexRuntimeTurnDiffUpdatedEvent event,
  ) {
    return _support.upsertBlock(
      state,
      CodexChangedFilesBlock(
        id: 'turn_diff_${event.turnId ?? event.createdAt.toIso8601String()}',
        createdAt: event.createdAt,
        title: 'Changed files',
        files: _itemPolicy.changedFilesFromSources(
          snapshot: null,
          body: event.unifiedDiff,
          rawPayload: event.rawPayload,
        ),
        unifiedDiff: event.unifiedDiff,
      ),
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
    return _support.upsertBlock(
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
    );
  }

  CodexSessionState applyStatus(
    CodexSessionState state,
    CodexRuntimeStatusEvent event,
  ) {
    if (event.rawMethod == 'thread/tokenUsage/updated') {
      return _support.upsertBlock(
        state,
        CodexUsageBlock(
          id: _support.eventEntryId('usage', event.createdAt),
          createdAt: event.createdAt,
          title: event.title,
          body: event.message,
        ),
      );
    }
    if (!_support.isTranscriptStatusSignal(event)) {
      return state;
    }
    return _support.upsertBlock(
      state,
      CodexStatusBlock(
        id: _support.eventEntryId('status', event.createdAt),
        createdAt: event.createdAt,
        title: event.title,
        body: event.message,
        isTranscriptSignal: true,
      ),
    );
  }

  CodexSessionState applyRuntimeError(
    CodexSessionState state,
    CodexRuntimeErrorEvent event,
  ) {
    return _support.upsertBlock(
      state,
      CodexErrorBlock(
        id: _support.eventEntryId('error', event.createdAt),
        createdAt: event.createdAt,
        title: 'Runtime error',
        body: event.message,
      ),
    );
  }
}
