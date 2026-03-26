import 'package:flutter/foundation.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

enum ConnectionWorkspaceInventoryBadgeTone { accent, warning }

@immutable
class ConnectionWorkspaceInventoryBadge {
  const ConnectionWorkspaceInventoryBadge({
    required this.label,
    required this.tone,
  });

  final String label;
  final ConnectionWorkspaceInventoryBadgeTone tone;
}

@immutable
class ConnectionWorkspaceInventoryEntry {
  const ConnectionWorkspaceInventoryEntry({
    required this.connection,
    required this.isLive,
    required this.isCurrent,
    required this.reconnectRequirement,
    required this.remoteRuntime,
    required this.badges,
    required this.remoteStatusSummary,
  });

  final SavedConnectionSummary connection;
  final bool isLive;
  final bool isCurrent;
  final ConnectionWorkspaceReconnectRequirement? reconnectRequirement;
  final ConnectionRemoteRuntimeState? remoteRuntime;
  final List<ConnectionWorkspaceInventoryBadge> badges;
  final String? remoteStatusSummary;
}

List<ConnectionWorkspaceInventoryEntry> connectionWorkspaceInventoryEntriesFromState(
  ConnectionWorkspaceState state,
) {
  return <ConnectionWorkspaceInventoryEntry>[
    for (final connectionId in state.catalog.orderedConnectionIds)
      if (state.catalog.connectionForId(connectionId) case final connection?)
        _buildConnectionWorkspaceInventoryEntry(state, connection),
  ];
}

ConnectionWorkspaceInventoryEntry _buildConnectionWorkspaceInventoryEntry(
  ConnectionWorkspaceState state,
  SavedConnectionSummary connection,
) {
  final connectionId = connection.id;
  final isLive = state.isConnectionLive(connectionId);
  final isCurrent =
      isLive &&
      state.isShowingLiveLane &&
      state.selectedConnectionId == connectionId;
  final reconnectRequirement = state.reconnectRequirementFor(connectionId);
  final remoteRuntime = state.remoteRuntimeFor(connectionId);

  return ConnectionWorkspaceInventoryEntry(
    connection: connection,
    isLive: isLive,
    isCurrent: isCurrent,
    reconnectRequirement: reconnectRequirement,
    remoteRuntime: remoteRuntime,
    badges: <ConnectionWorkspaceInventoryBadge>[
      if (isLive)
        const ConnectionWorkspaceInventoryBadge(
          label: ConnectionWorkspaceCopy.openConnectionBadge,
          tone: ConnectionWorkspaceInventoryBadgeTone.accent,
        ),
      if (isCurrent)
        const ConnectionWorkspaceInventoryBadge(
          label: ConnectionWorkspaceCopy.currentConnectionBadge,
          tone: ConnectionWorkspaceInventoryBadgeTone.accent,
        ),
      if (reconnectRequirement case final requirement?)
        ConnectionWorkspaceInventoryBadge(
          label: ConnectionWorkspaceCopy.reconnectBadgeFor(requirement),
          tone: ConnectionWorkspaceInventoryBadgeTone.warning,
        ),
    ],
    remoteStatusSummary: ConnectionWorkspaceCopy.savedConnectionRemoteStatusSummary(
      connection.profile,
      remoteRuntime,
    ),
  );
}
