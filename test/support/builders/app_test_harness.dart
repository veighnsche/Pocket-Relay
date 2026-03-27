import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/app/pocket_relay_app.dart';
import 'package:pocket_relay/src/core/device/background_grace_host.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void registerAppTestStorageLifecycle() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesAsyncPlatform? originalAsyncPlatform;

  setUp(() {
    originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
}

SavedProfile testSavedProfile() {
  return SavedProfile(
    profile: ConnectionProfile.defaults().copyWith(
      label: 'Dev Box',
      host: 'devbox.local',
      username: 'vince',
      workspaceDir: '/workspace',
    ),
    secrets: const ConnectionSecrets(password: 'secret'),
  );
}

SavedConnection buildSavedConnection({
  String id = 'conn_primary',
  SavedProfile? savedProfile,
}) {
  final resolvedSavedProfile = savedProfile ?? testSavedProfile();
  return SavedConnection(
    id: id,
    profile: resolvedSavedProfile.profile,
    secrets: resolvedSavedProfile.secrets,
  );
}

PocketRelayApp buildCatalogApp({
  SavedProfile? savedProfile,
  CodexConnectionRepository? connectionRepository,
  DisplayWakeLockController? displayWakeLockController,
  BackgroundGraceController? backgroundGraceController,
  CodexAppServerClient? appServerClient,
  CodexRemoteAppServerHostProbe? remoteAppServerHostProbe,
  CodexRemoteAppServerOwnerInspector? remoteAppServerOwnerInspector,
  ConnectionSettingsOverlayDelegate? settingsOverlayDelegate,
}) {
  return PocketRelayApp(
    connectionRepository:
        connectionRepository ??
        MemoryCodexConnectionRepository.single(
          savedProfile: savedProfile ?? testSavedProfile(),
          connectionId: 'conn_primary',
        ),
    modelCatalogStore: MemoryConnectionModelCatalogStore(),
    recoveryStore: MemoryConnectionWorkspaceRecoveryStore(),
    displayWakeLockController: displayWakeLockController,
    backgroundGraceController: backgroundGraceController,
    appServerClient: appServerClient,
    remoteAppServerHostProbe:
        remoteAppServerHostProbe ??
        const FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
    remoteAppServerOwnerInspector:
        remoteAppServerOwnerInspector ??
        FakeRemoteOwnerInspector(
          const CodexRemoteAppServerOwnerSnapshot(
            ownerId: 'conn_primary',
            workspaceDir: '/workspace',
            status: CodexRemoteAppServerOwnerStatus.missing,
          ),
        ),
    settingsOverlayDelegate:
        settingsOverlayDelegate ??
        const ModalConnectionSettingsOverlayDelegate(),
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
}

class DeferredConnectionRepository implements CodexConnectionRepository {
  final _completer = Completer<SavedConnection>();
  SavedConnection? _savedConnection;

  void complete(SavedProfile savedProfile) {
    final savedConnection = buildSavedConnection(savedProfile: savedProfile);
    _savedConnection = savedConnection;
    if (!_completer.isCompleted) {
      _completer.complete(savedConnection);
    }
  }

  @override
  Future<ConnectionCatalogState> loadCatalog() async {
    final savedConnection = await _loadSavedConnection();
    return ConnectionCatalogState(
      orderedConnectionIds: <String>[savedConnection.id],
      connectionsById: <String, SavedConnectionSummary>{
        savedConnection.id: savedConnection.toSummary(),
      },
    );
  }

  @override
  Future<WorkspaceCatalogState> loadWorkspaceCatalog() async {
    final savedConnection = await _loadSavedConnection();
    return WorkspaceCatalogState(
      orderedWorkspaceIds: <String>[savedConnection.id],
      workspacesById: <String, SavedWorkspaceSummary>{
        savedConnection.id: SavedWorkspaceSummary(
          id: savedConnection.id,
          profile: workspaceProfileFromConnectionProfile(
            savedConnection.profile,
            systemId: _systemIdForConnection(savedConnection),
          ),
        ),
      },
    );
  }

  @override
  Future<SystemCatalogState> loadSystemCatalog() async {
    final savedConnection = await _loadSavedConnection();
    if (!savedConnection.profile.isRemote) {
      return const SystemCatalogState.empty();
    }
    final systemId = _systemIdForConnection(savedConnection)!;
    return SystemCatalogState(
      orderedSystemIds: <String>[systemId],
      systemsById: <String, SavedSystemSummary>{
        systemId: SavedSystemSummary(
          id: systemId,
          profile: systemProfileFromConnectionProfile(savedConnection.profile),
        ),
      },
    );
  }

  @override
  Future<SavedConnection> loadConnection(String connectionId) async {
    final savedConnection = await _loadSavedConnection();
    if (savedConnection.id != connectionId) {
      throw StateError('Unknown saved connection: $connectionId');
    }
    return savedConnection;
  }

  @override
  Future<SavedWorkspace> loadWorkspace(String workspaceId) async {
    final savedConnection = await loadConnection(workspaceId);
    return SavedWorkspace(
      id: savedConnection.id,
      profile: workspaceProfileFromConnectionProfile(
        savedConnection.profile,
        systemId: _systemIdForConnection(savedConnection),
      ),
    );
  }

  @override
  Future<SavedSystem> loadSystem(String systemId) async {
    final savedConnection = await _loadSavedConnection();
    final expectedSystemId = _systemIdForConnection(savedConnection);
    if (expectedSystemId == null || expectedSystemId != systemId) {
      throw StateError('Unknown saved system: $systemId');
    }
    return SavedSystem(
      id: systemId,
      profile: systemProfileFromConnectionProfile(savedConnection.profile),
      secrets: savedConnection.secrets,
    );
  }

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    final connection = SavedConnection(
      id: 'conn_created',
      profile: profile,
      secrets: secrets,
    );
    await saveConnection(connection);
    return connection;
  }

  @override
  Future<SavedWorkspace> createWorkspace({
    required WorkspaceProfile profile,
  }) async {
    throw UnsupportedError('createWorkspace is not used in this test.');
  }

  @override
  Future<SavedSystem> createSystem({
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    throw UnsupportedError('createSystem is not used in this test.');
  }

  @override
  Future<void> saveConnection(SavedConnection connection) async {
    _savedConnection = connection;
    if (!_completer.isCompleted) {
      _completer.complete(connection);
    }
  }

  @override
  Future<void> saveWorkspace(SavedWorkspace workspace) async {
    throw UnsupportedError('saveWorkspace is not used in this test.');
  }

  @override
  Future<void> saveSystem(SavedSystem system) async {
    throw UnsupportedError('saveSystem is not used in this test.');
  }

  @override
  Future<void> deleteConnection(String connectionId) async {
    if (_savedConnection?.id == connectionId) {
      throw UnsupportedError('deleteConnection is not used in this test.');
    }
  }

  @override
  Future<void> deleteWorkspace(String workspaceId) async {
    throw UnsupportedError('deleteWorkspace is not used in this test.');
  }

  @override
  Future<void> deleteSystem(String systemId) async {
    throw UnsupportedError('deleteSystem is not used in this test.');
  }

  Future<SavedConnection> _loadSavedConnection() async {
    return _savedConnection ?? await _completer.future;
  }
}

class FailOnceConnectionRepository implements CodexConnectionRepository {
  FailOnceConnectionRepository({required this.savedConnection});

  final SavedConnection savedConnection;
  int loadCatalogCalls = 0;

  @override
  Future<ConnectionCatalogState> loadCatalog() async {
    loadCatalogCalls += 1;
    if (loadCatalogCalls == 1) {
      throw StateError('catalog load failed');
    }
    return ConnectionCatalogState(
      orderedConnectionIds: <String>[savedConnection.id],
      connectionsById: <String, SavedConnectionSummary>{
        savedConnection.id: savedConnection.toSummary(),
      },
    );
  }

  @override
  Future<WorkspaceCatalogState> loadWorkspaceCatalog() =>
      _singleWorkspaceCatalog(savedConnection);

  @override
  Future<SystemCatalogState> loadSystemCatalog() =>
      _singleSystemCatalog(savedConnection);

  @override
  Future<SavedConnection> loadConnection(String connectionId) async {
    if (connectionId != savedConnection.id) {
      throw StateError('Unknown saved connection: $connectionId');
    }
    return savedConnection;
  }

  @override
  Future<SavedWorkspace> loadWorkspace(String workspaceId) async {
    final connection = await loadConnection(workspaceId);
    return SavedWorkspace(
      id: connection.id,
      profile: workspaceProfileFromConnectionProfile(
        connection.profile,
        systemId: _systemIdForConnection(connection),
      ),
    );
  }

  @override
  Future<SavedSystem> loadSystem(String systemId) async {
    final expectedSystemId = _systemIdForConnection(savedConnection);
    if (expectedSystemId == null || expectedSystemId != systemId) {
      throw StateError('Unknown saved system: $systemId');
    }
    return SavedSystem(
      id: systemId,
      profile: systemProfileFromConnectionProfile(savedConnection.profile),
      secrets: savedConnection.secrets,
    );
  }

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    throw UnsupportedError('createConnection is not used in this test.');
  }

  @override
  Future<SavedWorkspace> createWorkspace({
    required WorkspaceProfile profile,
  }) async {
    throw UnsupportedError('createWorkspace is not used in this test.');
  }

  @override
  Future<SavedSystem> createSystem({
    required SystemProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    throw UnsupportedError('createSystem is not used in this test.');
  }

  @override
  Future<void> saveConnection(SavedConnection connection) async {
    throw UnsupportedError('saveConnection is not used in this test.');
  }

  @override
  Future<void> saveWorkspace(SavedWorkspace workspace) async {
    throw UnsupportedError('saveWorkspace is not used in this test.');
  }

  @override
  Future<void> saveSystem(SavedSystem system) async {
    throw UnsupportedError('saveSystem is not used in this test.');
  }

  @override
  Future<void> deleteConnection(String connectionId) async {
    throw UnsupportedError('deleteConnection is not used in this test.');
  }

  @override
  Future<void> deleteWorkspace(String workspaceId) async {
    throw UnsupportedError('deleteWorkspace is not used in this test.');
  }

  @override
  Future<void> deleteSystem(String systemId) async {
    throw UnsupportedError('deleteSystem is not used in this test.');
  }
}

String? _systemIdForConnection(SavedConnection connection) {
  return connection.profile.isRemote ? 'sys_${connection.id}' : null;
}

Future<WorkspaceCatalogState> _singleWorkspaceCatalog(
  SavedConnection connection,
) async {
  return WorkspaceCatalogState(
    orderedWorkspaceIds: <String>[connection.id],
    workspacesById: <String, SavedWorkspaceSummary>{
      connection.id: SavedWorkspaceSummary(
        id: connection.id,
        profile: workspaceProfileFromConnectionProfile(
          connection.profile,
          systemId: _systemIdForConnection(connection),
        ),
      ),
    },
  );
}

Future<SystemCatalogState> _singleSystemCatalog(
  SavedConnection connection,
) async {
  final systemId = _systemIdForConnection(connection);
  if (systemId == null) {
    return const SystemCatalogState.empty();
  }
  return SystemCatalogState(
    orderedSystemIds: <String>[systemId],
    systemsById: <String, SavedSystemSummary>{
      systemId: SavedSystemSummary(
        id: systemId,
        profile: systemProfileFromConnectionProfile(connection.profile),
      ),
    },
  );
}

class FakeDisplayWakeLockController implements DisplayWakeLockController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }
}
