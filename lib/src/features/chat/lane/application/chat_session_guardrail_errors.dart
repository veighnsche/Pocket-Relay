import 'package:pocket_relay/src/core/errors/pocket_error.dart';

abstract final class ChatSessionGuardrailErrors {
  static PocketUserFacingError hostFingerprintPromptUnavailable() {
    return PocketUserFacingError(
      definition:
          PocketErrorCatalog.chatSessionHostFingerprintPromptUnavailable,
      title: 'Host fingerprint unavailable',
      message: 'This host fingerprint prompt is no longer available.',
    );
  }

  static PocketUserFacingError hostFingerprintConflict() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionHostFingerprintConflict,
      title: 'Host fingerprint conflict',
      message:
          'This profile already has a different pinned host fingerprint. Review the connection settings before replacing it.',
    );
  }

  static PocketUserFacingError hostFingerprintSaveFailed({Object? error}) {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionHostFingerprintSaveFailed,
      title: 'Host fingerprint save failed',
      message: 'Could not save the host fingerprint to this profile.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError remoteConnectionDetailsRequired() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionRemoteConfigurationRequired,
      title: 'Connection details required',
      message: 'Fill in the remote connection details first.',
    );
  }

  static PocketUserFacingError localConfigurationRequired() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionLocalConfigurationRequired,
      title: 'Local settings required',
      message: 'Fill in the local agent adapter settings first.',
    );
  }

  static PocketUserFacingError localModeUnsupported() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionLocalModeUnsupported,
      title: 'Local mode unavailable',
      message: 'Local agent adapters are only available on desktop.',
    );
  }

  static PocketUserFacingError sshPasswordRequired() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionSshPasswordRequired,
      title: 'Password required',
      message: 'This profile needs an SSH password.',
    );
  }

  static PocketUserFacingError privateKeyRequired() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionPrivateKeyRequired,
      title: 'Private key required',
      message: 'This profile needs a private key.',
    );
  }

  static PocketUserFacingError imageInputUnsupported({String? model}) {
    final normalizedModel = model?.trim();
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionImageInputUnsupported,
      title: 'Image input unsupported',
      message: normalizedModel == null || normalizedModel.isEmpty
          ? 'This model does not support image inputs. Remove images or switch models.'
          : 'Model $normalizedModel does not support image inputs. Remove images or switch models.',
    );
  }

  static PocketUserFacingError userInputRequestUnavailable() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionUserInputRequestUnavailable,
      title: 'Input request unavailable',
      message: 'This input request is no longer pending.',
    );
  }

  static PocketUserFacingError approvalRequestUnavailable() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionApprovalRequestUnavailable,
      title: 'Approval request unavailable',
      message: 'This approval request is no longer pending.',
    );
  }

  static PocketUserFacingError freshConversationBlockedByActiveTurn() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionFreshConversationBlocked,
      title: 'Fresh conversation blocked',
      message: 'Stop the active turn before starting a new thread.',
    );
  }

  static PocketUserFacingError clearTranscriptBlockedByActiveTurn() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionClearTranscriptBlocked,
      title: 'Clear transcript blocked',
      message: 'Stop the active turn before clearing the transcript.',
    );
  }

  static PocketUserFacingError alternateSessionUnavailable() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionAlternateSessionUnavailable,
      title: 'Alternate session unavailable',
      message: 'That active session is no longer available locally.',
    );
  }

  static PocketUserFacingError continueBlockedByTranscriptRestore() {
    return PocketUserFacingError(
      definition:
          PocketErrorCatalog.chatSessionContinueBlockedByTranscriptRestore,
      title: 'Continue blocked',
      message: 'Wait for transcript restore before continuing from here.',
    );
  }

  static PocketUserFacingError continueBlockedByActiveTurn() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionContinueBlockedByActiveTurn,
      title: 'Continue blocked',
      message: 'Stop the active turn before continuing from here.',
    );
  }

  static PocketUserFacingError continueTargetUnavailable() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionContinueTargetUnavailable,
      title: 'Continue unavailable',
      message: 'This conversation cannot continue from that prompt yet.',
    );
  }

  static PocketUserFacingError continuePromptUnavailable() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionContinuePromptUnavailable,
      title: 'Prompt unavailable',
      message: 'That prompt is no longer available for continuation.',
    );
  }

  static PocketUserFacingError branchBlockedByTranscriptRestore() {
    return PocketUserFacingError(
      definition:
          PocketErrorCatalog.chatSessionBranchBlockedByTranscriptRestore,
      title: 'Branch blocked',
      message: 'Wait for transcript restore before branching.',
    );
  }

  static PocketUserFacingError branchBlockedByActiveTurn() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionBranchBlockedByActiveTurn,
      title: 'Branch blocked',
      message: 'Stop the active turn before branching this conversation.',
    );
  }

  static PocketUserFacingError branchTargetUnavailable() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.chatSessionBranchTargetUnavailable,
      title: 'Branch unavailable',
      message: 'This conversation cannot be branched yet.',
    );
  }
}
