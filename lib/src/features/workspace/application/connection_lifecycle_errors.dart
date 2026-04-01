import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/errors/pocket_error_detail_formatter.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';

abstract final class ConnectionLifecycleErrors {
  static PocketUserFacingError openConnectionFailure({
    required ConnectionProfile profile,
    ConnectionRemoteRuntimeState? remoteRuntime,
    Object? error,
  }) {
    if (profile.connectionMode == ConnectionMode.local) {
      final message = PocketErrorDetailFormatter.resolvePrimaryMessage(
        error: error,
        fallbackMessage: 'Verify the saved connection, then try again.',
      );
      return PocketUserFacingError(
        definition: PocketErrorCatalog.connectionOpenLocalUnexpectedFailure,
        title: 'Could not open lane',
        message: message,
      );
    }

    final runtimeResolution = _openRemoteResolution(remoteRuntime);
    if (runtimeResolution != null) {
      return PocketUserFacingError(
        definition: runtimeResolution.$1,
        title: 'Could not open lane',
        message: runtimeResolution.$2,
      );
    }

    final errorDetail = PocketErrorDetailFormatter.normalize(error);
    if (errorDetail != null) {
      return PocketUserFacingError(
        definition: PocketErrorCatalog.connectionOpenRemoteUnexpectedFailure,
        title: 'Could not open lane',
        message: errorDetail,
      );
    }

    return PocketUserFacingError(
      definition: PocketErrorCatalog.connectionOpenRemoteUnexpectedFailure,
      title: 'Could not open lane',
      message:
          'Verify the saved connection and managed remote app-server, then try again.',
    );
  }

  static PocketUserFacingError remoteServerActionFailure(
    ConnectionSettingsRemoteServerActionId actionId, {
    ConnectionRemoteRuntimeState? remoteRuntime,
    Object? error,
  }) {
    final resolution = _remoteServerActionResolution(actionId, remoteRuntime);
    final message = PocketErrorDetailFormatter.resolvePrimaryMessage(
      preferredMessage: resolution?.$2,
      error: error,
      fallbackMessage: _genericRemoteServerActionFailureMessage(actionId),
      stripRemoteOwnerControlFailure: true,
    );
    return PocketUserFacingError(
      definition:
          resolution?.$1 ?? _unexpectedRemoteServerActionDefinition(actionId),
      title: 'Could not ${_remoteServerActionVerb(actionId)}',
      message: message,
    ).withNormalizedUnderlyingError(
      resolution?.$2 == null ? null : error,
      stripRemoteOwnerControlFailure: true,
    );
  }

