import 'package:pocket_relay/src/core/errors/pocket_error_detail_formatter.dart';

enum PocketErrorDomain {
  connectionLifecycle,
  chatSession,
  chatComposer,
  connectionSettings,
  appBootstrap,
  deviceCapability,
}

final class PocketErrorDefinition {
  const PocketErrorDefinition({
    required this.code,
    required this.domain,
    required this.meaning,
  });

  final String code;
  final PocketErrorDomain domain;
  final String meaning;
}

final class PocketUserFacingError {
  const PocketUserFacingError({
    required this.definition,
    required this.title,
    required this.message,
    this.underlyingDetail,
  });

  final PocketErrorDefinition definition;
  final String title;
  final String message;
  final String? underlyingDetail;

  String get formattedMessage => PocketErrorDetailFormatter.composeMessage(
    message: message,
    underlyingDetail: underlyingDetail,
  );

  String get inlineMessage {
    final normalizedTitle = title.trim();
    final normalizedMessage = formattedMessage.trim();
    if (normalizedTitle.isEmpty) {
      return '[${definition.code}] $normalizedMessage';
    }
    if (normalizedMessage.isEmpty) {
      return '[${definition.code}] $normalizedTitle';
    }
    return '[${definition.code}] $normalizedTitle. $normalizedMessage';
  }

  String get bodyWithCode => '[${definition.code}] ${formattedMessage.trim()}';

  PocketUserFacingError withUnderlyingDetail(String? detail) {
    final normalizedDetail = detail?.trim();
    if ((underlyingDetail ?? '') == (normalizedDetail ?? '')) {
      return this;
    }
    return PocketUserFacingError(
      definition: definition,
      title: title,
      message: message,
      underlyingDetail: normalizedDetail,
    );
  }

  PocketUserFacingError withNormalizedUnderlyingError(
    Object? error, {
    bool stripRemoteOwnerControlFailure = false,
  }) {
    final detail = PocketErrorDetailFormatter.uniqueUnderlyingDetail(
      existingText: inlineMessage,
      error: error,
      stripRemoteOwnerControlFailure: stripRemoteOwnerControlFailure,
    );
    if (detail == null) {
      return this;
    }
    return withUnderlyingDetail(detail);
  }

  String inlineMessageWithDetail(Object? error) {
    return withNormalizedUnderlyingError(error).inlineMessage;
  }
}

