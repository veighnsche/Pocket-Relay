import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/codex_conversation_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/workspace/models/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';

import 'support/fake_codex_app_server_client.dart';

void main() {
  test('initializes one live lane and keeps the rest dormant', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.liveConnectionIds, <String>['conn_primary']);
    expect(controller.state.dormantConnectionIds, <String>['conn_secondary']);
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
    expect(controller.selectedLaneBinding?.connectionId, 'conn_primary');
    expect(controller.bindingForConnectionId('conn_secondary'), isNull);
  });

  test(
    'instantiating a dormant connection selects it without affecting existing live lanes',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      await controller.instantiateConnection('conn_secondary');

      expect(controller.state.liveConnectionIds, <String>[
        'conn_primary',
        'conn_secondary',
      ]);
      expect(controller.state.dormantConnectionIds, isEmpty);
      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(
        controller.bindingForConnectionId('conn_primary'),
        same(firstBinding),
      );
      expect(controller.bindingForConnectionId('conn_secondary'), isNotNull);
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );

  test('terminating one live lane leaves the others intact', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await controller.instantiateConnection('conn_secondary');

    controller.terminateConnection('conn_secondary');

    expect(controller.state.liveConnectionIds, <String>['conn_primary']);
    expect(controller.state.dormantConnectionIds, <String>['conn_secondary']);
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
    expect(controller.bindingForConnectionId('conn_secondary'), isNull);
    expect(clientsById['conn_secondary']?.disconnectCalls, 1);
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  test('showDormantRoster preserves the selected live lane', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();

    controller.showDormantRoster();

    expect(
      controller.state.viewport,
      ConnectionWorkspaceViewport.dormantRoster,
    );
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(controller.selectedLaneBinding?.connectionId, 'conn_primary');
  });

  test(
    'instantiating from the dormant roster returns the workspace to a live lane',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      controller.showDormantRoster();

      await controller.instantiateConnection('conn_secondary');

      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(controller.state.selectedConnectionId, 'conn_secondary');
    },
  );

  test(
    'selecting the current live connection exits dormant-roster mode',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      controller.showDormantRoster();

      controller.selectConnection('conn_primary');

      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(controller.state.selectedConnectionId, 'conn_primary');
    },
  );
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
}) {
  final repository = MemoryCodexConnectionRepository(
    initialConnections: <SavedConnection>[
      SavedConnection(
        id: 'conn_primary',
        profile: _profile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      ),
      SavedConnection(
        id: 'conn_secondary',
        profile: _profile('Secondary Box', 'secondary.local'),
        secrets: const ConnectionSecrets(password: 'secret-2'),
      ),
    ],
  );
  final handoffStore = MemoryCodexConnectionHandoffStore(
    initialValues: <String, SavedConversationHandoff>{
      'conn_secondary': const SavedConversationHandoff(
        resumeThreadId: 'thread_saved',
      ),
    },
  );

  return ConnectionWorkspaceController(
    connectionRepository: repository,
    connectionHandoffStore: handoffStore,
    laneBindingFactory:
        ({required connectionId, required connection, required handoff}) {
          final appServerClient = clientsById[connectionId]!;
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            conversationHandoffStore: ConnectionScopedConversationHandoffStore(
              connectionId: connectionId,
              handoffStore: handoffStore,
            ),
            appServerClient: appServerClient,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            initialSavedConversationHandoff: handoff,
            ownsAppServerClient: false,
          );
        },
  );
}

ConnectionProfile _profile(String label, String host) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
  );
}

Map<String, FakeCodexAppServerClient> _buildClientsById(
  String firstConnectionId,
  String secondConnectionId,
) {
  return <String, FakeCodexAppServerClient>{
    firstConnectionId: FakeCodexAppServerClient(),
    secondConnectionId: FakeCodexAppServerClient(),
  };
}

Future<void> _closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}
