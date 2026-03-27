import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_lifecycle_presentation.dart';

void main() {
  test(
    'successful live reattach stays in open lanes instead of needs attention',
    () {
      const connectionId = 'conn_primary';
      final profile = ConnectionProfile.defaults().copyWith(
        label: 'Primary Box',
        host: 'primary.local',
        username: 'vince',
        workspaceDir: '/workspace',
        codexPath: 'codex',
      );
      const remoteRuntime = ConnectionRemoteRuntimeState(
        hostCapability: ConnectionRemoteHostCapabilityState.supported(),
        server: ConnectionRemoteServerState.running(port: 7331),
      );
      final state = ConnectionWorkspaceState(
        isLoading: false,
        catalog: ConnectionCatalogState(
          orderedConnectionIds: const <String>[connectionId],
          connectionsById: <String, SavedConnectionSummary>{
            connectionId: SavedConnectionSummary(
              id: connectionId,
              profile: profile,
            ),
          },
        ),
        liveConnectionIds: const <String>[connectionId],
        selectedConnectionId: null,
        viewport: ConnectionWorkspaceViewport.savedConnections,
        savedSettingsReconnectRequiredConnectionIds: const <String>{},
        transportReconnectRequiredConnectionIds: const <String>{},
        transportRecoveryPhasesByConnectionId:
            const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
        liveReattachPhasesByConnectionId:
            const <String, ConnectionWorkspaceLiveReattachPhase>{
              connectionId: ConnectionWorkspaceLiveReattachPhase.liveReattached,
            },
        recoveryDiagnosticsByConnectionId:
            const <String, ConnectionWorkspaceRecoveryDiagnostics>{},
        remoteRuntimeByConnectionId:
            const <String, ConnectionRemoteRuntimeState>{
              connectionId: remoteRuntime,
            },
      );

      final sections = connectionLifecycleSectionsFromState(
        state,
        isTransportConnected: (_) => true,
      );

      expect(
        sections.any(
          (section) =>
              section.id == ConnectionLifecycleSectionId.needsAttention,
        ),
        isFalse,
      );
      expect(sections.single.id, ConnectionLifecycleSectionId.openLanes);
      expect(sections.single.rows.single.connection.id, connectionId);
    },
  );
}
