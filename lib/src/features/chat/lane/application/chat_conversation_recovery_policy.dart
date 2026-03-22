import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

typedef ChatConversationFailurePresentation = ({
  String title,
  String message,
  String? runtimeErrorMessage,
});

class ChatConversationSendFailureAssessment {
  const ChatConversationSendFailureAssessment({
    required this.presentation,
    this.recoveryState,
    this.suppressSnackBar = false,
  });

  final ChatConversationFailurePresentation presentation;
  final ChatConversationRecoveryState? recoveryState;
  final bool suppressSnackBar;
}

class ChatConversationRecoveryPolicy {
  const ChatConversationRecoveryPolicy();

  ChatConversationRecoveryState? preflightRecoveryState({
    required CodexSessionState sessionState,
    required String? activeThreadId,
    required String? trackedThreadId,
  }) {
    if (_normalizeThreadId(activeThreadId) != null) {
      return null;
    }

    final normalizedTrackedThreadId = _normalizeThreadId(trackedThreadId);
    if (normalizedTrackedThreadId == null ||
        !_hasConversationHistory(sessionState)) {
      return null;
    }

    return ChatConversationRecoveryState(
      reason: ChatConversationRecoveryReason.detachedTranscript,
      alternateThreadId: _alternateRecoveryThreadId(
        sessionState: sessionState,
        preferredThreadId: normalizedTrackedThreadId,
      ),
    );
  }

  ChatConversationSendFailureAssessment assessSendFailure({
    required Object error,
    required CodexSessionState sessionState,
    required String sessionLabel,
    String? preferredAlternateThreadId,
  }) {
    if (_unexpectedConversationThread(error) case (
      expectedThreadId: final expectedThreadId,
      actualThreadId: final actualThreadId,
    )) {
      final message =
          'Pocket Relay expected remote conversation "$expectedThreadId", '
          'but the remote session returned "$actualThreadId". Sending is '
          'blocked to avoid attaching your draft to a different conversation.';
      return ChatConversationSendFailureAssessment(
        recoveryState: ChatConversationRecoveryState(
          reason: ChatConversationRecoveryReason.unexpectedRemoteConversation,
          alternateThreadId: _alternateRecoveryThreadId(
            sessionState: sessionState,
            preferredThreadId: actualThreadId,
          ),
          expectedThreadId: expectedThreadId,
          actualThreadId: actualThreadId,
        ),
        suppressSnackBar: true,
        presentation: (
          title: 'Conversation changed',
          message: message,
          runtimeErrorMessage: message,
        ),
      );
    }

    if (_isMissingConversationThreadError(error)) {
      const message =
          'Could not continue this conversation because the remote '
          'conversation was not found. Start a fresh conversation to '
          'continue.';
      return ChatConversationSendFailureAssessment(
        recoveryState: ChatConversationRecoveryState(
          reason: ChatConversationRecoveryReason.missingRemoteConversation,
          alternateThreadId: _alternateRecoveryThreadId(
            sessionState: sessionState,
            preferredThreadId: preferredAlternateThreadId,
          ),
        ),
        suppressSnackBar: true,
        presentation: (
          title: 'Conversation unavailable',
          message: message,
          runtimeErrorMessage: message,
        ),
      );
    }

    return ChatConversationSendFailureAssessment(
      presentation: (
        title: 'Send failed',
        message: 'Could not send the prompt to the $sessionLabel session.',
        runtimeErrorMessage: null,
      ),
    );
  }

  String? _alternateRecoveryThreadId({
    required CodexSessionState sessionState,
    String? preferredThreadId,
  }) {
    final normalizedPreferred = _normalizeThreadId(preferredThreadId);
    final currentRootThreadId = _normalizeThreadId(sessionState.rootThreadId);
    if (normalizedPreferred != null &&
        normalizedPreferred != currentRootThreadId &&
        sessionState.timelineForThread(normalizedPreferred) != null) {
      return normalizedPreferred;
    }
    return null;
  }

  bool _hasConversationHistory(CodexSessionState sessionState) {
    return sessionState.transcriptBlocks.any((block) {
      return switch (block.kind) {
        CodexUiBlockKind.userMessage ||
        CodexUiBlockKind.assistantMessage ||
        CodexUiBlockKind.reasoning ||
        CodexUiBlockKind.plan ||
        CodexUiBlockKind.proposedPlan ||
        CodexUiBlockKind.workLogEntry ||
        CodexUiBlockKind.workLogGroup ||
        CodexUiBlockKind.changedFiles ||
        CodexUiBlockKind.approvalRequest ||
        CodexUiBlockKind.userInputRequest ||
        CodexUiBlockKind.usage ||
        CodexUiBlockKind.turnBoundary => true,
        CodexUiBlockKind.status || CodexUiBlockKind.error => false,
      };
    });
  }

  bool _isMissingConversationThreadError(Object error) {
    final normalizedMessage = error.toString().toLowerCase();
    if (!normalizedMessage.contains('thread')) {
      return false;
    }

    return const <String>[
      'thread not found',
      'missing thread',
      'no such thread',
      'unknown thread',
      'does not exist',
    ].any(normalizedMessage.contains);
  }

  ({String expectedThreadId, String actualThreadId})?
  _unexpectedConversationThread(Object error) {
    if (error is! CodexAppServerException) {
      return null;
    }

    final payload = _asObject(error.data);
    final expectedThreadId = _normalizeThreadId(
      _asString(payload?['expectedThreadId']),
    );
    final actualThreadId = _normalizeThreadId(
      _asString(payload?['actualThreadId']),
    );
    if (expectedThreadId == null || actualThreadId == null) {
      return null;
    }

    return (expectedThreadId: expectedThreadId, actualThreadId: actualThreadId);
  }

  static String? _normalizeThreadId(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }

  static Map<String, dynamic>? _asObject(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static String? _asString(Object? value) {
    return value is String ? value : null;
  }
}
