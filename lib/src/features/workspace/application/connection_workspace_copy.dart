import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

abstract final class ConnectionWorkspaceCopy {
  static const String workspaceTitle = 'Workspaces';
  static const String connectionInventorySectionTitle = workspaceTitle;
  static const String savedConnectionsTitle = 'Saved workspaces';
  static const String savedConnectionsMenuLabel = savedConnectionsTitle;
  static const String manageConnectionsAction = 'Manage workspaces';
  static const String allConnectionsAction = manageConnectionsAction;
  static const String conversationHistoryMenuLabel = 'Conversation history';
  static const String currentLaneSectionTitle = 'Current lane';
  static const String openLanesSectionTitle = 'Open lanes';
  static const String needsAttentionSectionTitle = 'Needs attention';
  static const String mobileSavedConnectionsDescription =
      'Jump back to an open lane or open another saved workspace. System and lane controls stay inside each lane.';
  static const String desktopSidebarDescription =
      'Keep multiple lanes open while every saved workspace stays visible in one list.';
  static const String desktopSavedConnectionsDescription =
      'Open another saved workspace or jump back to a lane that is already open. System and lane controls stay inside each lane.';
  static const String addConnectionAction = 'Add workspace';
  static const String addConnectionProgress = 'Adding…';
  static const String openLaneAction = 'Open lane';
  static const String goToLaneAction = 'Go to lane';
  static const String openingLaneAction = 'Opening…';
  static const String editAction = 'Edit';
  static const String saveProgress = 'Saving…';
  static const String deleteAction = 'Delete';
  static const String deleteProgress = 'Deleting…';
  static const String startServerAction = 'Start server';
  static const String startServerProgress = 'Starting…';
  static const String stopServerAction = 'Stop server';
  static const String stopServerProgress = 'Stopping…';
  static const String restartServerAction = 'Restart server';
  static const String restartServerProgress = 'Restarting…';
  static const String closeLaneAction = 'Close lane';
  static const String openConnectionBadge = 'Open';
  static const String currentConnectionBadge = 'Current';
  static const String savedSettingsReconnectBadge = 'Changes pending';
  static const String savedSettingsReconnectAction = 'Apply changes';
  static const String savedSettingsReconnectProgress = 'Applying changes…';
  static const String savedSettingsReconnectMenuAction = 'Apply saved settings';
  static const String savedSettingsReconnectMenuProgress =
      'Applying saved settings…';
  static const String transportReconnectBadge = 'Reconnect needed';
  static const String transportReconnectAction = 'Reconnect';
  static const String transportReconnectProgress = 'Reconnecting…';
  static const String transportReconnectMenuAction = 'Reconnect lane';
  static const String transportReconnectMenuProgress = 'Reconnecting lane…';
  static const String reconnectingNoticeTitle =
      'Reconnecting to remote session';
  static const String reconnectingNoticeMessage =
      'Pocket Relay is reconnecting this lane to Codex before it can continue. Your draft is preserved below.';
  static const String restoringConversationNoticeTitle =
      'Restoring conversation';
  static const String restoringConversationNoticeMessage =
      'Pocket Relay is restoring this transcript from Codex after live reattach could not continue directly. Your draft is preserved below.';
  static const String remoteServerRunningSummary = 'Server running';
  static const String remoteServerStoppedSummary = 'Server stopped';
  static const String remoteServerUnhealthySummary = 'Server unhealthy';
  static const String remoteHostUnsupportedSummary = 'System unsupported';
  static const String remoteHostProbeFailedSummary = 'System check failed';
  static const String remoteHostCheckingSummary = 'Checking system';
  static const String remoteServerCheckingSummary = 'Checking server';
  static const String laneConnectedStatus = 'Connected';
  static const String laneDisconnectedStatus = 'Disconnected';
  static const String laneConnectingStatus = 'Connecting';
  static const String laneConfigurationIncompleteStatus =
      'Workspace not configured';
  static const String laneLocalReadyStatus = 'Local workspace ready';
  static const String laneServerRunningStatus = 'Server running';
  static const String laneServerStoppedStatus = 'Server stopped';
  static const String laneServerUnhealthyStatus = 'Server unhealthy';
  static const String laneHostUnknownStatus = 'System status unknown';
  static const String laneHostCheckingStatus = 'Checking system';
  static const String laneServerCheckingStatus = 'Checking server';
  static const String laneHostCheckFailedStatus = 'System check failed';
  static const String laneContinuityUnavailableStatus =
      'Remote continuity unavailable';
  static const String laneReconnectNeededStatus = 'Reconnect needed';
  static const String laneChangesPendingStatus = 'Changes pending';
  static const String laneReconnectingStatus = 'Reconnecting';
  static const String laneBootstrapDetail =
      'Open lane does not connect automatically. Check this system to continue from here.';
  static const String laneConfigurationIncompleteDetail =
      'Finish the workspace setup before this lane can continue.';
  static const String laneHostCheckingDetail =
      'Pocket Relay is checking whether this system can support continuity for this lane.';
  static const String laneServerCheckingDetail =
      'Pocket Relay is checking the managed remote session for this lane.';
  static const String laneDisconnectedDetail =
      'Connect this lane to Codex to continue.';
  static const String connectAction = 'Connect';
  static const String connectProgress = 'Connecting…';
  static const String disconnectAction = 'Disconnect';
  static const String disconnectProgress = 'Disconnecting…';
  static const String checkHostAction = 'Check system';
  static const String checkHostProgress = 'Checking…';
  static const String collapseSidebarAction = 'Collapse sidebar';
  static const String expandSidebarAction = 'Expand sidebar';
  static const String workspaceNotSet = 'Workspace not set';
  static const String hostNotSet = 'System not set';
  static const String remoteConnectionNotConfigured =
      'Remote system not configured';
  static const String emptyWorkspaceTitle = 'No saved workspaces yet.';
  static const String emptyWorkspaceMessage =
      'Add your first workspace to open a new lane.';
  static const String laneFactLabel = 'Lane';
  static const String laneCurrentFact = 'Current';
  static const String laneOpenFact = 'Open';
  static const String laneClosedFact = 'Closed';
  static const String transportFactLabel = 'Transport';
  static const String transportConnectedFact = 'Connected';
  static const String transportDisconnectedFact = 'Disconnected';
  static const String transportReconnectingFact = 'Reconnecting';
  static const String hostFactLabel = 'System';
  static const String hostSupportedFact = 'Supported';
  static const String hostUnsupportedFact = 'Unsupported';
  static const String hostCheckFailedFact = 'Check failed';
  static const String serverFactLabel = 'Server';
  static const String settingsFactLabel = 'Settings';
  static const String settingsChangesPendingFact = 'Changes pending';

