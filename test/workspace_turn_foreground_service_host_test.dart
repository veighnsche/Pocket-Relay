import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/device/foreground_service_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_foreground_service_host.dart';

void main() {
  testWidgets(
    'keeps the Android foreground service tied to active live turns',
    (tester) async {
      final clientsById = _buildClientsById(firstConnectionId: 'conn_primary');
      final workspaceController = _buildWorkspaceController(
        clientsById: clientsById,
      );
      final foregroundServiceController = _FakeForegroundServiceController();
      addTearDown(() async {
        workspaceController.dispose();
        await _closeClients(clientsById);
      });

      await workspaceController.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceTurnForegroundServiceHost(
            workspaceController: workspaceController,
            foregroundServiceController: foregroundServiceController,
            supportsForegroundService: true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(foregroundServiceController.enabledStates, isEmpty);

      final laneBinding = workspaceController.selectedLaneBinding!;
      expect(
        await laneBinding.sessionController.sendPrompt(
          'Keep the active turn alive outside the app',
        ),
        isTrue,
      );
      await tester.pumpAndSettle();

      expect(foregroundServiceController.enabledStates, <bool>[true]);

      clientsById['conn_primary']!.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(foregroundServiceController.enabledStates, <bool>[true, false]);
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
    ],
  );
  return ConnectionWorkspaceController(
    connectionRepository: repository,
    laneBindingFactory: ({required connectionId, required connection}) {
      final appServerClient = clientsById[connectionId]!;
      return ConnectionLaneBinding(
        connectionId: connectionId,
        profileStore: ConnectionScopedProfileStore(
          connectionId: connectionId,
          connectionRepository: repository,
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: connection.profile,
          secrets: connection.secrets,
        ),
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
    workspaceDir: '/workspace',
  );
}

Map<String, FakeCodexAppServerClient> _buildClientsById({
  required String firstConnectionId,
}) {
  return <String, FakeCodexAppServerClient>{
    firstConnectionId: FakeCodexAppServerClient(),
  };
}

Future<void> _closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}

class _FakeForegroundServiceController implements ForegroundServiceController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }
}
