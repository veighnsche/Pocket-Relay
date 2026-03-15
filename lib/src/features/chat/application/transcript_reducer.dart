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
    return _policy.addUserMessage(state, text: text, createdAt: createdAt);
  }

  CodexSessionState startFreshThread(
    CodexSessionState state, {
    String? message,
    DateTime? createdAt,
  }) {
    return _policy.startFreshThread(
      state,
      message: message,
      createdAt: createdAt,
    );
  }

  CodexSessionState clearTranscript(CodexSessionState state) {
    return _policy.clearTranscript(state);
  }

  CodexSessionState detachThread(CodexSessionState state) {
    return _policy.detachThread(state);
  }

  CodexSessionState clearLocalUserMessageCorrelationState(
    CodexSessionState state,
  ) {
    return _policy.clearLocalUserMessageCorrelationState(state);
  }

  CodexSessionState markUnpinnedHostKeySaved(
    CodexSessionState state, {
    required String blockId,
  }) {
    return _policy.markUnpinnedHostKeySaved(state, blockId: blockId);
  }

  CodexSessionState reduceRuntimeEvent(
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
        return normalizedState.copyWith(threadId: event.providerThreadId);
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
        return normalizedState.copyWith(
          connectionStatus: CodexRuntimeSessionState.running,
          threadId: event.threadId ?? normalizedState.threadId,
          activeTurn: nextActiveTurn,
        );
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
        return normalizedState;
      case CodexRuntimeUnpinnedHostKeyEvent():
        return _policy.applyUnpinnedHostKey(normalizedState, event);
      case CodexRuntimeSshHostKeyMismatchEvent():
        return normalizedState;
      case CodexRuntimeSshAuthenticationFailedEvent():
        return normalizedState;
      case CodexRuntimeSshAuthenticatedEvent():
        return normalizedState;
      case CodexRuntimeSshRemoteLaunchFailedEvent():
        return normalizedState;
      case CodexRuntimeSshRemoteProcessStartedEvent():
        return normalizedState;
      case CodexRuntimeStatusEvent():
        return _policy.applyStatus(normalizedState, event);
      case CodexRuntimeErrorEvent():
        return _policy.applyRuntimeError(normalizedState, event);
    }
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
