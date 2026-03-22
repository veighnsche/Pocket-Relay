import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/app/pocket_relay_app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_app_lifecycle_host.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/workspace_turn_wake_lock_host.dart';

void main() {
  testWidgets(
    'workspace app lifecycle host snapshots the selected lane state on pause',
    (tester) async {
      final clientsById = _buildClientsById(firstConnectionId: 'conn_primary');
      final snapshotTime = DateTime(2026, 3, 22, 14, 10);
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          _savedConversationThread(threadId: 'thread_saved');
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        now: () => snapshotTime,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await controller.resumeConversation(
        connectionId: 'conn_primary',
        threadId: 'thread_saved',
      );
      controller.selectedLaneBinding!.restoreComposerDraft(
        'Recover this draft',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceAppLifecycleHost(
            workspaceController: controller,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      final recoveryState = await recoveryStore.load();
      expect(recoveryState, isNotNull);
      expect(recoveryState!.connectionId, 'conn_primary');
      expect(recoveryState.selectedThreadId, 'thread_saved');
      expect(recoveryState.draftText, 'Recover this draft');
      expect(recoveryState.backgroundedAt, snapshotTime);
    },
  );

  testWidgets(
    'workspace app lifecycle host preserves the selected lane on resume without forcing reconnect',
    (tester) async {
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
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
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryStore: MemoryConnectionWorkspaceRecoveryStore(),
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient();
          clientsByConnectionId[connectionId]!.add(appServerClient);
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
      addTearDown(() async {
        controller.dispose();
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      await controller.instantiateConnection('conn_secondary');
      controller.selectConnection('conn_primary');
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Persist across resume');

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceAppLifecycleHost(
            workspaceController: controller,
            child: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, same(firstBinding));
      expect(
        nextBinding!.composerDraftHost.draft.text,
        'Persist across resume',
      );
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(controller.state.requiresReconnect('conn_secondary'), isFalse);
      expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 0);
    },
  );

  testWidgets(
    'PocketRelayApp keeps the lifecycle host above the wake-lock host',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        PocketRelayApp(
          connectionRepository: MemoryCodexConnectionRepository.single(
            savedProfile: SavedProfile(
              profile: _profile('Primary Box', 'primary.local'),
              secrets: const ConnectionSecrets(password: 'secret-1'),
            ),
            connectionId: 'conn_primary',
          ),
          modelCatalogStore: MemoryConnectionModelCatalogStore(),
          recoveryStore: MemoryConnectionWorkspaceRecoveryStore(),
          appServerClient: appServerClient,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WorkspaceAppLifecycleHost), findsOneWidget);
      expect(find.byType(WorkspaceTurnWakeLockHost), findsOneWidget);
    },
  );
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  required ConnectionWorkspaceRecoveryStore recoveryStore,
  WorkspaceNow? now,
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
    recoveryStore: recoveryStore,
    now: now,
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

Future<void> _closeClientLists(
  Map<String, List<FakeCodexAppServerClient>> clientsByConnectionId,
) async {
  for (final clients in clientsByConnectionId.values) {
    for (final client in clients) {
      await client.close();
    }
  }
}

CodexAppServerThreadHistory _savedConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_saved',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_saved',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}
