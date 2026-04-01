import 'package:pocket_relay/src/features/chat/transcript/application/transcript_item_policy.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_request_policy.dart';
import 'package:pocket_relay/src/features/chat/composer/domain/chat_composer_draft.dart';
import 'package:pocket_relay/src/core/utils/duration_utils.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';

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

  TranscriptSessionState addUserMessage(
    TranscriptSessionState state, {
    required String text,
    ChatComposerDraft? draft,
    DateTime? createdAt,
  }) {
    final eventTime = createdAt ?? DateTime.now();
    final block = TranscriptUserMessageBlock(
      id: _support.eventEntryId('user', eventTime),
      createdAt: eventTime,
      text: draft?.text ?? text,
      deliveryState: TranscriptUserMessageDeliveryState.sent,
      structuredDraft: draft,
    );

    return _support.appendBlock(
      state.copyWithProjectedTranscript(
        connectionStatus: TranscriptRuntimeSessionState.running,
        pendingLocalUserMessageBlockIds: <String>[
          ...state.pendingLocalUserMessageBlockIds,
          block.id,
        ],
      ),
      block,
    );
  }

  TranscriptSessionState startFreshThread(
    TranscriptSessionState state, {
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
      TranscriptStatusBlock(
        id: _support.eventEntryId('status', eventTime),
        createdAt: eventTime,
        title: 'New thread',
        body: message,
        statusKind: TranscriptStatusBlockKind.info,
        isTranscriptSignal: true,
      ),
    );
  }

  TranscriptSessionState clearTranscript(TranscriptSessionState state) {
    return _resetTranscriptStateImpl(
      state,
      blocks: const <TranscriptUiBlock>[],
    );
  }

  TranscriptSessionState detachThread(TranscriptSessionState state) {
    return _resetTranscriptStateImpl(state);
  }

  TranscriptSessionState clearLocalUserMessageCorrelationState(
    TranscriptSessionState state,
  ) {
    return _clearLocalUserMessageCorrelationStateImpl(state);
  }

  TranscriptSessionState rolloverTurnIfNeeded(
    TranscriptSessionState state, {
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

  TranscriptSessionState applyThreadClosed(
    TranscriptSessionState state,
    TranscriptRuntimeThreadStateChangedEvent event,
  ) {
    return _applyThreadClosedImpl(this, state, event);
  }

  TranscriptSessionState applySessionExited(
    TranscriptSessionState state,
    TranscriptRuntimeSessionExitedEvent event,
  ) {
    return _applySessionExitedImpl(this, state, event);
  }

  TranscriptSessionState applyTurnCompleted(
    TranscriptSessionState state,
    TranscriptRuntimeTurnCompletedEvent event,
  ) {
    return _applyTurnCompletedImpl(this, state, event);
  }

  TranscriptSessionState applyTurnAborted(
    TranscriptSessionState state,
    TranscriptRuntimeTurnAbortedEvent event,
  ) {
    return _applyTurnAbortedImpl(this, state, event);
  }

  TranscriptSessionState applyTurnPlanUpdated(
    TranscriptSessionState state,
    TranscriptRuntimeTurnPlanUpdatedEvent event,
  ) {
    return _stateWithAppendedTranscriptBlockImpl(
      this,
      state,
      TranscriptPlanUpdateBlock(
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

  TranscriptSessionState applyItemLifecycle(
    TranscriptSessionState state,
    TranscriptRuntimeItemLifecycleEvent event, {
    required bool removeAfterUpsert,
  }) {
    return _itemPolicy.applyItemLifecycle(
      state,
      event,
      removeAfterUpsert: removeAfterUpsert,
    );
  }

  TranscriptSessionState applyContentDelta(
    TranscriptSessionState state,
    TranscriptRuntimeContentDeltaEvent event,
  ) {
    return _itemPolicy.applyContentDelta(state, event);
  }

  TranscriptSessionState applyRequestOpened(
    TranscriptSessionState state,
    TranscriptRuntimeRequestOpenedEvent event,
  ) {
    return _requestPolicy.applyRequestOpened(state, event);
  }

  TranscriptSessionState applyRequestResolved(
    TranscriptSessionState state,
    TranscriptRuntimeRequestResolvedEvent event,
  ) {
    return _requestPolicy.applyRequestResolved(state, event);
  }

  TranscriptSessionState applyUserInputRequested(
    TranscriptSessionState state,
    TranscriptRuntimeUserInputRequestedEvent event,
  ) {
    return _requestPolicy.applyUserInputRequested(state, event);
  }

  TranscriptSessionState applyUserInputResolved(
    TranscriptSessionState state,
    TranscriptRuntimeUserInputResolvedEvent event,
  ) {
    return _requestPolicy.applyUserInputResolved(state, event);
  }

  TranscriptSessionState applyWarning(
    TranscriptSessionState state,
    TranscriptRuntimeWarningEvent event,
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
        statusKind: TranscriptStatusBlockKind.warning,
        isTranscriptSignal: true,
      ),
      turnId: event.turnId,
      threadId: event.threadId,
    );
  }

  TranscriptSessionState applyUnpinnedHostKey(
    TranscriptSessionState state,
    TranscriptRuntimeUnpinnedHostKeyEvent event,
  ) {
    return _upsertTopLevelTranscriptBlockImpl(
      this,
      state,
      TranscriptSshUnpinnedHostKeyBlock(
        id: _sshUnpinnedHostKeyBlockIdImpl(host: event.host, port: event.port),
        createdAt: event.createdAt,
        host: event.host,
        port: event.port,
        keyType: event.keyType,
        fingerprint: event.fingerprint,
      ),
    );
  }

  TranscriptSessionState applySshConnectFailed(
    TranscriptSessionState state,
    TranscriptRuntimeSshConnectFailedEvent event,
  ) {
    return _upsertTopLevelTranscriptBlockImpl(
      this,
      state,
      TranscriptSshConnectFailedBlock(
        id: _sshConnectFailedBlockIdImpl(host: event.host, port: event.port),
        createdAt: event.createdAt,
        host: event.host,
        port: event.port,
        message: event.message,
      ),
    );
  }

  TranscriptSessionState applySshHostKeyMismatch(
    TranscriptSessionState state,
    TranscriptRuntimeSshHostKeyMismatchEvent event,
  ) {
    return _upsertTopLevelTranscriptBlockImpl(
      this,
      state,
      TranscriptSshHostKeyMismatchBlock(
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

  TranscriptSessionState applySshAuthenticationFailed(
    TranscriptSessionState state,
    TranscriptRuntimeSshAuthenticationFailedEvent event,
  ) {
    return _upsertTopLevelTranscriptBlockImpl(
      this,
      state,
      TranscriptSshAuthenticationFailedBlock(
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

  TranscriptSessionState markUnpinnedHostKeySaved(
    TranscriptSessionState state, {
    required String blockId,
  }) {
    return _markUnpinnedHostKeySavedImpl(state, blockId: blockId);
  }

  TranscriptSessionState applyStatus(
    TranscriptSessionState state,
    TranscriptRuntimeStatusEvent event,
  ) {
    return _applyStatusImpl(this, state, event);
  }

  TranscriptSessionState applyRuntimeError(
    TranscriptSessionState state,
    TranscriptRuntimeErrorEvent event,
  ) {
    return _stateWithTranscriptBlockImpl(
      this,
      state,
      TranscriptErrorBlock(
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