abstract final class PocketErrorCatalog {
  // Connection lifecycle: open lane (11xx).
  static const PocketErrorDefinition
  connectionOpenRemoteHostProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-1101',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed because Pocket Relay could not verify the remote host continuity prerequisites.',
  );
  static const PocketErrorDefinition
  connectionOpenRemoteContinuityUnsupported = PocketErrorDefinition(
    code: 'PR-CONN-1102',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed because the host does not satisfy Pocket Relay continuity requirements.',
  );
  static const PocketErrorDefinition
  connectionOpenRemoteServerStopped = PocketErrorDefinition(
    code: 'PR-CONN-1103',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed because no managed remote app-server is running for the saved remote connection.',
  );
  static const PocketErrorDefinition
  connectionOpenRemoteServerUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-1104',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed because the saved managed remote app-server is present but not healthy enough to attach.',
  );
  static const PocketErrorDefinition
  connectionOpenRemoteAttachUnavailable = PocketErrorDefinition(
    code: 'PR-CONN-1105',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed after the server reported running because Pocket Relay could not attach the lane to the managed remote session.',
  );
  static const PocketErrorDefinition
  connectionOpenRemoteUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CONN-1106',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a remote lane failed for an unexpected connection-lifecycle reason outside the known remote continuity states.',
  );
  static const PocketErrorDefinition
  connectionOpenLocalUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CONN-1107',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Opening a local lane failed for an unexpected connection-lifecycle reason outside the known local startup states.',
  );

  // Connection lifecycle: start server (12xx).
  static const PocketErrorDefinition
  connectionStartServerHostProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-1201',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Starting the managed remote app-server failed because Pocket Relay could not verify the remote host after the start attempt.',
  );
  static const PocketErrorDefinition
  connectionStartServerContinuityUnsupported = PocketErrorDefinition(
    code: 'PR-CONN-1202',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Starting the managed remote app-server failed because the host does not satisfy Pocket Relay continuity requirements.',
  );
  static const PocketErrorDefinition
  connectionStartServerStillStopped = PocketErrorDefinition(
    code: 'PR-CONN-1203',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Starting the managed remote app-server failed because the managed owner was still not running after the start attempt.',
  );
  static const PocketErrorDefinition
  connectionStartServerUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-1204',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Starting the managed remote app-server failed because the managed owner appeared but did not become healthy enough to accept connections.',
  );
  static const PocketErrorDefinition
  connectionStartServerUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CONN-1205',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Starting the managed remote app-server failed for an unexpected reason outside the known post-start runtime states.',
  );

  // Connection lifecycle: stop server (13xx).
  static const PocketErrorDefinition
  connectionStopServerHostProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-1301',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Stopping the managed remote app-server failed because Pocket Relay could not verify the remote host after the stop attempt.',
  );
  static const PocketErrorDefinition
  connectionStopServerContinuityUnsupported = PocketErrorDefinition(
    code: 'PR-CONN-1302',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Stopping the managed remote app-server failed because the host does not satisfy Pocket Relay continuity requirements.',
  );
  static const PocketErrorDefinition
  connectionStopServerStillRunning = PocketErrorDefinition(
    code: 'PR-CONN-1303',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Stopping the managed remote app-server failed because the managed owner was still running after the stop attempt.',
  );
  static const PocketErrorDefinition
  connectionStopServerStillUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-1304',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Stopping the managed remote app-server failed because the managed owner remained present in an unhealthy state after the stop attempt.',
  );
  static const PocketErrorDefinition
  connectionStopServerUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CONN-1305',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Stopping the managed remote app-server failed for an unexpected reason outside the known post-stop runtime states.',
  );

  // Connection lifecycle: restart server (14xx).
  static const PocketErrorDefinition
  connectionRestartServerHostProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-1401',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Restarting the managed remote app-server failed because Pocket Relay could not verify the remote host after the restart attempt.',
  );
  static const PocketErrorDefinition
  connectionRestartServerContinuityUnsupported = PocketErrorDefinition(
    code: 'PR-CONN-1402',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Restarting the managed remote app-server failed because the host does not satisfy Pocket Relay continuity requirements.',
  );
  static const PocketErrorDefinition
  connectionRestartServerStopped = PocketErrorDefinition(
    code: 'PR-CONN-1403',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Restarting the managed remote app-server failed because no managed owner was running after the restart attempt.',
  );
  static const PocketErrorDefinition
  connectionRestartServerUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-1404',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Restarting the managed remote app-server failed because the managed owner did not become healthy enough to accept connections after the restart attempt.',
  );
  static const PocketErrorDefinition
  connectionRestartServerUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CONN-1405',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Restarting the managed remote app-server failed for an unexpected reason outside the known post-restart runtime states.',
  );

  // Connection lifecycle: reconnect and live reattach (21xx).
  static const PocketErrorDefinition
  connectionTransportLost = PocketErrorDefinition(
    code: 'PR-CONN-2101',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'The live lane lost its transport connection to Codex and now requires reconnect handling.',
  );
  static const PocketErrorDefinition
  connectionTransportUnavailable = PocketErrorDefinition(
    code: 'PR-CONN-2102',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Reconnecting the lane transport failed and Pocket Relay could not restore the remote session directly.',
  );
  static const PocketErrorDefinition
  connectionReconnectContinuityUnsupported = PocketErrorDefinition(
    code: 'PR-CONN-2103',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Reconnecting the lane failed because the remote host does not satisfy Pocket Relay continuity requirements.',
  );
  static const PocketErrorDefinition
  connectionReconnectHostProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-2104',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Reconnecting the lane failed because Pocket Relay could not verify the remote host continuity prerequisites.',
  );
  static const PocketErrorDefinition
  connectionReconnectServerStopped = PocketErrorDefinition(
    code: 'PR-CONN-2105',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Reconnecting the lane failed because no managed remote app-server was running for the saved remote connection.',
  );
  static const PocketErrorDefinition
  connectionReconnectServerUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-2106',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Reconnecting the lane failed because the managed remote app-server was present but unhealthy.',
  );
  static const PocketErrorDefinition
  connectionLiveReattachFallbackRestore = PocketErrorDefinition(
    code: 'PR-CONN-2107',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Pocket Relay restored a lane from Codex history after transport reconnect because direct live-session reattach failed.',
  );

  // Connection lifecycle: passive runtime probing (22xx).
  static const PocketErrorDefinition
  connectionRuntimeProbeFailed = PocketErrorDefinition(
    code: 'PR-CONN-2201',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Refreshing passive remote runtime state failed because Pocket Relay could not verify the remote host for the saved connection.',
  );

  // Connection lifecycle: explicit lane disconnect (23xx).
  static const PocketErrorDefinition
  connectionDisconnectLaneFailed = PocketErrorDefinition(
    code: 'PR-CONN-2301',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Disconnecting a live lane failed because Pocket Relay could not close the current app-server transport cleanly.',
  );

  // Connection lifecycle: conversation history (31xx).
  static const PocketErrorDefinition
  connectionHistoryLoadFailed = PocketErrorDefinition(
    code: 'PR-CONN-3101',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Loading authoritative conversation history from Codex failed for a generic connection-lifecycle reason.',
  );
  static const PocketErrorDefinition
  connectionHistoryHostKeyUnpinned = PocketErrorDefinition(
    code: 'PR-CONN-3102',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Loading authoritative conversation history failed because the remote host fingerprint is not pinned for the saved host identity.',
  );
  static const PocketErrorDefinition
  connectionHistoryServerStopped = PocketErrorDefinition(
    code: 'PR-CONN-3103',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Loading authoritative conversation history failed because no managed remote app-server was running for the saved remote connection.',
  );
  static const PocketErrorDefinition
  connectionHistoryServerUnhealthy = PocketErrorDefinition(
    code: 'PR-CONN-3104',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Loading authoritative conversation history failed because the managed remote app-server was present but unhealthy.',
  );
  static const PocketErrorDefinition
  connectionHistorySessionUnavailable = PocketErrorDefinition(
    code: 'PR-CONN-3105',
    domain: PocketErrorDomain.connectionLifecycle,
    meaning:
        'Loading authoritative conversation history failed because Pocket Relay could not attach to the managed remote session even though the owner reported running.',
  );

  // Chat session: send failures (11xx).
  static const PocketErrorDefinition
  chatSessionSendConversationChanged = PocketErrorDefinition(
    code: 'PR-CHAT-1101',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending a prompt failed because the remote session returned a different conversation thread than Pocket Relay expected.',
  );
  static const PocketErrorDefinition
  chatSessionSendConversationUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1102',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending a prompt failed because the target remote conversation thread was no longer available.',
  );
  static const PocketErrorDefinition
  chatSessionSendFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1103',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending a prompt or draft failed for a generic live chat-session reason outside the known conversation-recovery states.',
  );
  static const PocketErrorDefinition
  chatSessionImageSupportCheckFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1104',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending a draft with images failed because Pocket Relay could not connect to Codex to validate image-input support.',
  );

  // Chat session: transcript restore (12xx).
  static const PocketErrorDefinition
  chatSessionConversationLoadFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1201',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Loading a saved conversation transcript into the active chat lane failed.',
  );
  static const PocketErrorDefinition
  chatSessionContinueFromPromptFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1202',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Continuing from an earlier prompt failed because Pocket Relay could not rewind the active conversation state from Codex.',
  );
  static const PocketErrorDefinition
  chatSessionBranchConversationFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1203',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Branching the selected conversation failed because Pocket Relay could not fork and restore the new Codex conversation state.',
  );

  // Chat session: turn control (13xx).
  static const PocketErrorDefinition
  chatSessionStopTurnFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1301',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Stopping the active Codex turn failed for the selected live chat lane.',
  );

  // Chat session: interactive request handling (14xx).
  static const PocketErrorDefinition
  chatSessionSubmitUserInputFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1401',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Submitting requested user input back to the active Codex session failed.',
  );
  static const PocketErrorDefinition chatSessionApproveRequestFailed =
      PocketErrorDefinition(
        code: 'PR-CHAT-1402',
        domain: PocketErrorDomain.chatSession,
        meaning: 'Approving a pending live-session request failed.',
      );
  static const PocketErrorDefinition chatSessionDenyRequestFailed =
      PocketErrorDefinition(
        code: 'PR-CHAT-1403',
        domain: PocketErrorDomain.chatSession,
        meaning: 'Denying a pending live-session request failed.',
      );
  static const PocketErrorDefinition
  chatSessionRejectUnsupportedRequestFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1404',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Rejecting an unsupported app-server request from the active live session failed.',
  );
  static const PocketErrorDefinition
  chatSessionUserInputRequestUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1405',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Submitting user input was blocked because the target request was no longer pending in the active chat session.',
  );
  static const PocketErrorDefinition
  chatSessionApprovalRequestUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1406',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Resolving an approval request was blocked because the target request was no longer pending in the active chat session.',
  );

  // Chat session: send guardrails and prerequisites (15xx).
  static const PocketErrorDefinition
  chatSessionHostFingerprintPromptUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1501',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Saving an observed host fingerprint was blocked because the referenced host-key prompt was no longer available in the transcript.',
  );
  static const PocketErrorDefinition
  chatSessionHostFingerprintConflict = PocketErrorDefinition(
    code: 'PR-CHAT-1502',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Saving an observed host fingerprint was blocked because the profile already stores a different pinned fingerprint.',
  );
  static const PocketErrorDefinition
  chatSessionHostFingerprintSaveFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1503',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Saving an observed host fingerprint failed because Pocket Relay could not persist the updated profile.',
  );
  static const PocketErrorDefinition
  chatSessionRemoteConfigurationRequired = PocketErrorDefinition(
    code: 'PR-CHAT-1504',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending was blocked because the remote connection profile is incomplete.',
  );
  static const PocketErrorDefinition
  chatSessionLocalConfigurationRequired = PocketErrorDefinition(
    code: 'PR-CHAT-1505',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending was blocked because the selected local agent-adapter profile is incomplete.',
  );
  static const PocketErrorDefinition
  chatSessionLocalModeUnsupported = PocketErrorDefinition(
    code: 'PR-CHAT-1506',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending was blocked because local agent-adapter mode is unavailable on the current platform.',
  );
  static const PocketErrorDefinition
  chatSessionSshPasswordRequired = PocketErrorDefinition(
    code: 'PR-CHAT-1507',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending was blocked because the selected remote profile requires an SSH password that is not present.',
  );
  static const PocketErrorDefinition
  chatSessionPrivateKeyRequired = PocketErrorDefinition(
    code: 'PR-CHAT-1508',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending was blocked because the selected remote profile requires a private key that is not present.',
  );
  static const PocketErrorDefinition
  chatSessionImageInputUnsupported = PocketErrorDefinition(
    code: 'PR-CHAT-1509',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Sending a draft was blocked because the effective model does not support image inputs.',
  );

  // Chat session: recovery guardrails (16xx).
  static const PocketErrorDefinition
  chatSessionFreshConversationBlocked = PocketErrorDefinition(
    code: 'PR-CHAT-1601',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Starting a fresh conversation was blocked because the lane still has an active turn or busy state.',
  );
  static const PocketErrorDefinition
  chatSessionClearTranscriptBlocked = PocketErrorDefinition(
    code: 'PR-CHAT-1602',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Clearing the transcript was blocked because the lane still has an active turn or busy state.',
  );
  static const PocketErrorDefinition
  chatSessionAlternateSessionUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1603',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Switching to the alternate recovered session was blocked because that local session is no longer available.',
  );
  static const PocketErrorDefinition
  chatSessionContinueBlockedByTranscriptRestore = PocketErrorDefinition(
    code: 'PR-CHAT-1604',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Continuing from an earlier prompt was blocked because transcript restoration is still in progress.',
  );
  static const PocketErrorDefinition
  chatSessionContinueBlockedByActiveTurn = PocketErrorDefinition(
    code: 'PR-CHAT-1605',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Continuing from an earlier prompt was blocked because the lane still has an active turn or busy state.',
  );
  static const PocketErrorDefinition
  chatSessionContinueTargetUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1606',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Continuing from an earlier prompt was blocked because there is no resumable active conversation target yet.',
  );
  static const PocketErrorDefinition
  chatSessionContinuePromptUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1607',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Continuing from an earlier prompt was blocked because the selected user prompt is no longer available in the transcript.',
  );
  static const PocketErrorDefinition
  chatSessionBranchBlockedByTranscriptRestore = PocketErrorDefinition(
    code: 'PR-CHAT-1608',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Branching the selected conversation was blocked because transcript restoration is still in progress.',
  );
  static const PocketErrorDefinition
  chatSessionBranchBlockedByActiveTurn = PocketErrorDefinition(
    code: 'PR-CHAT-1609',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Branching the selected conversation was blocked because the lane still has an active turn or busy state.',
  );
  static const PocketErrorDefinition
  chatSessionBranchTargetUnavailable = PocketErrorDefinition(
    code: 'PR-CHAT-1610',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Branching the selected conversation was blocked because there is no selectable conversation target yet.',
  );

  // Chat session: best-effort diagnostics (18xx).
  static const PocketErrorDefinition
  chatSessionModelCatalogHydrationFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1801',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Refreshing the best-effort live model catalog after transport connection failed, so capability checks may remain incomplete until a later retry succeeds.',
  );
  static const PocketErrorDefinition
  chatSessionThreadMetadataHydrationFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1802',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Reading best-effort child-thread metadata failed, so timeline labels may remain incomplete until later runtime data fills them in.',
  );

  // Connection settings: model refresh (11xx).
  static const PocketErrorDefinition
  connectionSettingsModelCatalogUnavailable = PocketErrorDefinition(
    code: 'PR-CONNSET-1101',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Refreshing models in the connection settings sheet did not produce a backend model catalog.',
  );
  static const PocketErrorDefinition
  connectionSettingsModelCatalogRefreshFailed = PocketErrorDefinition(
    code: 'PR-CONNSET-1102',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Refreshing models in the connection settings sheet failed because the backend refresh call threw an error.',
  );
  static const PocketErrorDefinition
  connectionSettingsModelCatalogConnectionCacheSaveFailed = PocketErrorDefinition(
    code: 'PR-CONNSET-1103',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Refreshing models in the connection settings sheet succeeded, but Pocket Relay could not save the connection-scoped cached model catalog.',
  );
  static const PocketErrorDefinition
  connectionSettingsModelCatalogLastKnownCacheSaveFailed = PocketErrorDefinition(
    code: 'PR-CONNSET-1104',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Refreshing models in the connection settings sheet succeeded, but Pocket Relay could not save the shared last-known cached model catalog.',
  );
  static const PocketErrorDefinition
  connectionSettingsModelCatalogCachePersistenceFailed = PocketErrorDefinition(
    code: 'PR-CONNSET-1105',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Refreshing models in the connection settings sheet succeeded, but Pocket Relay could not save either local model catalog cache.',
  );

  // Connection settings: remote runtime probing (12xx).
  static const PocketErrorDefinition
  connectionSettingsRemoteRuntimeProbeFailed = PocketErrorDefinition(
    code: 'PR-CONNSET-1201',
    domain: PocketErrorDomain.connectionSettings,
    meaning:
        'Probing the remote target from the connection settings sheet failed before Pocket Relay could determine continuity support.',
  );

  // App bootstrap: workspace initialization (11xx).
  static const PocketErrorDefinition
  appBootstrapWorkspaceInitializationFailed = PocketErrorDefinition(
    code: 'PR-BOOT-1101',
    domain: PocketErrorDomain.appBootstrap,
    meaning:
        'Pocket Relay failed to initialize the workspace shell during app bootstrap.',
  );
  static const PocketErrorDefinition
  appBootstrapRecoveryStateLoadFailed = PocketErrorDefinition(
    code: 'PR-BOOT-1102',
    domain: PocketErrorDomain.appBootstrap,
    meaning:
        'Pocket Relay could not restore the previously persisted local workspace recovery state during app bootstrap, so startup continued without that recovery snapshot.',
  );

  // Device capability: active-turn continuity hosts (11xx).
  static const PocketErrorDefinition
  deviceForegroundServicePermissionQueryFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1101',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not verify notification permission before trying to enable the Android foreground service used for active-turn continuity.',
  );
  static const PocketErrorDefinition
  deviceForegroundServicePermissionRequestFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1102',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not request notification permission before trying to enable the Android foreground service used for active-turn continuity.',
  );
  static const PocketErrorDefinition
  deviceForegroundServiceEnableFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1103',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not enable or disable the Android foreground service used for active-turn continuity.',
  );
  static const PocketErrorDefinition
  deviceBackgroundGraceEnableFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1104',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not enable or disable the finite background-grace host used to preserve an active turn while the app is backgrounded.',
  );
  static const PocketErrorDefinition
  deviceWakeLockEnableFailed = PocketErrorDefinition(
    code: 'PR-DEVICE-1105',
    domain: PocketErrorDomain.deviceCapability,
    meaning:
        'Pocket Relay could not enable or disable the display wake lock used to preserve an active turn while the app remains in the foreground.',
  );

  // Chat session: image attachment (15xx).
  static const PocketErrorDefinition chatSessionImageAttachmentEmpty =
      PocketErrorDefinition(
        code: 'PR-CHAT-1501',
        domain: PocketErrorDomain.chatSession,
        meaning:
            'Attaching an image failed because the selected file was empty.',
      );
  static const PocketErrorDefinition
  chatSessionImageAttachmentTooLarge = PocketErrorDefinition(
    code: 'PR-CHAT-1502',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Attaching an image failed because the selected file exceeded Pocket Relay attachment limits.',
  );
  static const PocketErrorDefinition
  chatSessionImageAttachmentUnsupportedType = PocketErrorDefinition(
    code: 'PR-CHAT-1503',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Attaching an image failed because the selected file was not a supported image type.',
  );
  static const PocketErrorDefinition
  chatSessionImageAttachmentDecodeFailed = PocketErrorDefinition(
    code: 'PR-CHAT-1504',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Attaching an image failed because Pocket Relay could not decode the selected file as an image payload.',
  );
  static const PocketErrorDefinition
  chatSessionImageAttachmentTooLargeForRemote = PocketErrorDefinition(
    code: 'PR-CHAT-1505',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Attaching an image failed because Pocket Relay could not shrink the selected image enough for remote sending.',
  );
  static const PocketErrorDefinition
  chatSessionImageAttachmentUnexpectedFailure = PocketErrorDefinition(
    code: 'PR-CHAT-1506',
    domain: PocketErrorDomain.chatSession,
    meaning:
        'Attaching an image failed for an unexpected local picker or preprocessing reason outside the known attachment-validation states.',
  );

  static const List<PocketErrorDefinition> connectionLifecycleDefinitions =
      <PocketErrorDefinition>[
        connectionOpenRemoteHostProbeFailed,
        connectionOpenRemoteContinuityUnsupported,
        connectionOpenRemoteServerStopped,
        connectionOpenRemoteServerUnhealthy,
        connectionOpenRemoteAttachUnavailable,
        connectionOpenRemoteUnexpectedFailure,
        connectionOpenLocalUnexpectedFailure,
        connectionStartServerHostProbeFailed,
        connectionStartServerContinuityUnsupported,
        connectionStartServerStillStopped,
        connectionStartServerUnhealthy,
        connectionStartServerUnexpectedFailure,
        connectionStopServerHostProbeFailed,
        connectionStopServerContinuityUnsupported,
        connectionStopServerStillRunning,
        connectionStopServerStillUnhealthy,
        connectionStopServerUnexpectedFailure,
        connectionRestartServerHostProbeFailed,
        connectionRestartServerContinuityUnsupported,
        connectionRestartServerStopped,
        connectionRestartServerUnhealthy,
        connectionRestartServerUnexpectedFailure,
        connectionTransportLost,
        connectionTransportUnavailable,
        connectionReconnectContinuityUnsupported,
        connectionReconnectHostProbeFailed,
        connectionReconnectServerStopped,
        connectionReconnectServerUnhealthy,
        connectionLiveReattachFallbackRestore,
        connectionRuntimeProbeFailed,
        connectionDisconnectLaneFailed,
        connectionHistoryLoadFailed,
        connectionHistoryHostKeyUnpinned,
        connectionHistoryServerStopped,
        connectionHistoryServerUnhealthy,
        connectionHistorySessionUnavailable,
      ];

  static const List<PocketErrorDefinition> chatSessionDefinitions =
      <PocketErrorDefinition>[
        chatSessionSendConversationChanged,
        chatSessionSendConversationUnavailable,
        chatSessionSendFailed,
        chatSessionImageSupportCheckFailed,
        chatSessionConversationLoadFailed,
        chatSessionContinueFromPromptFailed,
        chatSessionBranchConversationFailed,
        chatSessionStopTurnFailed,
        chatSessionSubmitUserInputFailed,
        chatSessionApproveRequestFailed,
        chatSessionDenyRequestFailed,
        chatSessionRejectUnsupportedRequestFailed,
        chatSessionUserInputRequestUnavailable,
        chatSessionApprovalRequestUnavailable,
        chatSessionHostFingerprintPromptUnavailable,
        chatSessionHostFingerprintConflict,
        chatSessionHostFingerprintSaveFailed,
        chatSessionRemoteConfigurationRequired,
        chatSessionLocalConfigurationRequired,
        chatSessionLocalModeUnsupported,
        chatSessionSshPasswordRequired,
        chatSessionPrivateKeyRequired,
        chatSessionImageInputUnsupported,
        chatSessionFreshConversationBlocked,
        chatSessionClearTranscriptBlocked,
        chatSessionAlternateSessionUnavailable,
        chatSessionContinueBlockedByTranscriptRestore,
        chatSessionContinueBlockedByActiveTurn,
        chatSessionContinueTargetUnavailable,
        chatSessionContinuePromptUnavailable,
        chatSessionBranchBlockedByTranscriptRestore,
        chatSessionBranchBlockedByActiveTurn,
        chatSessionBranchTargetUnavailable,
        chatSessionModelCatalogHydrationFailed,
        chatSessionThreadMetadataHydrationFailed,
        chatSessionImageAttachmentEmpty,
        chatSessionImageAttachmentTooLarge,
        chatSessionImageAttachmentUnsupportedType,
        chatSessionImageAttachmentDecodeFailed,
        chatSessionImageAttachmentTooLargeForRemote,
        chatSessionImageAttachmentUnexpectedFailure,
      ];

  static const List<PocketErrorDefinition> connectionSettingsDefinitions =
      <PocketErrorDefinition>[
        connectionSettingsModelCatalogUnavailable,
        connectionSettingsModelCatalogRefreshFailed,
        connectionSettingsModelCatalogConnectionCacheSaveFailed,
        connectionSettingsModelCatalogLastKnownCacheSaveFailed,
        connectionSettingsModelCatalogCachePersistenceFailed,
        connectionSettingsRemoteRuntimeProbeFailed,
      ];

  static const List<PocketErrorDefinition> appBootstrapDefinitions =
      <PocketErrorDefinition>[
        appBootstrapWorkspaceInitializationFailed,
        appBootstrapRecoveryStateLoadFailed,
      ];

  static const List<PocketErrorDefinition> deviceCapabilityDefinitions =
      <PocketErrorDefinition>[
        deviceForegroundServicePermissionQueryFailed,
        deviceForegroundServicePermissionRequestFailed,
        deviceForegroundServiceEnableFailed,
        deviceBackgroundGraceEnableFailed,
        deviceWakeLockEnableFailed,
      ];

  static const List<PocketErrorDefinition> allDefinitions =
      <PocketErrorDefinition>[
        ...connectionLifecycleDefinitions,
        ...chatSessionDefinitions,
        ...connectionSettingsDefinitions,
        ...appBootstrapDefinitions,
        ...deviceCapabilityDefinitions,
      ];

  static PocketErrorDefinition? lookup(String code) {
    for (final definition in allDefinitions) {
      if (definition.code == code) {
        return definition;
      }
    }
    return null;
  }
}
