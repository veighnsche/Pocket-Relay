import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_wake_lock_host.dart';

import 'support/fake_codex_app_server_client.dart';

void main() {
  testWidgets('blocked turns release the workspace wake lock', (tester) async {
    final clientsById = _buildClientsById(
      firstConnectionId: 'conn_primary',
    );
    final controller = _buildWorkspaceController(clientsById: clientsById);
    final wakeLockController = _FakeDisplayWakeLockController();
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceTurnWakeLockHost(
          workspaceController: controller,
          displayWakeLockController: wakeLockController,
          supportsWakeLock: true,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(wakeLockController.enabledStates, isEmpty);

    final laneBinding = controller.selectedLaneBinding!;
    expect(
      await laneBinding.sessionController.sendPrompt(
        'Keep the screen awake while the turn is running',
      ),
      isTrue,
    );
    await tester.pumpAndSettle();

    expect(wakeLockController.enabledStates, <bool>[true]);

    clientsById['conn_primary']!.emit(
      const CodexAppServerRequestEvent(
        requestId: 'approval_1',
        method: 'item/fileChange/requestApproval',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'item_1',
          'reason': 'Write files',
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(wakeLockController.enabledStates, <bool>[true, false]);
  });

  testWidgets(
    'a non-selected live lane with a ticking turn still keeps the display awake',
    (tester) async {
      final clientsById = _buildClientsById(
        firstConnectionId: 'conn_primary',
        secondConnectionId: 'conn_secondary',
      );
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final wakeLockController = _FakeDisplayWakeLockController();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await controller.instantiateConnection('conn_secondary');
      controller.selectConnection('conn_primary');

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceTurnWakeLockHost(
            workspaceController: controller,
            displayWakeLockController: wakeLockController,
            supportsWakeLock: true,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(wakeLockController.enabledStates, isEmpty);

      final backgroundLane =
          controller.bindingForConnectionId('conn_secondary')!;
      expect(
        await backgroundLane.sessionController.sendPrompt(
          'Run in the background lane',
        ),
        isTrue,
      );
      await tester.pumpAndSettle();

      expect(wakeLockController.enabledStates, <bool>[true]);

      clientsById['conn_secondary']!.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(wakeLockController.enabledStates, <bool>[true, false]);
    },
  );
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  MemoryCodexConnectionRepository? repository,
  MemoryCodexConnectionConversationStateStore? conversationStateStore,
}) {
  final resolvedRepository =
      repository ??
      MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          if (clientsById.containsKey('conn_secondary'))
            SavedConnection(
              id: 'conn_secondary',
              profile: _profile('Secondary Box', 'secondary.local'),
              secrets: const ConnectionSecrets(password: 'secret-2'),
            ),
        ],
      );
  final resolvedConversationStateStore =
      conversationStateStore ?? MemoryCodexConnectionConversationStateStore();

  return ConnectionWorkspaceController(
    connectionRepository: resolvedRepository,
    connectionConversationStateStore: resolvedConversationStateStore,
    laneBindingFactory:
        ({
          required connectionId,
          required connection,
        }) {
          final appServerClient = clientsById[connectionId]!;
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: resolvedRepository,
            ),
            conversationStateStore: ConnectionScopedConversationStateStore(
              connectionId: connectionId,
              conversationStateStore: resolvedConversationStateStore,
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
  String? secondConnectionId,
}) {
  final secondaryClients = secondConnectionId == null
      ? null
      : <String, FakeCodexAppServerClient>{
          secondConnectionId: FakeCodexAppServerClient(),
        };
  return <String, FakeCodexAppServerClient>{
    firstConnectionId: FakeCodexAppServerClient(),
    ...?secondaryClients,
  };
}

Future<void> _closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}

class _FakeDisplayWakeLockController implements DisplayWakeLockController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }
}