  static PocketUserFacingError transportLostNotice() {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.connectionTransportLost,
      title: 'Live transport lost',
      message:
          'Pocket Relay lost the live connection to Codex. Your draft is preserved below until the lane reconnects.',
    );
  }

  static PocketUserFacingError transportUnavailableNotice(
    ConnectionRemoteRuntimeState? remoteRuntime, {
    String? recoveryFailureDetail,
  }) {
    return switch (remoteRuntime?.hostCapability.status) {
      ConnectionRemoteHostCapabilityStatus.unsupported => PocketUserFacingError(
        definition: PocketErrorCatalog.connectionReconnectContinuityUnsupported,
        title: 'Remote continuity unavailable',
        message:
            remoteRuntime?.hostCapability.detail ??
            'This host does not currently satisfy Pocket Relay continuity requirements. Verify SSH access, tmux, workspace access, and the configured agent command, then reconnect this lane.',
      ),
      ConnectionRemoteHostCapabilityStatus.probeFailed => PocketUserFacingError(
        definition: PocketErrorCatalog.connectionReconnectHostProbeFailed,
        title: 'Remote continuity unavailable',
        message:
            remoteRuntime?.hostCapability.detail ??
            'This host does not currently satisfy Pocket Relay continuity requirements. Verify SSH access, tmux, workspace access, and the configured agent command, then reconnect this lane.',
      ),
      _ => switch (remoteRuntime?.server.status) {
        ConnectionRemoteServerStatus.notRunning => PocketUserFacingError(
          definition: PocketErrorCatalog.connectionReconnectServerStopped,
          title: 'Remote server stopped',
          message:
              remoteRuntime?.server.detail ??
              'The managed remote app-server for this connection is not running. Start it from this lane, then reconnect.',
        ),
        ConnectionRemoteServerStatus.unhealthy => PocketUserFacingError(
          definition: PocketErrorCatalog.connectionReconnectServerUnhealthy,
          title: 'Remote server unhealthy',
          message:
              remoteRuntime?.server.detail ??
              'The managed remote app-server exists but is not healthy enough to accept connections. Restart it from this lane, then reconnect.',
        ),
        _ => PocketUserFacingError(
          definition: PocketErrorCatalog.connectionTransportUnavailable,
          title: 'Remote session unavailable',
          message:
              'Pocket Relay could not reconnect this lane to Codex. Your draft is preserved below. Try reconnecting again.',
        ).withUnderlyingDetail(recoveryFailureDetail),
      },
    };
  }

  static PocketUserFacingError liveReattachFallbackNotice({
    String? reattachFailureDetail,
  }) {
    return const PocketUserFacingError(
      definition: PocketErrorCatalog.connectionLiveReattachFallbackRestore,
      title: 'Restoring conversation from history',
      message:
          'Pocket Relay reconnected the lane transport but could not reattach the live remote session directly. It is restoring the conversation from Codex history instead.',
    ).withUnderlyingDetail(reattachFailureDetail);
  }

  static PocketUserFacingError connectLaneFailure({
    ConnectionRemoteRuntimeState? remoteRuntime,
    Object? error,
  }) {
    final unavailable = transportUnavailableNotice(remoteRuntime);
    return PocketUserFacingError(
      definition: unavailable.definition,
      title: 'Could not connect lane',
      message: unavailable.message,
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError remoteRuntimeProbeFailure({Object? error}) {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.connectionRuntimeProbeFailed,
      title: 'Remote continuity unavailable',
      message:
          'Pocket Relay could not verify the remote host for this connection.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError disconnectLaneFailure({Object? error}) {
    return PocketUserFacingError(
      definition: PocketErrorCatalog.connectionDisconnectLaneFailed,
      title: 'Could not disconnect lane',
      message: 'Pocket Relay could not close the live transport for this lane.',
    ).withNormalizedUnderlyingError(error);
  }

  static PocketUserFacingError conversationHistoryFailure(Object error) {
    if (error is WorkspaceConversationHistoryUnpinnedHostKeyException) {
      return PocketUserFacingError(
        definition: PocketErrorCatalog.connectionHistoryHostKeyUnpinned,
        title: 'Host key not pinned',
        message:
            'Conversation history cannot connect until this host fingerprint is saved for this host identity.\nObserved fingerprint: ${error.fingerprint}',
      );
    }

    if (error is CodexRemoteAppServerAttachException) {
      return switch (error.snapshot.status) {
        CodexRemoteAppServerOwnerStatus.missing ||
        CodexRemoteAppServerOwnerStatus.stopped => PocketUserFacingError(
          definition: PocketErrorCatalog.connectionHistoryServerStopped,
          title: 'Remote server stopped',
          message: error.message.trim().isEmpty
              ? 'Managed remote app-server is not running for this connection.'
              : error.message,
        ),
        CodexRemoteAppServerOwnerStatus.unhealthy => PocketUserFacingError(
          definition: PocketErrorCatalog.connectionHistoryServerUnhealthy,
          title: 'Remote server unhealthy',
          message: error.message.trim().isEmpty
              ? 'Managed remote app-server is unhealthy and cannot load conversation history.'
              : error.message,
        ),
        CodexRemoteAppServerOwnerStatus.running => PocketUserFacingError(
          definition: PocketErrorCatalog.connectionHistorySessionUnavailable,
          title: 'Remote session unavailable',
          message: error.message.trim().isEmpty
              ? 'Pocket Relay could not attach to the managed remote session to load conversation history.'
              : error.message,
        ),
      };
    }

    return PocketUserFacingError(
      definition: PocketErrorCatalog.connectionHistoryLoadFailed,
      title: 'Could not load conversations',
      message: PocketErrorDetailFormatter.resolvePrimaryMessage(
        error: error,
        fallbackMessage:
            'Pocket Relay could not load conversations from Codex.',
      ),
    );
  }

  static (PocketErrorDefinition, String)? _openRemoteResolution(
    ConnectionRemoteRuntimeState? remoteRuntime,
  ) {
    if (remoteRuntime == null) {
      return null;
    }

    return switch (remoteRuntime.hostCapability.status) {
      ConnectionRemoteHostCapabilityStatus.probeFailed => (
        PocketErrorCatalog.connectionOpenRemoteHostProbeFailed,
        remoteRuntime.hostCapability.detail ??
            'Pocket Relay could not verify the remote host.',
      ),
      ConnectionRemoteHostCapabilityStatus.unsupported => (
        PocketErrorCatalog.connectionOpenRemoteContinuityUnsupported,
        remoteRuntime.hostCapability.detail ??
            'This remote host does not satisfy Pocket Relay continuity requirements.',
      ),
      _ => switch (remoteRuntime.server.status) {
        ConnectionRemoteServerStatus.notRunning => (
          PocketErrorCatalog.connectionOpenRemoteServerStopped,
          remoteRuntime.server.detail ??
              'The managed remote app-server is still stopped.',
        ),
        ConnectionRemoteServerStatus.unhealthy => (
          PocketErrorCatalog.connectionOpenRemoteServerUnhealthy,
          remoteRuntime.server.detail ??
              'The managed remote app-server is still unhealthy.',
        ),
        ConnectionRemoteServerStatus.running => (
          PocketErrorCatalog.connectionOpenRemoteAttachUnavailable,
          remoteRuntime.server.detail ??
              'The managed remote app-server is running but the lane could not attach.',
        ),
        _ => null,
      },
    };
  }

  static (PocketErrorDefinition, String?)? _remoteServerActionResolution(
    ConnectionSettingsRemoteServerActionId actionId,
    ConnectionRemoteRuntimeState? remoteRuntime,
  ) {
    if (remoteRuntime == null) {
      return null;
    }

    return switch (actionId) {
      ConnectionSettingsRemoteServerActionId.start => _startServerResolution(
        remoteRuntime,
      ),
      ConnectionSettingsRemoteServerActionId.stop => _stopServerResolution(
        remoteRuntime,
      ),
      ConnectionSettingsRemoteServerActionId.restart =>
        _restartServerResolution(remoteRuntime),
    };
  }

  static (PocketErrorDefinition, String?)? _startServerResolution(
    ConnectionRemoteRuntimeState remoteRuntime,
  ) {
    return switch (remoteRuntime.hostCapability.status) {
      ConnectionRemoteHostCapabilityStatus.probeFailed => (
        PocketErrorCatalog.connectionStartServerHostProbeFailed,
        remoteRuntime.hostCapability.detail ??
            'Pocket Relay could not verify the remote host.',
      ),
      ConnectionRemoteHostCapabilityStatus.unsupported => (
        PocketErrorCatalog.connectionStartServerContinuityUnsupported,
        remoteRuntime.hostCapability.detail ??
            'This remote host does not satisfy Pocket Relay continuity requirements.',
      ),
      _ => switch (remoteRuntime.server.status) {
        ConnectionRemoteServerStatus.notRunning => (
          PocketErrorCatalog.connectionStartServerStillStopped,
          remoteRuntime.server.detail ??
              'The managed remote app-server is still stopped.',
        ),
        ConnectionRemoteServerStatus.unhealthy => (
          PocketErrorCatalog.connectionStartServerUnhealthy,
          remoteRuntime.server.detail ??
              'The managed remote app-server is still unhealthy.',
        ),
        _ => null,
      },
    };
  }

  static (PocketErrorDefinition, String?)? _stopServerResolution(
    ConnectionRemoteRuntimeState remoteRuntime,
  ) {
    return switch (remoteRuntime.hostCapability.status) {
      ConnectionRemoteHostCapabilityStatus.probeFailed => (
        PocketErrorCatalog.connectionStopServerHostProbeFailed,
        remoteRuntime.hostCapability.detail ??
            'Pocket Relay could not verify the remote host.',
      ),
      ConnectionRemoteHostCapabilityStatus.unsupported => (
        PocketErrorCatalog.connectionStopServerContinuityUnsupported,
        remoteRuntime.hostCapability.detail ??
            'This remote host does not satisfy Pocket Relay continuity requirements.',
      ),
      _ => switch (remoteRuntime.server.status) {
        ConnectionRemoteServerStatus.running => (
          PocketErrorCatalog.connectionStopServerStillRunning,
          remoteRuntime.server.detail ??
              'The managed remote app-server is still running.',
        ),
        ConnectionRemoteServerStatus.unhealthy => (
          PocketErrorCatalog.connectionStopServerStillUnhealthy,
          remoteRuntime.server.detail ??
              'The managed remote app-server is still unhealthy.',
        ),
        _ => null,
      },
    };
  }

  static (PocketErrorDefinition, String?)? _restartServerResolution(
    ConnectionRemoteRuntimeState remoteRuntime,
  ) {
    return switch (remoteRuntime.hostCapability.status) {
      ConnectionRemoteHostCapabilityStatus.probeFailed => (
        PocketErrorCatalog.connectionRestartServerHostProbeFailed,
        remoteRuntime.hostCapability.detail ??
            'Pocket Relay could not verify the remote host.',
      ),
      ConnectionRemoteHostCapabilityStatus.unsupported => (
        PocketErrorCatalog.connectionRestartServerContinuityUnsupported,
        remoteRuntime.hostCapability.detail ??
            'This remote host does not satisfy Pocket Relay continuity requirements.',
      ),
      _ => switch (remoteRuntime.server.status) {
        ConnectionRemoteServerStatus.notRunning => (
          PocketErrorCatalog.connectionRestartServerStopped,
          remoteRuntime.server.detail ??
              'The managed remote app-server is still stopped.',
        ),
        ConnectionRemoteServerStatus.unhealthy => (
          PocketErrorCatalog.connectionRestartServerUnhealthy,
          remoteRuntime.server.detail ??
              'The managed remote app-server is still unhealthy.',
        ),
        _ => null,
      },
    };
  }

  static PocketErrorDefinition _unexpectedRemoteServerActionDefinition(
    ConnectionSettingsRemoteServerActionId actionId,
  ) {
    return switch (actionId) {
      ConnectionSettingsRemoteServerActionId.start =>
        PocketErrorCatalog.connectionStartServerUnexpectedFailure,
      ConnectionSettingsRemoteServerActionId.stop =>
        PocketErrorCatalog.connectionStopServerUnexpectedFailure,
      ConnectionSettingsRemoteServerActionId.restart =>
        PocketErrorCatalog.connectionRestartServerUnexpectedFailure,
    };
  }

  static String _genericRemoteServerActionFailureMessage(
    ConnectionSettingsRemoteServerActionId actionId,
  ) {
    return switch (actionId) {
      ConnectionSettingsRemoteServerActionId.start =>
        'Pocket Relay could not verify that the managed remote app-server started.',
      ConnectionSettingsRemoteServerActionId.stop =>
        'Pocket Relay could not verify that the managed remote app-server stopped.',
      ConnectionSettingsRemoteServerActionId.restart =>
        'Pocket Relay could not verify that the managed remote app-server restarted.',
    };
  }

  static String _remoteServerActionVerb(
    ConnectionSettingsRemoteServerActionId actionId,
  ) {
    return switch (actionId) {
      ConnectionSettingsRemoteServerActionId.start => 'start server',
      ConnectionSettingsRemoteServerActionId.stop => 'stop server',
      ConnectionSettingsRemoteServerActionId.restart => 'restart server',
    };
  }
}
