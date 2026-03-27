import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_live_lane_surface.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_saved_connections_content.dart';

export 'dart:async';
export 'package:flutter/material.dart';
export 'package:flutter_test/flutter_test.dart';
export 'package:pocket_relay/src/core/errors/pocket_error.dart';
export 'package:pocket_relay/src/core/models/connection_models.dart';
export 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
export 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
export 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
export 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
export 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
export 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
export 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
export 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
export 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
export 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
export 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
export 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
export 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

Widget buildDormantRosterApp(
  ConnectionWorkspaceController controller, {
  ConnectionSettingsOverlayDelegate? settingsOverlayDelegate,
}) {
  final resolvedSettingsOverlayDelegate =
      settingsOverlayDelegate ??
      (DeferredConnectionSettingsOverlayDelegate()..complete(null));
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ConnectionWorkspaceSavedConnectionsContent(
            workspaceController: controller,
            description: 'Saved connections test surface.',
            settingsOverlayDelegate: resolvedSettingsOverlayDelegate,
            useSafeArea: false,
          );
        },
      ),
    ),
  );
}

Widget buildLiveLaneApp(
  ConnectionWorkspaceController controller,
  ConnectionLaneBinding laneBinding, {
  required ConnectionSettingsOverlayDelegate settingsOverlayDelegate,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: ConnectionWorkspaceLiveLaneSurface(
        workspaceController: controller,
        laneBinding: laneBinding,
        platformPolicy: PocketPlatformPolicy.resolve(
          platform: TargetPlatform.android,
        ),
        settingsOverlayDelegate: settingsOverlayDelegate,
      ),
    ),
  );
}

Widget buildWorkspaceDrivenLiveLaneApp(
  ConnectionWorkspaceController controller, {
  required ConnectionSettingsOverlayDelegate settingsOverlayDelegate,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final laneBinding = controller.selectedLaneBinding;
        if (laneBinding == null) {
          return const SizedBox.shrink();
        }

        return Scaffold(
          body: ConnectionWorkspaceLiveLaneSurface(
            workspaceController: controller,
            laneBinding: laneBinding,
            platformPolicy: PocketPlatformPolicy.resolve(
              platform: TargetPlatform.android,
            ),
            settingsOverlayDelegate: settingsOverlayDelegate,
          ),
        );
      },
    ),
  );
}

ConnectionWorkspaceController buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  CodexConnectionRepository? repository,
  ConnectionModelCatalogStore? modelCatalogStore,
  CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
      const FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
  CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
      const ThrowingRemoteOwnerInspector(),
  CodexRemoteAppServerOwnerControl remoteAppServerOwnerControl =
      const ThrowingRemoteOwnerControl(),
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
    remoteAppServerHostProbe: remoteAppServerHostProbe,
    remoteAppServerOwnerInspector: remoteAppServerOwnerInspector,
    remoteAppServerOwnerControl: remoteAppServerOwnerControl,
    laneBindingFactory: ({required connectionId, required connection}) {
      return ConnectionLaneBinding(
        connectionId: connectionId,
        profileStore: ConnectionScopedProfileStore(
          connectionId: connectionId,
          connectionRepository: resolvedRepository,
        ),
        appServerClient: clientsById[connectionId]!,
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

final class MapRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const MapRemoteOwnerInspector(this.snapshotsByOwnerId);

  final Map<String, CodexRemoteAppServerOwnerSnapshot> snapshotsByOwnerId;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshotsByOwnerId[ownerId] ??
        notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
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
    return CodexRemoteAppServerOwnerSnapshot(
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      status: CodexRemoteAppServerOwnerStatus.missing,
      sessionName: 'pocket-relay-$ownerId',
      detail: 'No managed remote app-server is running for this connection.',
    );
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

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }
}

typedef _RemoteOwnerControlCall = ({
  ConnectionProfile profile,
  ConnectionSecrets secrets,
  String ownerId,
  String workspaceDir,
});

final class RecordingRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  final List<_RemoteOwnerControlCall> startCalls = <_RemoteOwnerControlCall>[];
  final List<_RemoteOwnerControlCall> stopCalls = <_RemoteOwnerControlCall>[];
  final List<_RemoteOwnerControlCall> restartCalls =
      <_RemoteOwnerControlCall>[];

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
    return notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    startCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    return notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    stopCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    return notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    restartCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    return notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }
}

