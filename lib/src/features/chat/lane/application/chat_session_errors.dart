import 'package:pocket_relay/src/core/errors/pocket_error.dart';

abstract final class ChatSessionErrors {
  static PocketUserFacingError sendConversationChanged({
    required String expectedThreadId,
    required String actualThreadId,
  }) {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionSendConversationChanged,
      title: 'Conversation changed',
      message:
          'Pocket Relay expected remote conversation "$expectedThreadId", but the remote session returned "$actualThreadId". Sending is blocked to avoid attaching your draft to a different conversation.',
    );
  }

  static PocketUserFacingError sendConversationUnavailable() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionSendConversationUnavailable,
      title: 'Conversation unavailable',
      message:
          'Could not continue this conversation because the remote conversation was not found. Start a fresh conversation to continue.',
    );
  }

  static PocketUserFacingError sendFailed({required String sessionLabel}) {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionSendFailed,
      title: 'Send failed',
      message: 'Could not send the prompt to the $sessionLabel session.',
    );
  }

  static PocketUserFacingError imageSupportCheckFailed() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionImageSupportCheckFailed,
      title: 'Send failed',
      message: 'Could not connect to Codex to validate image support.',
    );
  }

  static PocketUserFacingError conversationLoadFailed() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionConversationLoadFailed,
      title: 'Conversation load failed',
      message: 'Could not load the saved conversation transcript.',
    );
  }

  static PocketUserFacingError continueFromPromptFailed() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionContinueFromPromptFailed,
      title: 'Continue from prompt failed',
      message: 'Could not rewind this conversation to the selected prompt.',
    );
  }

  static PocketUserFacingError branchConversationFailed() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionBranchConversationFailed,
      title: 'Branch conversation failed',
      message: 'Could not branch this conversation from Codex.',
    );
  }

  static PocketUserFacingError stopTurnFailed() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionStopTurnFailed,
      title: 'Stop failed',
      message: 'Could not stop the active Codex turn.',
    );
  }

  static PocketUserFacingError submitUserInputFailed() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionSubmitUserInputFailed,
      title: 'Input failed',
      message: 'Could not submit the requested user input.',
    );
  }

  static PocketUserFacingError approveRequestFailed() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionApproveRequestFailed,
      title: 'Approval failed',
      message: 'Could not submit the decision for this request.',
    );
  }

  static PocketUserFacingError denyRequestFailed() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionDenyRequestFailed,
      title: 'Denial failed',
      message: 'Could not submit the decision for this request.',
    );
  }

  static PocketUserFacingError modelCatalogHydrationFailed({Object? error}) {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionModelCatalogHydrationFailed,
      title: 'Model capabilities unavailable',
      message:
          'Pocket Relay could not refresh the live model catalog after connecting. Capability checks such as image-input support may stay incomplete until a later retry succeeds.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError threadMetadataHydrationFailed({
    required String threadId,
    Object? error,
  }) {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionThreadMetadataHydrationFailed,
      title: 'Thread labels unavailable',
      message:
          'Pocket Relay could not load metadata for thread "$threadId". Timeline labels may stay incomplete until a later restore provides that metadata.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError rejectUnsupportedRequestFailed() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionRejectUnsupportedRequestFailed,
      title: 'Request handling failed',
      message: 'Could not reject an unsupported app-server request.',
    );
  }

  static String runtimeMessage(
    PocketUserFacingError userFacingError, {
    Object? error,
  }) {
    return userFacingError.withNormalizedUnderlyingError(error).inlineMessage;
  }
}
