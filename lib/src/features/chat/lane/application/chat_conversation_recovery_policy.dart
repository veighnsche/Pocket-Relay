import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/lane/application/chat_session_errors.dart';

typedef ChatConversationFailurePresentation = ({
  PocketUserFacingError userFacingError,
  String runtimeErrorMessage,
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
    required TranscriptSessionState sessionState,
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
    required TranscriptSessionState sessionState,
    required String sessionLabel,
    String? preferredAlternateThreadId,
  }) {
    if (_unexpectedConversationThread(error) case (
      expectedThreadId: final expectedThreadId,
      actualThreadId: final actualThreadId,
    )) {
      final userFacingError = ChatSessionErrors.sendConversationChanged(
        expectedThreadId: expectedThreadId,
        actualThreadId: actualThreadId,
      );
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
          userFacingError: userFacingError,
          runtimeErrorMessage: userFacingError.inlineMessage,
        ),
      );
    }

    if (_isMissingConversationThreadError(error)) {
      final userFacingError = ChatSessionErrors.sendConversationUnavailable();
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
          userFacingError: userFacingError,
          runtimeErrorMessage: userFacingError.inlineMessage,
        ),
      );
    }

    final userFacingError = ChatSessionErrors.sendFailed(
      sessionLabel: sessionLabel,
    );
    return ChatConversationSendFailureAssessment(
      presentation: (
        userFacingError: userFacingError,
        runtimeErrorMessage: ChatSessionErrors.runtimeMessage(
          userFacingError,
          error: error,
        ),
      ),
    );
  }

  String? _alternateRecoveryThreadId({
    required TranscriptSessionState sessionState,
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

  bool _hasConversationHistory(TranscriptSessionState sessionState) {
    return sessionState.transcriptBlocks.any((block) {
      return switch (block.kind) {
        TranscriptUiBlockKind.userMessage ||
        TranscriptUiBlockKind.assistantMessage ||
        TranscriptUiBlockKind.reasoning ||
        TranscriptUiBlockKind.plan ||
        TranscriptUiBlockKind.proposedPlan ||
        TranscriptUiBlockKind.workLogEntry ||
        TranscriptUiBlockKind.workLogGroup ||
        TranscriptUiBlockKind.changedFiles ||
        TranscriptUiBlockKind.approvalRequest ||
        TranscriptUiBlockKind.userInputRequest ||
        TranscriptUiBlockKind.usage ||
        TranscriptUiBlockKind.turnBoundary => true,
        TranscriptUiBlockKind.status || TranscriptUiBlockKind.error => false,
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