final class StatefulRemoteOwnerRuntime
    implements
        CodexRemoteAppServerOwnerInspector,
        CodexRemoteAppServerOwnerControl {
  StatefulRemoteOwnerRuntime({
    Map<String, CodexRemoteAppServerOwnerStatus>? statusesByOwnerId,
  }) : _statusesByOwnerId = Map<String, CodexRemoteAppServerOwnerStatus>.from(
         statusesByOwnerId ?? const <String, CodexRemoteAppServerOwnerStatus>{},
       );

  final Map<String, CodexRemoteAppServerOwnerStatus> _statusesByOwnerId;
  final List<_RemoteOwnerControlCall> startCalls = <_RemoteOwnerControlCall>[];
  final List<_RemoteOwnerControlCall> stopCalls = <_RemoteOwnerControlCall>[];
  final List<_RemoteOwnerControlCall> restartCalls =
      <_RemoteOwnerControlCall>[];

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
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    startCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    _statusesByOwnerId[ownerId] = CodexRemoteAppServerOwnerStatus.running;
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    stopCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    _statusesByOwnerId[ownerId] = CodexRemoteAppServerOwnerStatus.stopped;
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    restartCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    _statusesByOwnerId[ownerId] = CodexRemoteAppServerOwnerStatus.running;
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  CodexRemoteAppServerOwnerSnapshot _snapshotFor(
    String ownerId, {
    required String workspaceDir,
  }) {
    return switch (_statusesByOwnerId[ownerId] ??
        CodexRemoteAppServerOwnerStatus.stopped) {
      CodexRemoteAppServerOwnerStatus.running => runningOwnerSnapshot(
        ownerId,
        workspaceDir: workspaceDir,
      ),
      CodexRemoteAppServerOwnerStatus.unhealthy =>
        CodexRemoteAppServerOwnerSnapshot(
          ownerId: ownerId,
          workspaceDir: workspaceDir,
          status: CodexRemoteAppServerOwnerStatus.unhealthy,
          sessionName: 'pocket-relay-$ownerId',
          endpoint: const CodexRemoteAppServerEndpoint(
            host: '127.0.0.1',
            port: 4100,
          ),
          detail: 'readyz failed',
        ),
      CodexRemoteAppServerOwnerStatus.missing ||
      CodexRemoteAppServerOwnerStatus.stopped => notRunningOwnerSnapshot(
        ownerId,
        workspaceDir: workspaceDir,
      ),
    };
  }
}

final class ThrowingRemoteHostProbe implements CodexRemoteAppServerHostProbe {
  const ThrowingRemoteHostProbe(this.message);

