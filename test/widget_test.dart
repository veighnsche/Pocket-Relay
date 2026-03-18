import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/app.dart';
import 'package:pocket_relay/src/core/device/display_wake_lock_host.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_app_chrome.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_mobile_shell.dart';

import 'support/fake_codex_app_server_client.dart';

void main() {
  testWidgets(
    'enables the display wake lock for the top-level app shell',
    (tester) async {
      final controller = _FakeDisplayWakeLockController();

      await tester.pumpWidget(
        _buildCatalogApp(displayWakeLockController: controller),
      );

      await tester.pumpAndSettle();

      expect(controller.enabledStates, contains(true));
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

    expect(find.text('Pocket Relay'), findsOneWidget);
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

    expect(find.text('Dev Box · devbox.local'), findsOneWidget);
    expect(find.text('Second Box · second.local'), findsNothing);
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
    'uses the cupertino foundation path by default on iOS while transcript stays on the flutter region path',
    (tester) async {
      await tester.pumpWidget(_buildCatalogApp());

      await tester.pumpAndSettle();

      expect(find.byType(ConnectionWorkspaceMobileShell), findsOneWidget);
      expect(find.byType(ChatRootAdapter), findsOneWidget);
      expect(find.byType(CupertinoChatScreenRenderer), findsOneWidget);
      expect(find.byType(CupertinoChatAppChrome), findsOneWidget);
      expect(find.byType(CupertinoChatComposerRegion), findsOneWidget);
      expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
      expect(find.byType(FlutterChatScreenRenderer), findsNothing);
      expect(find.byType(FlutterChatAppChrome), findsNothing);
      expect(find.byType(FlutterChatComposerRegion), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'uses the cupertino foundation path by default on macOS while transcript stays on the flutter region path',
    (tester) async {
      await tester.pumpWidget(_buildCatalogApp());

      await tester.pumpAndSettle();

      expect(find.byType(ConnectionWorkspaceDesktopShell), findsOneWidget);
      expect(find.byType(ChatRootAdapter), findsOneWidget);
      expect(find.byType(CupertinoChatScreenRenderer), findsOneWidget);
      expect(find.byType(CupertinoChatAppChrome), findsOneWidget);
      expect(find.byType(CupertinoChatComposerRegion), findsOneWidget);
      expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
      expect(find.byType(FlutterChatScreenRenderer), findsNothing);
      expect(find.byType(FlutterChatAppChrome), findsNothing);
      expect(find.byType(FlutterChatComposerRegion), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'shows a cupertino bootstrap shell while the catalog is loading on iOS',
    (tester) async {
      final connectionRepository = _DeferredConnectionRepository();

      await tester.pumpWidget(
        _buildCatalogApp(connectionRepository: connectionRepository),
      );
      await tester.pump();

      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Scaffold), findsNothing);

      connectionRepository.complete(_savedProfile());
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoChatScreenRenderer), findsOneWidget);
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

      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('New thread'), findsOneWidget);
      expect(find.text('Clear transcript'), findsOneWidget);
      expect(find.text('Dormant connections'), findsOneWidget);
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
    ),
    secrets: const ConnectionSecrets(password: 'secret'),
  );
}

PocketRelayApp _buildCatalogApp({
  SavedProfile? savedProfile,
  CodexConnectionRepository? connectionRepository,
  CodexConnectionHandoffStore? connectionHandoffStore,
  DisplayWakeLockController? displayWakeLockController,
  CodexAppServerClient? appServerClient,
}) {
  return PocketRelayApp(
    connectionRepository:
        connectionRepository ??
        MemoryCodexConnectionRepository.single(
          savedProfile: savedProfile ?? _savedProfile(),
          connectionId: 'conn_primary',
        ),
    connectionHandoffStore:
        connectionHandoffStore ?? MemoryCodexConnectionHandoffStore(),
    displayWakeLockController: displayWakeLockController,
    appServerClient: appServerClient,
  );
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

class _FakeDisplayWakeLockController implements DisplayWakeLockController {
  final List<bool> enabledStates = <bool>[];

  @override
  Future<void> setEnabled(bool enabled) async {
    enabledStates.add(enabled);
  }
}
