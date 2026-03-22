import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_policy.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';

part 'transcript_reducer_lifecycle.dart';
part 'transcript_reducer_session.dart';
part 'transcript_reducer_workspace.dart';
part 'transcript_reducer_workspace_threads.dart';
part 'transcript_reducer_workspace_timeline.dart';

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
    ChatComposerDraft? draft,
    DateTime? createdAt,
  }) {
    final rootThreadId = state.rootThreadId;
    if (rootThreadId == null) {
      return _policy.addUserMessage(
        state,
        text: text,
        draft: draft,
        createdAt: createdAt,
      );
    }

    return _reduceTimelineStateImpl(
      this,
      state,
      threadId: rootThreadId,
      event: null,
      reducerFn: (projectedState) => _policy.addUserMessage(
        projectedState,
        text: text,
        draft: draft,
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
    return _resetSessionTranscript(
      state,
      reset: (transcriptState) => _policy.startFreshThread(
        transcriptState,
        message: message,
        createdAt: createdAt,
      ),
    );
  }

  CodexSessionState clearTranscript(CodexSessionState state) {
    return _resetSessionTranscript(state, reset: _policy.clearTranscript);
  }

  CodexSessionState detachThread(CodexSessionState state) {
    return _resetSessionTranscript(state, reset: _policy.detachThread);
  }

  CodexSessionState _resetSessionTranscript(
    CodexSessionState state, {
    required CodexSessionState Function(CodexSessionState transcriptState)
    reset,
  }) {
    return reset(
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
    return _reduceTimelineStateImpl(
      this,
      state,
      threadId: targetThreadId,
      event: null,
      reducerFn: _policy.clearLocalUserMessageCorrelationState,
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
    return _reduceTimelineStateImpl(
      this,
      state,
      threadId: targetThreadId,
      event: null,
      reducerFn: (projectedState) =>
          _policy.markUnpinnedHostKeySaved(projectedState, blockId: blockId),
    );
  }

  CodexSessionState reduceRuntimeEvent(
    CodexSessionState state,
    CodexRuntimeEvent event,
  ) {
    if (state.rootThreadId == null) {
      final nextState = _reduceSessionTranscriptRuntimeEventImpl(
        this,
        state,
        event,
      );
      if (event is CodexRuntimeThreadStartedEvent) {
        return _promoteSessionTranscriptToWorkspaceImpl(nextState, event);
      }
      return nextState;
    }

    return _reduceWorkspaceRuntimeEventImpl(this, state, event);
  }
}
