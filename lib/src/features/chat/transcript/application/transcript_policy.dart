import 'package:pocket_relay/src/features/chat/transcript/application/transcript_item_policy.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_request_policy.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/core/utils/duration_utils.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

part 'transcript_policy_blocks.dart';
part 'transcript_policy_support_helpers.dart';
part 'transcript_policy_turns.dart';

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
    ChatComposerDraft? draft,
    DateTime? createdAt,
  }) {
    final eventTime = createdAt ?? DateTime.now();
    final block = CodexUserMessageBlock(
      id: _support.eventEntryId('user', eventTime),
      createdAt: eventTime,
      text: draft?.text ?? text,
      deliveryState: CodexUserMessageDeliveryState.sent,
      structuredDraft: draft,
    );

    return _support.appendBlock(
      state.copyWithProjectedTranscript(
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
    final cleared = _resetTranscriptStateImpl(state);
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
        statusKind: CodexStatusBlockKind.info,
        isTranscriptSignal: true,
      ),
    );
  }

  CodexSessionState clearTranscript(CodexSessionState state) {
    return _resetTranscriptStateImpl(state, blocks: const <CodexUiBlock>[]);
  }

  CodexSessionState detachThread(CodexSessionState state) {
    return _resetTranscriptStateImpl(state);
  }

  CodexSessionState clearLocalUserMessageCorrelationState(
    CodexSessionState state,
  ) {
    return _clearLocalUserMessageCorrelationStateImpl(state);
  }

  CodexSessionState rolloverTurnIfNeeded(
    CodexSessionState state, {
    required String? turnId,
    required String? threadId,
    required DateTime createdAt,
  }) {
    return _rolloverTurnIfNeededImpl(
      this,
      state,
      turnId: turnId,
      threadId: threadId,
      createdAt: createdAt,
    );
  }

  CodexSessionState applyThreadClosed(
    CodexSessionState state,
    CodexRuntimeThreadStateChangedEvent event,
  ) {
    return _applyThreadClosedImpl(this, state, event);
  }

  CodexSessionState applySessionExited(
    CodexSessionState state,
    CodexRuntimeSessionExitedEvent event,
  ) {
    return _applySessionExitedImpl(this, state, event);
  }

  CodexSessionState applyTurnCompleted(
    CodexSessionState state,
    CodexRuntimeTurnCompletedEvent event,
  ) {
    return _applyTurnCompletedImpl(this, state, event);
  }

  CodexSessionState applyTurnAborted(
    CodexSessionState state,
    CodexRuntimeTurnAbortedEvent event,
  ) {
    return _applyTurnAbortedImpl(this, state, event);
  }

  CodexSessionState applyTurnPlanUpdated(
    CodexSessionState state,
    CodexRuntimeTurnPlanUpdatedEvent event,
  ) {
    return _stateWithAppendedTranscriptBlockImpl(
      this,
      state,
      CodexPlanUpdateBlock(
        id: _nextTranscriptEventBlockIdImpl(
          this,
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
    return _stateWithTranscriptBlockImpl(
      this,
      state,
      _support.statusEntry(
        prefix: 'warning',
        title: event.rawMethod == 'deprecationNotice'
            ? 'Deprecation notice'
            : 'Warning',
        body: event.details == null || event.details!.trim().isEmpty
            ? event.summary
            : '${event.summary}\n\n${event.details}',
        createdAt: event.createdAt,
        statusKind: CodexStatusBlockKind.warning,
        isTranscriptSignal: true,
      ),
      turnId: event.turnId,
      threadId: event.threadId,
    );
  }

  CodexSessionState applyUnpinnedHostKey(
    CodexSessionState state,
    CodexRuntimeUnpinnedHostKeyEvent event,
  ) {
    return _upsertTopLevelTranscriptBlockImpl(
      this,
      state,
      CodexSshUnpinnedHostKeyBlock(
        id: _sshUnpinnedHostKeyBlockIdImpl(host: event.host, port: event.port),
        createdAt: event.createdAt,
        host: event.host,
        port: event.port,
        keyType: event.keyType,
        fingerprint: event.fingerprint,
      ),
    );
  }

  CodexSessionState applySshConnectFailed(
    CodexSessionState state,
    CodexRuntimeSshConnectFailedEvent event,
  ) {
    return _upsertTopLevelTranscriptBlockImpl(
      this,
      state,
      CodexSshConnectFailedBlock(
        id: _sshConnectFailedBlockIdImpl(host: event.host, port: event.port),
        createdAt: event.createdAt,
        host: event.host,
        port: event.port,
        message: event.message,
      ),
    );
  }

  CodexSessionState applySshHostKeyMismatch(
    CodexSessionState state,
    CodexRuntimeSshHostKeyMismatchEvent event,
  ) {
    return _upsertTopLevelTranscriptBlockImpl(
      this,
      state,
      CodexSshHostKeyMismatchBlock(
        id: _sshHostKeyMismatchBlockIdImpl(host: event.host, port: event.port),
        createdAt: event.createdAt,
        host: event.host,
        port: event.port,
        keyType: event.keyType,
        expectedFingerprint: event.expectedFingerprint,
        actualFingerprint: event.actualFingerprint,
      ),
    );
  }

  CodexSessionState applySshAuthenticationFailed(
    CodexSessionState state,
    CodexRuntimeSshAuthenticationFailedEvent event,
  ) {
    return _upsertTopLevelTranscriptBlockImpl(
      this,
      state,
      CodexSshAuthenticationFailedBlock(
        id: _sshAuthenticationFailedBlockIdImpl(
          host: event.host,
          port: event.port,
          username: event.username,
        ),
        createdAt: event.createdAt,
        host: event.host,
        port: event.port,
        username: event.username,
        authMode: event.authMode,
        message: event.message,
      ),
    );
  }

  CodexSessionState markUnpinnedHostKeySaved(
    CodexSessionState state, {
    required String blockId,
  }) {
    return _markUnpinnedHostKeySavedImpl(state, blockId: blockId);
  }

  CodexSessionState applyStatus(
    CodexSessionState state,
    CodexRuntimeStatusEvent event,
  ) {
    return _applyStatusImpl(this, state, event);
  }

  CodexSessionState applyRuntimeError(
    CodexSessionState state,
    CodexRuntimeErrorEvent event,
  ) {
    return _stateWithTranscriptBlockImpl(
      this,
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
}
