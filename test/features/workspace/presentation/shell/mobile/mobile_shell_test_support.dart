import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_mobile_shell.dart';
import '../../../../../support/fakes/connection_settings_overlay_delegate.dart';

export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/errors/pocket_error.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
export 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
export 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
export 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
export 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
export 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';
export 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
export '../../../../../support/fakes/connection_settings_overlay_delegate.dart';

Widget buildShell(
  ConnectionWorkspaceController controller, {
  ConnectionSettingsOverlayDelegate? settingsOverlayDelegate,
  CodexWorkspaceConversationHistoryRepository? conversationHistoryRepository,
  TargetPlatform platform = TargetPlatform.android,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: ConnectionWorkspaceMobileShell(
      workspaceController: controller,
      platformPolicy: PocketPlatformPolicy.resolve(platform: platform),
      conversationHistoryRepository: conversationHistoryRepository,
      settingsOverlayDelegate:
          settingsOverlayDelegate ?? FakeConnectionSettingsOverlayDelegate(),
    ),
  );
}

Future<void> openLaneConversationHistory(WidgetTester tester) async {
  await tester.tap(find.byTooltip('More actions'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Conversation history'));
  await tester.pumpAndSettle();
}

ConnectionWorkspaceController buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  MemoryCodexConnectionRepository? repository,
}) {
  final resolvedRepository =
      repository ??
      MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
  return ConnectionWorkspaceController(
    connectionRepository: resolvedRepository,
    remoteAppServerHostProbe: const FakeRemoteHostProbe(
      CodexRemoteAppServerHostCapabilities(),
    ),
    remoteAppServerOwnerInspector: const StaticRemoteOwnerInspector(
      CodexRemoteAppServerOwnerSnapshot(
        ownerId: 'conn_primary',
        workspaceDir: '/workspace',
        status: CodexRemoteAppServerOwnerStatus.stopped,
        sessionName: 'pocket-relay-conn_primary',
      ),
    ),
    remoteAppServerOwnerControl: const StaticRemoteOwnerControl(
      CodexRemoteAppServerOwnerSnapshot(
        ownerId: 'conn_primary',
        workspaceDir: '/workspace',
        status: CodexRemoteAppServerOwnerStatus.stopped,
        sessionName: 'pocket-relay-conn_primary',
      ),
    ),
    laneBindingFactory: ({required connectionId, required connection}) {
      final appServerClient = clientsById[connectionId]!;
      return ConnectionLaneBinding(
        connectionId: connectionId,
        profileStore: ConnectionScopedProfileStore(
          connectionId: connectionId,
          connectionRepository: resolvedRepository,
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

final class FakeRemoteHostProbe implements CodexRemoteAppServerHostProbe {
  const FakeRemoteHostProbe(this.capabilities);

  final CodexRemoteAppServerHostCapabilities capabilities;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return capabilities;
  }
}

final class StaticRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const StaticRemoteOwnerInspector(this.snapshot);

  final CodexRemoteAppServerOwnerSnapshot snapshot;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}

final class StaticRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  const StaticRemoteOwnerControl(this.snapshot);

  final CodexRemoteAppServerOwnerSnapshot snapshot;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }
}

ConnectionProfile workspaceProfile(String label, String host) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

Map<String, FakeCodexAppServerClient> buildClientsById(
  String firstConnectionId,
  String secondConnectionId,
) {
  return <String, FakeCodexAppServerClient>{
    firstConnectionId: FakeCodexAppServerClient(),
    secondConnectionId: FakeCodexAppServerClient(),
  };
}

Future<void> closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}

CodexAppServerThreadHistory savedConversationThread({
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

class FakeCodexWorkspaceConversationHistoryRepository
    implements CodexWorkspaceConversationHistoryRepository {
  FakeCodexWorkspaceConversationHistoryRepository({
    this.conversations = const <CodexWorkspaceConversationSummary>[],
    this.error,
  });

  final List<CodexWorkspaceConversationSummary> conversations;
  final Object? error;
  final List<String?> loadOwnerIds = <String?>[];

  @override
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  }) async {
    loadOwnerIds.add(ownerId);
    if (error != null) {
      throw error!;
    }
    return conversations;
  }
}