  final String message;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    throw Exception(message);
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

ConnectionProfile workspaceProfile(String label, String host) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

CodexRemoteAppServerOwnerSnapshot notRunningOwnerSnapshot(
  String ownerId, {
  String workspaceDir = '/workspace',
}) {
  return CodexRemoteAppServerOwnerSnapshot(
    ownerId: ownerId,
    workspaceDir: workspaceDir,
    status: CodexRemoteAppServerOwnerStatus.stopped,
    sessionName: 'pocket-relay-$ownerId',
  );
}

CodexRemoteAppServerOwnerSnapshot runningOwnerSnapshot(
  String ownerId, {
  String workspaceDir = '/workspace',
}) {
  return CodexRemoteAppServerOwnerSnapshot(
    ownerId: ownerId,
    workspaceDir: workspaceDir,
    status: CodexRemoteAppServerOwnerStatus.running,
    sessionName: 'pocket-relay-$ownerId',
    endpoint: const CodexRemoteAppServerEndpoint(host: '127.0.0.1', port: 4100),
  );
}

ConnectionModelCatalog connectionModelCatalog({
  required String connectionId,
  required DateTime fetchedAt,
  required String model,
  required String displayName,
  required String description,
}) {
  return ConnectionModelCatalog(
    connectionId: connectionId,
    fetchedAt: fetchedAt,
    models: <ConnectionAvailableModel>[
      ConnectionAvailableModel(
        id: 'preset_$model',
        model: model,
        displayName: displayName,
        description: description,
        hidden: false,
        supportedReasoningEfforts:
            const <ConnectionAvailableModelReasoningEffortOption>[
              ConnectionAvailableModelReasoningEffortOption(
                reasoningEffort: CodexReasoningEffort.medium,
                description: 'Balanced mode.',
              ),
            ],
        defaultReasoningEffort: CodexReasoningEffort.medium,
        inputModalities: const <String>['text'],
        supportsPersonality: false,
        isDefault: true,
      ),
    ],
  );
}

CodexAppServerModel backendModel({
  required String id,
  required String model,
  required String displayName,
  required String description,
  bool isDefault = false,
}) {
  return CodexAppServerModel(
    id: id,
    model: model,
    displayName: displayName,
    description: description,
    hidden: false,
    supportedReasoningEfforts: const <CodexAppServerReasoningEffortOption>[],
    defaultReasoningEffort: CodexReasoningEffort.medium,
    inputModalities: const <String>['text'],
    supportsPersonality: false,
    isDefault: isDefault,
  );
}

Map<String, FakeCodexAppServerClient> buildClientsById([
  String firstConnectionId = 'conn_primary',
  String? secondConnectionId,
]) {
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

Future<void> closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}

class DeferredConnectionSettingsOverlayDelegate
    implements ConnectionSettingsOverlayDelegate {
  int launchCount = 0;
  final List<(ConnectionProfile, ConnectionSecrets)> launchedSettings =
      <(ConnectionProfile, ConnectionSecrets)>[];
  final List<ConnectionModelCatalog?> launchedModelCatalogs =
      <ConnectionModelCatalog?>[];
  final List<ConnectionRemoteRuntimeState?> launchedInitialRemoteRuntimes =
      <ConnectionRemoteRuntimeState?>[];
  final List<ConnectionSettingsModelCatalogSource?>
  launchedModelCatalogSources = <ConnectionSettingsModelCatalogSource?>[];
  final List<
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  >
  launchedRefreshCallbacks =
      <
        Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
      >[];
  final List<ConnectionSettingsRemoteRuntimeRefresher?>
  launchedRemoteRuntimeCallbacks =
      <ConnectionSettingsRemoteRuntimeRefresher?>[];
  Completer<ConnectionSettingsSubmitPayload?> _completer =
      Completer<ConnectionSettingsSubmitPayload?>();

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
    ConnectionRemoteRuntimeState? initialRemoteRuntime,
    ConnectionModelCatalog? availableModelCatalog,
    ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
    onRefreshModelCatalog,
    ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime,
  }) {
    launchCount += 1;
    launchedSettings.add((initialProfile, initialSecrets));
    launchedModelCatalogs.add(availableModelCatalog);
    launchedInitialRemoteRuntimes.add(initialRemoteRuntime);
    launchedModelCatalogSources.add(availableModelCatalogSource);
    launchedRefreshCallbacks.add(onRefreshModelCatalog);
    launchedRemoteRuntimeCallbacks.add(onRefreshRemoteRuntime);
    return _completer.future;
  }

  void complete(ConnectionSettingsSubmitPayload? payload) {
    if (_completer.isCompleted) {
      _completer = Completer<ConnectionSettingsSubmitPayload?>();
      _completer.complete(payload);
      return;
    }
    _completer.complete(payload);
  }
}

class DelayedMemoryCodexConnectionRepository
    extends MemoryCodexConnectionRepository {
  DelayedMemoryCodexConnectionRepository({required super.initialConnections});

  final Map<String, int> loadConnectionCallsById = <String, int>{};
  final Map<String, Completer<void>> loadConnectionGates =
      <String, Completer<void>>{};

  @override
  Future<SavedConnection> loadConnection(String connectionId) async {
    loadConnectionCallsById[connectionId] =
        (loadConnectionCallsById[connectionId] ?? 0) + 1;
    final gate = loadConnectionGates[connectionId];
    if (gate != null) {
      await gate.future;
    }
    return super.loadConnection(connectionId);
  }
}