  static String connectionSubtitle(ConnectionProfile profile) {
    final host = profile.host.trim();
    final workspaceDir = profile.workspaceDir.trim();

    return switch (profile.connectionMode) {
      ConnectionMode.remote when host.isNotEmpty && workspaceDir.isNotEmpty =>
        '$host · $workspaceDir',
      ConnectionMode.remote when host.isNotEmpty => '$host · $workspaceNotSet',
      ConnectionMode.remote when workspaceDir.isNotEmpty =>
        '$hostNotSet · $workspaceDir',
      ConnectionMode.remote => remoteConnectionNotConfigured,
      ConnectionMode.local when workspaceDir.isNotEmpty =>
        'Local workspace · $workspaceDir',
      ConnectionMode.local => 'Local workspace · $workspaceNotSet',
    };
  }

  static String reconnectBadgeFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings =>
        savedSettingsReconnectBadge,
      ConnectionWorkspaceReconnectRequirement.transport ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        transportReconnectBadge,
    };
  }

  static String reconnectActionFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings =>
        savedSettingsReconnectAction,
      ConnectionWorkspaceReconnectRequirement.transport ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        transportReconnectAction,
    };
  }

  static String reconnectProgressFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings =>
        savedSettingsReconnectProgress,
      ConnectionWorkspaceReconnectRequirement.transport ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        transportReconnectProgress,
    };
  }

  static String reconnectMenuActionFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings =>
        savedSettingsReconnectMenuAction,
      ConnectionWorkspaceReconnectRequirement.transport ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        transportReconnectMenuAction,
    };
  }

  static String reconnectMenuProgressFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings =>
        savedSettingsReconnectMenuProgress,
      ConnectionWorkspaceReconnectRequirement.transport ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        transportReconnectMenuProgress,
    };
  }

  static String laneFactFor({required bool isLive, required bool isCurrent}) {
    final value = switch ((isLive, isCurrent)) {
      (true, true) => laneCurrentFact,
      (true, false) => laneOpenFact,
      (false, _) => laneClosedFact,
    };
    return '$laneFactLabel: $value';
  }

  static String transportFactFor({
    required bool isConnected,
    required ConnectionWorkspaceTransportRecoveryPhase? transportRecoveryPhase,
    required ConnectionWorkspaceLiveReattachPhase? liveReattachPhase,
  }) {
    final value =
        liveReattachPhase ==
                ConnectionWorkspaceLiveReattachPhase.reconnecting ||
            transportRecoveryPhase ==
                ConnectionWorkspaceTransportRecoveryPhase.reconnecting
        ? transportReconnectingFact
        : isConnected
        ? transportConnectedFact
        : transportDisconnectedFact;
    return '$transportFactLabel: $value';
  }

  static String hostFactFor(ConnectionRemoteHostCapabilityStatus hostStatus) {
    final value = switch (hostStatus) {
      ConnectionRemoteHostCapabilityStatus.checking => laneHostCheckingStatus,
      ConnectionRemoteHostCapabilityStatus.probeFailed => hostCheckFailedFact,
      ConnectionRemoteHostCapabilityStatus.unsupported => hostUnsupportedFact,
      ConnectionRemoteHostCapabilityStatus.supported => hostSupportedFact,
      ConnectionRemoteHostCapabilityStatus.unknown => laneHostUnknownStatus,
    };
    return '$hostFactLabel: $value';
  }

  static String serverFactFor(ConnectionRemoteServerStatus serverStatus) {
    final value = switch (serverStatus) {
      ConnectionRemoteServerStatus.checking => laneServerCheckingStatus,
      ConnectionRemoteServerStatus.notRunning => laneServerStoppedStatus,
      ConnectionRemoteServerStatus.unhealthy => laneServerUnhealthyStatus,
      ConnectionRemoteServerStatus.running => laneServerRunningStatus,
      ConnectionRemoteServerStatus.unknown => laneHostUnknownStatus,
    };
    return '$serverFactLabel: $value';
  }

  static String settingsFactFor(
    ConnectionWorkspaceReconnectRequirement requirement,
  ) {
    return switch (requirement) {
      ConnectionWorkspaceReconnectRequirement.savedSettings ||
      ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings =>
        '$settingsFactLabel: $settingsChangesPendingFact',
      ConnectionWorkspaceReconnectRequirement.transport => throw UnsupportedError(
        'Transport-only reconnect requirements do not produce a settings fact.',
      ),
    };
  }

  static String? savedConnectionRemoteStatusSummary(
    ConnectionProfile profile,
    ConnectionRemoteRuntimeState? remoteRuntime,
  ) {
    if (profile.connectionMode == ConnectionMode.local ||
        remoteRuntime == null) {
      return null;
    }

    return switch (remoteRuntime.hostCapability.status) {
      ConnectionRemoteHostCapabilityStatus.checking =>
        remoteHostCheckingSummary,
      ConnectionRemoteHostCapabilityStatus.probeFailed =>
        remoteHostProbeFailedSummary,
      ConnectionRemoteHostCapabilityStatus.unsupported =>
        remoteHostUnsupportedSummary,
      ConnectionRemoteHostCapabilityStatus.unknown => null,
      ConnectionRemoteHostCapabilityStatus.supported => switch (remoteRuntime
          .server
          .status) {
        ConnectionRemoteServerStatus.checking => remoteServerCheckingSummary,
        ConnectionRemoteServerStatus.notRunning => remoteServerStoppedSummary,
        ConnectionRemoteServerStatus.unhealthy => remoteServerUnhealthySummary,
        ConnectionRemoteServerStatus.running => remoteServerRunningSummary,
        ConnectionRemoteServerStatus.unknown => null,
      },
    };
  }

  static String remoteServerActionLabel(
    ConnectionSettingsRemoteServerActionId actionId,
  ) {
    return switch (actionId) {
      ConnectionSettingsRemoteServerActionId.start => startServerAction,
      ConnectionSettingsRemoteServerActionId.stop => stopServerAction,
      ConnectionSettingsRemoteServerActionId.restart => restartServerAction,
    };
  }

  static String remoteServerActionProgressLabel(
    ConnectionSettingsRemoteServerActionId actionId,
  ) {
    return switch (actionId) {
      ConnectionSettingsRemoteServerActionId.start => startServerProgress,
      ConnectionSettingsRemoteServerActionId.stop => stopServerProgress,
      ConnectionSettingsRemoteServerActionId.restart => restartServerProgress,
    };
  }
}
