import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

export 'dart:async';
export 'package:flutter_secure_storage/flutter_secure_storage.dart';
export 'package:flutter/widgets.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
export 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
export 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
export 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
export 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
export 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
export 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
export 'package:shared_preferences/shared_preferences.dart';
export 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
export 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

ConnectionWorkspaceController buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  MemoryCodexConnectionRepository? repository,
  ConnectionModelCatalogStore? modelCatalogStore,
  ConnectionWorkspaceRecoveryStore? recoveryStore,
  CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
      const FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
  CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
      const ThrowingRemoteOwnerInspector(),
  CodexRemoteAppServerOwnerControl remoteAppServerOwnerControl =
      const ThrowingRemoteOwnerControl(),
  Duration? recoveryPersistenceDebounceDuration,
  WorkspaceNow? now,
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
    modelCatalogStore: modelCatalogStore,
    recoveryStore: recoveryStore,
    remoteAppServerHostProbe: remoteAppServerHostProbe,
    remoteAppServerOwnerInspector: remoteAppServerOwnerInspector,
    remoteAppServerOwnerControl: remoteAppServerOwnerControl,
    recoveryPersistenceDebounceDuration:
        recoveryPersistenceDebounceDuration ??
        const Duration(milliseconds: 250),
    now: now,
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

final class FakeRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const FakeRemoteOwnerInspector(this.snapshot);

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

final class ThrowingRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const ThrowingRemoteOwnerInspector();

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('owner inspection should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}

final class ThrowingRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  const ThrowingRemoteOwnerControl();

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }
}

final class MutableRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  MutableRemoteOwnerControl({
    required CodexRemoteAppServerOwnerSnapshot snapshot,
  }) : _snapshot = snapshot;

  CodexRemoteAppServerOwnerSnapshot _snapshot;
  int startCalls = 0;
  int stopCalls = 0;
  int restartCalls = 0;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return _snapshot;
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    restartCalls += 1;
    await stopOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
    return startOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    startCalls += 1;
    _snapshot = CodexRemoteAppServerOwnerSnapshot(
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      status: CodexRemoteAppServerOwnerStatus.running,
      sessionName: 'pocket-relay-$ownerId',
      endpoint: const CodexRemoteAppServerEndpoint(
        host: '127.0.0.1',
        port: 4100,
      ),
      detail: 'Managed remote app-server is ready.',
    );
    return _snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    stopCalls += 1;
    _snapshot = CodexRemoteAppServerOwnerSnapshot(
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      status: CodexRemoteAppServerOwnerStatus.missing,
      sessionName: 'pocket-relay-$ownerId',
      detail: 'No managed remote app-server is running for this connection.',
    );
    return _snapshot;
  }
}

class RecordingConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  RecordingConnectionWorkspaceRecoveryStore({this.initialState});

  final ConnectionWorkspaceRecoveryState? initialState;
  final List<ConnectionWorkspaceRecoveryState?> savedStates =
      <ConnectionWorkspaceRecoveryState?>[];
  ConnectionWorkspaceRecoveryState? _state;

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async {
    return _state ?? initialState;
  }

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    _state = state;
    savedStates.add(state);
  }
}

ConnectionProfile workspaceProfile(String label, String host) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
  );
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

Future<void> startBusyTurn(
  ConnectionLaneBinding binding,
  FakeCodexAppServerClient appServerClient,
) async {
  appServerClient.emit(
    const CodexAppServerNotificationEvent(
      method: 'thread/started',
      params: <String, Object?>{
        'thread': <String, Object?>{'id': 'thread_123'},
      },
    ),
  );
  appServerClient.emit(
    const CodexAppServerNotificationEvent(
      method: 'turn/started',
      params: <String, Object?>{
        'threadId': 'thread_123',
        'turn': <String, Object?>{
          'id': 'turn_running',
          'status': 'running',
          'model': 'gpt-5.4',
          'effort': 'high',
        },
      },
    ),
  );
  await Future<void>.delayed(Duration.zero);
  expect(binding.sessionController.sessionState.isBusy, isTrue);
}

class StickyDisconnectFakeCodexAppServerClient
    extends FakeCodexAppServerClient {
  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
  }
}

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  FakeFlutterSecureStorage(this.data);

  final Map<String, String> data;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
      return;
    }
    data[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
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

Future<void> closeClientLists(
  Map<String, List<FakeCodexAppServerClient>> clientsByConnectionId,
) async {
  for (final clients in clientsByConnectionId.values) {
    for (final client in clients) {
      await client.close();
    }
  }
}
