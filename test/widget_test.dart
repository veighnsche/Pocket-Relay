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
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_desktop_shell.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_mobile_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';
import 'support/fakes/connection_settings_overlay_delegate.dart';

void main() {
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

  testWidgets(
    'keeps the display awake only while a turn is actively ticking',
    (tester) async {
      final controller = _FakeDisplayWakeLockController();
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(
          displayWakeLockController: controller,
          appServerClient: appServerClient,
        ),
      );

      await tester.pumpAndSettle();

      expect(controller.enabledStates, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('composer_input')),
        'Keep the screen awake while this runs',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(controller.enabledStates, <bool>[true]);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.enabledStates, <bool>[true, false]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('shows the Pocket Relay shell', (tester) async {
    await tester.pumpWidget(
      _buildCatalogApp(
        savedProfile: SavedProfile(
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Developer Box'), findsOneWidget);
    expect(find.text('Configure remote'), findsWidgets);
    expect(find.byType(ConnectionWorkspaceMobileShell), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace_page_view')), findsOneWidget);
    expect(find.byType(ChatRootAdapter), findsOneWidget);
    expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
    expect(find.byType(FlutterChatAppChrome), findsOneWidget);
    expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
    expect(find.byType(FlutterChatComposerRegion), findsOneWidget);
  });

  testWidgets('boots the first saved connection from the catalog', (
    tester,
  ) async {
    final repository = MemoryCodexConnectionRepository(
      initialConnections: <SavedConnection>[
        SavedConnection(
          id: 'conn_primary',
          profile: _savedProfile().profile,
          secrets: _savedProfile().secrets,
        ),
        SavedConnection(
          id: 'conn_secondary',
          profile: _savedProfile().profile.copyWith(
            label: 'Second Box',
            host: 'second.local',
          ),
          secrets: const ConnectionSecrets(password: 'second-secret'),
        ),
      ],
    );

    await tester.pumpWidget(_buildCatalogApp(connectionRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Dev Box'), findsOneWidget);
    expect(find.text('devbox.local'), findsOneWidget);
    expect(find.text('Second Box'), findsNothing);
    expect(find.text('second.local'), findsNothing);
  });

  testWidgets('boots an empty workspace into the dormant roster shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCatalogApp(connectionRepository: MemoryCodexConnectionRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConnectionWorkspaceMobileShell), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace_page_view')), findsOneWidget);
    expect(find.byType(ChatRootAdapter), findsNothing);
    expect(find.text('No saved connections yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('add_connection')), findsOneWidget);
  });

  testWidgets(
    'uses the material renderer path by default on iOS',
    (tester) async {
      await tester.pumpWidget(_buildCatalogApp());

      await tester.pumpAndSettle();

      expect(find.byType(ConnectionWorkspaceMobileShell), findsOneWidget);
      expect(find.byType(ChatRootAdapter), findsOneWidget);
      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
      expect(find.byType(FlutterChatAppChrome), findsOneWidget);
      expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
      expect(find.byType(FlutterChatComposerRegion), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'uses the material renderer path by default on macOS',
    (tester) async {
      await tester.pumpWidget(_buildCatalogApp());

      await tester.pumpAndSettle();

      expect(find.byType(ConnectionWorkspaceDesktopShell), findsOneWidget);
      expect(find.byType(ChatRootAdapter), findsOneWidget);
      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
      expect(find.byType(FlutterChatAppChrome), findsOneWidget);
      expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
      expect(find.byType(FlutterChatComposerRegion), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'shows the material bootstrap shell while the catalog is loading on iOS',
    (tester) async {
      final connectionRepository = _DeferredConnectionRepository();

      await tester.pumpWidget(
        _buildCatalogApp(connectionRepository: connectionRepository),
      );
      await tester.pump();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Pocket Relay'), findsOneWidget);
      expect(
        find.text('Loading saved connections and workspace state.'),
        findsOneWidget,
      );
      expect(find.byType(Image), findsOneWidget);

      connectionRepository.complete(_savedProfile());
      await tester.pumpAndSettle();

      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'shows a retry action when workspace bootstrap initialization fails',
    (tester) async {
      final connectionRepository = _FailOnceConnectionRepository(
        savedConnection: SavedConnection(
          id: 'conn_primary',
          profile: _savedProfile().profile,
          secrets: _savedProfile().secrets,
        ),
      );

      await tester.pumpWidget(
        _buildCatalogApp(connectionRepository: connectionRepository),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Pocket Relay could not finish loading your workspace.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('retry_workspace_bootstrap')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('retry_workspace_bootstrap')));
      await tester.pumpAndSettle();

      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
      expect(connectionRepository.loadCatalogCalls, 2);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'routes live settings through the material workspace settings renderer on iOS',
    (tester) async {
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate();

      await tester.pumpWidget(
        _buildCatalogApp(settingsOverlayDelegate: settingsOverlayDelegate),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();

      expect(settingsOverlayDelegate.launchedSettings, hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('uses system theme mode', (tester) async {
    await tester.pumpWidget(
      _buildCatalogApp(
        savedProfile: SavedProfile(
          profile: ConnectionProfile.defaults().copyWith(
            host: 'example.com',
            username: 'vince',
          ),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets(
    'disposes the active lane when the top-level app shell unmounts',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildCatalogApp(appServerClient: appServerClient),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(appServerClient.disconnectCalls, 1);
    },
  );

  testWidgets(
    'presents top-level menu actions through the shared popup menu by default on iOS',
    (tester) async {
      await tester.pumpWidget(_buildCatalogApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('New thread'), findsOneWidget);
      expect(find.text('Clear transcript'), findsOneWidget);
      expect(find.text('Saved connections'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('settings sheet no longer shows a dark mode toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildCatalogApp(
        savedProfile: SavedProfile(
          profile: ConnectionProfile.defaults().copyWith(
            host: 'example.com',
            username: 'vince',
          ),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Dark mode'), findsNothing);
  });
}

SavedProfile _savedProfile() {
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

PocketRelayApp _buildCatalogApp({
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
          savedProfile: savedProfile ?? _savedProfile(),
          connectionId: 'conn_primary',
        ),
    modelCatalogStore: MemoryConnectionModelCatalogStore(),
    recoveryStore: MemoryConnectionWorkspaceRecoveryStore(),
    displayWakeLockController: displayWakeLockController,
    backgroundGraceController: backgroundGraceController,
    appServerClient: appServerClient,
    remoteAppServerHostProbe:
        remoteAppServerHostProbe ??
        const _FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
    remoteAppServerOwnerInspector:
        remoteAppServerOwnerInspector ??
        _FakeRemoteOwnerInspector(
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

final class _FakeRemoteHostProbe implements CodexRemoteAppServerHostProbe {
  const _FakeRemoteHostProbe(this.capabilities);

  final CodexRemoteAppServerHostCapabilities capabilities;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return capabilities;
  }
}

final class _FakeRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const _FakeRemoteOwnerInspector(this.snapshot);

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

class _DeferredConnectionRepository implements CodexConnectionRepository {
  final _completer = Completer<SavedConnection>();
  SavedConnection? _savedConnection;

  void complete(SavedProfile savedProfile) {
    final savedConnection = SavedConnection(
      id: 'conn_primary',
      profile: savedProfile.profile,
      secrets: savedProfile.secrets,
    );
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
  Future<SavedConnection> loadConnection(String connectionId) async {
    final savedConnection = await _loadSavedConnection();
    if (savedConnection.id != connectionId) {
      throw StateError('Unknown saved connection: $connectionId');
    }
    return savedConnection;
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
  Future<void> saveConnection(SavedConnection connection) async {
    _savedConnection = connection;
    if (!_completer.isCompleted) {
      _completer.complete(connection);
    }
  }

  @override
  Future<void> deleteConnection(String connectionId) async {
    if (_savedConnection?.id == connectionId) {
      throw UnsupportedError('deleteConnection is not used in this test.');
    }
  }

  Future<SavedConnection> _loadSavedConnection() async {
    return _savedConnection ?? await _completer.future;
  }
}

class _FailOnceConnectionRepository implements CodexConnectionRepository {
  _FailOnceConnectionRepository({required this.savedConnection});

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
  Future<SavedConnection> loadConnection(String connectionId) async {
    if (connectionId != savedConnection.id) {
      throw StateError('Unknown saved connection: $connectionId');
    }
    return savedConnection;
  }

  @override
  Future<SavedConnection> createConnection({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    throw UnsupportedError('createConnection is not used in this test.');
  }

  @override
  Future<void> saveConnection(SavedConnection connection) async {
    throw UnsupportedError('saveConnection is not used in this test.');
  }

  @override
  Future<void> deleteConnection(String connectionId) async {
    throw UnsupportedError('deleteConnection is not used in this test.');
  }
}

class _FakeDisplayWakeLockController implements DisplayWakeLockController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }
}
