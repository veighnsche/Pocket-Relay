import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_conversation_recovery_policy.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

void main() {
  const policy = ChatConversationRecoveryPolicy();
  final createdAt = DateTime(2026, 1, 1);

  test(
    'preflightRecoveryState returns detached transcript recovery for a tracked live thread',
    () {
      final sessionState = CodexSessionState(
        sessionBlocks: <CodexUiBlock>[
          CodexUserMessageBlock(
            id: 'user_1',
            createdAt: createdAt,
            text: 'Hello',
            deliveryState: CodexUserMessageDeliveryState.sent,
          ),
        ],
        timelinesByThreadId: const <String, CodexTimelineState>{
          'thread_live': CodexTimelineState(threadId: 'thread_live'),
        },
      );

      final recoveryState = policy.preflightRecoveryState(
        sessionState: sessionState,
        activeThreadId: null,
        trackedThreadId: 'thread_live',
      );

      expect(
        recoveryState?.reason,
        ChatConversationRecoveryReason.detachedTranscript,
      );
      expect(recoveryState?.alternateThreadId, 'thread_live');
    },
  );

  test(
    'assessSendFailure returns missing conversation recovery and suppresses the snackbar',
    () {
      final assessment = policy.assessSendFailure(
        error: const CodexAppServerException(
          'turn/start failed: thread not found',
        ),
        sessionState: const CodexSessionState(
          rootThreadId: 'thread_root',
          timelinesByThreadId: <String, CodexTimelineState>{
            'thread_alt': CodexTimelineState(threadId: 'thread_alt'),
          },
        ),
        sessionLabel: 'remote Codex',
        preferredAlternateThreadId: 'thread_alt',
      );

      expect(
        assessment.recoveryState?.reason,
        ChatConversationRecoveryReason.missingRemoteConversation,
      );
      expect(assessment.recoveryState?.alternateThreadId, 'thread_alt');
      expect(assessment.suppressSnackBar, isTrue);
      expect(assessment.presentation.title, 'Conversation unavailable');
    },
  );

  test(
    'assessSendFailure returns unexpected conversation recovery with expected and actual ids',
    () {
      final assessment = policy.assessSendFailure(
        error: const CodexAppServerException(
          'thread/resume returned a different thread id than requested.',
          data: <String, Object?>{
            'expectedThreadId': 'thread_old',
            'actualThreadId': 'thread_new',
          },
        ),
        sessionState: const CodexSessionState(
          rootThreadId: 'thread_old',
          timelinesByThreadId: <String, CodexTimelineState>{
            'thread_new': CodexTimelineState(threadId: 'thread_new'),
          },
        ),
        sessionLabel: 'remote Codex',
      );

      expect(
        assessment.recoveryState?.reason,
        ChatConversationRecoveryReason.unexpectedRemoteConversation,
      );
      expect(assessment.recoveryState?.expectedThreadId, 'thread_old');
      expect(assessment.recoveryState?.actualThreadId, 'thread_new');
      expect(assessment.recoveryState?.alternateThreadId, 'thread_new');
      expect(assessment.suppressSnackBar, isTrue);
      expect(assessment.presentation.title, 'Conversation changed');
    },
  );

  test(
    'assessSendFailure keeps generic transport failures out of recovery state',
    () {
      final assessment = policy.assessSendFailure(
        error: Exception('network down'),
        sessionState: CodexSessionState.initial(),
        sessionLabel: 'remote Codex',
      );

      expect(assessment.recoveryState, isNull);
      expect(assessment.suppressSnackBar, isFalse);
      expect(assessment.presentation.title, 'Send failed');
      expect(
        assessment.presentation.message,
        'Could not send the prompt to the remote Codex session.',
      );
    },
  );
}
