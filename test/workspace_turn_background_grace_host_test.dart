import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_background_grace_host.dart';

void main() {
  testWidgets(
    'requests background grace only while a live turn is ticking in the background',
    (tester) async {
      final clientsById = _buildClientsById(firstConnectionId: 'conn_primary');
      final workspaceController = _buildWorkspaceController(
        clientsById: clientsById,
      );
      final backgroundGraceController = _FakeBackgroundGraceController();
      addTearDown(() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        workspaceController.dispose();
        await _closeClients(clientsById);
      });

      await workspaceController.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceTurnBackgroundGraceHost(
            workspaceController: workspaceController,
            backgroundGraceController: backgroundGraceController,
            supportsBackgroundGrace: true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(backgroundGraceController.enabledStates, isEmpty);

      final laneBinding = workspaceController.selectedLaneBinding!;
      expect(
        await laneBinding.sessionController.sendPrompt(
          'Keep the turn alive while the app is backgrounded',
        ),
        isTrue,
      );
      await tester.pumpAndSettle();

      expect(backgroundGraceController.enabledStates, isEmpty);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      expect(backgroundGraceController.enabledStates, <bool>[true]);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(backgroundGraceController.enabledStates, <bool>[true, false]);
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

class _FakeBackgroundGraceController implements BackgroundGraceController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }
}
