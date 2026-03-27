import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

abstract final class ConnectionWorkspaceCopy {
  static const String workspaceTitle = 'Connections';
  static const String savedConnectionsTitle = 'Saved connections';
  static const String savedConnectionsMenuLabel = savedConnectionsTitle;
  static const String allConnectionsAction = 'All connections';
  static const String conversationHistoryMenuLabel = 'Conversation history';
  static const String currentLaneSectionTitle = 'Current lane';
  static const String openLanesSectionTitle = 'Open lanes';
  static const String needsAttentionSectionTitle = 'Needs attention';
  static const String mobileSavedConnectionsDescription =
      'Jump between open lanes, reconnect stalled ones, or open another saved connection.';
  static const String desktopSavedConnectionsDescription =
      'Use the full connections view to jump between lanes, edit saved settings, reconnect remote lanes, and manage host checks.';
  static const String addConnectionAction = 'Add connection';
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
  static const String savedSettingsReconnectAction = 'Apply changes';
  static const String savedSettingsReconnectProgress = 'Applying changes…';
  static const String savedSettingsReconnectMenuAction = 'Apply saved settings';
  static const String savedSettingsReconnectMenuProgress =
      'Applying saved settings…';
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
  static const String laneConfigurationIncompleteStatus =
      'Connection not configured';
  static const String laneServerRunningStatus = 'Server running';
  static const String laneServerStoppedStatus = 'Server stopped';
  static const String laneServerUnhealthyStatus = 'Server unhealthy';
  static const String laneHostUnknownStatus = 'Host status unknown';
  static const String laneHostCheckingStatus = 'Checking host';
  static const String laneServerCheckingStatus = 'Checking server';
  static const String laneHostCheckFailedStatus = 'Host check failed';
  static const String connectAction = 'Connect';
  static const String connectProgress = 'Connecting…';
  static const String disconnectAction = 'Disconnect';
  static const String disconnectProgress = 'Disconnecting…';
  static const String checkHostAction = 'Check host';
  static const String checkHostProgress = 'Checking…';
  static const String collapseSidebarAction = 'Collapse sidebar';
  static const String expandSidebarAction = 'Expand sidebar';
  static const String workspaceNotSet = 'Workspace not set';
  static const String hostNotSet = 'Host not set';
  static const String remoteConnectionNotConfigured =
      'Remote connection not configured';
  static const String emptyWorkspaceTitle = 'No saved connections yet.';
  static const String emptyWorkspaceMessage =
      'Add your first connection to open a new lane.';
  static const String laneFactLabel = 'Lane';
  static const String laneCurrentFact = 'Current';
  static const String laneOpenFact = 'Open';
  static const String laneClosedFact = 'Closed';
  static const String transportFactLabel = 'Transport';
  static const String transportConnectedFact = 'Connected';
  static const String transportDisconnectedFact = 'Disconnected';
  static const String transportReconnectingFact = 'Reconnecting';
  static const String hostFactLabel = 'Host';
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
        'Local Codex · $workspaceDir',
      ConnectionMode.local => 'Local Codex · $workspaceNotSet',
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
