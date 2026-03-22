import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_dormant_roster_content.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_live_lane_surface.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

void main() {
  testWidgets(
    'dormant roster add action launches settings only once while pending',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildDormantRosterApp(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('add_connection')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('add_connection')));
      await tester.pump();

      expect(settingsOverlayDelegate.launchCount, 1);

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dormant roster edit action enters busy state before loading saved settings',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final repository = _DelayedMemoryCodexConnectionRepository(
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
      )..loadConnectionGates['conn_secondary'] = Completer<void>();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        repository: repository,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildDormantRosterApp(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
      await tester.pump();

      expect(repository.loadConnectionCallsById['conn_secondary'], 1);

      repository.loadConnectionGates['conn_secondary']!.complete();
      await tester.pump();

      expect(settingsOverlayDelegate.launchCount, 1);

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dormant roster offers return to open lane when every saved connection is already live',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await controller.instantiateConnection('conn_secondary');
      controller.showDormantRoster();

      await tester.pumpWidget(_buildDormantRosterApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Return to open lane'), findsOneWidget);

      await tester.tap(find.text('Return to open lane'));
      await tester.pumpAndSettle();

      expect(controller.state.isShowingLiveLane, isTrue);
      expect(controller.state.selectedConnectionId, 'conn_secondary');
    },
  );

  testWidgets('dormant roster uses tighter panel corners', (tester) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildDormantRosterApp(controller));
    await tester.pumpAndSettle();

    final panelSurfaces = tester.widgetList<PocketPanelSurface>(
      find.byType(PocketPanelSurface),
    );

    expect(panelSurfaces, isNotEmpty);
    expect(panelSurfaces.every((surface) => surface.radius == 12), isTrue);
  });

  testWidgets(
    'live lane ignores connection settings results after the surface unmounts',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        repository: repository,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        _buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pump();

      expect(settingsOverlayDelegate.launchCount, 1);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      settingsOverlayDelegate.complete(
        ConnectionSettingsSubmitPayload(
          profile: _profile('Primary Renamed', 'primary.changed'),
          secrets: const ConnectionSecrets(password: 'updated-secret'),
        ),
      );
      await tester.pumpAndSettle();

      final savedConnection = await controller.loadSavedConnection(
        'conn_primary',
      );
      expect(savedConnection.profile.host, 'primary.local');
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(controller.state.liveConnectionIds, <String>['conn_primary']);
    },
  );
}

Widget _buildDormantRosterApp(
  ConnectionWorkspaceController controller, {
  ConnectionSettingsOverlayDelegate? settingsOverlayDelegate,
}) {
  final resolvedSettingsOverlayDelegate =
      settingsOverlayDelegate ??
      (_DeferredConnectionSettingsOverlayDelegate()..complete(null));
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: ConnectionWorkspaceDormantRosterContent(
        workspaceController: controller,
        description: 'Saved connections test surface.',
        settingsOverlayDelegate: resolvedSettingsOverlayDelegate,
        useSafeArea: false,
      ),
    ),
  );
}

Widget _buildLiveLaneApp(
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

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  CodexConnectionRepository? repository,
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
          SavedConnection(
            id: 'conn_secondary',
            profile: _profile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
  return ConnectionWorkspaceController(
    connectionRepository: resolvedRepository,
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

ConnectionProfile _profile(String label, String host) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

Map<String, FakeCodexAppServerClient> _buildClientsById([
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

Future<void> _closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}

class _DeferredConnectionSettingsOverlayDelegate
    implements ConnectionSettingsOverlayDelegate {
  int launchCount = 0;
  final List<(ConnectionProfile, ConnectionSecrets)> launchedSettings =
      <(ConnectionProfile, ConnectionSecrets)>[];
  Completer<ConnectionSettingsSubmitPayload?> _completer =
      Completer<ConnectionSettingsSubmitPayload?>();

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
  }) {
    launchCount += 1;
    launchedSettings.add((initialProfile, initialSecrets));
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

class _DelayedMemoryCodexConnectionRepository
    extends MemoryCodexConnectionRepository {
  _DelayedMemoryCodexConnectionRepository({required super.initialConnections});

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
