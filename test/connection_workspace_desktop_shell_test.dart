import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/codex_conversation_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_desktop_shell.dart';

import 'support/fake_codex_app_server_client.dart';
import 'support/fake_connection_settings_overlay_delegate.dart';

void main() {
  testWidgets('renders live and dormant sections in the desktop sidebar', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    expect(find.text('Connections'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Dormant'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop_live_conn_primary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('desktop_dormant_roster')),
      findsOneWidget,
    );
    expect(find.textContaining('Secondary Box'), findsOneWidget);
  });

  testWidgets('dormant sidebar action shows the roster in the main pane', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop_dormant_roster')));
    await tester.pumpAndSettle();

    expect(controller.state.isShowingDormantRoster, isTrue);
    expect(
      find.byKey(const ValueKey('dormant_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  testWidgets('selecting a live lane from the sidebar returns to the lane', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await controller.instantiateConnection('conn_secondary');
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    controller.showDormantRoster();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop_live_conn_secondary')));
    await tester.pumpAndSettle();

    expect(controller.state.isShowingLiveLane, isTrue);
    expect(controller.state.selectedConnectionId, 'conn_secondary');
    expect(find.text('Secondary Box · secondary.local'), findsOneWidget);
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets('closing a live lane from the sidebar keeps other lanes intact', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await controller.instantiateConnection('conn_secondary');
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('desktop_close_lane_conn_primary')),
    );
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, <String>['conn_secondary']);
    expect(controller.state.selectedConnectionId, 'conn_secondary');
    expect(controller.state.dormantConnectionIds, <String>['conn_primary']);
    expect(
      find.byKey(const ValueKey('desktop_live_conn_primary')),
      findsNothing,
    );
    expect(find.text('Secondary Box · secondary.local'), findsOneWidget);
    expect(clientsById['conn_primary']?.disconnectCalls, 1);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets('closing the last live lane shows the dormant roster', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('desktop_close_lane_conn_primary')),
    );
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, isEmpty);
    expect(controller.state.selectedConnectionId, isNull);
    expect(controller.state.isShowingDormantRoster, isTrue);
    expect(
      find.byKey(const ValueKey('dormant_connection_conn_primary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('dormant_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 1);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets('empty workspace shows the first-connection CTA', (tester) async {
    final controller = _buildWorkspaceController(
      clientsById: <String, FakeCodexAppServerClient>{},
      repository: MemoryCodexConnectionRepository(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    expect(find.text('No saved connections yet.'), findsOneWidget);
    expect(find.text('Return to lane'), findsNothing);
    expect(find.byKey(const ValueKey('add_connection')), findsOneWidget);
  });

  testWidgets('desktop dormant roster can add a saved connection', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
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
      connectionIdGenerator: () => 'conn_created',
    );
    final controller = _buildWorkspaceController(
      clientsById: clientsById,
      repository: repository,
    );
    final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
      results: <ConnectionSettingsSubmitPayload?>[
        ConnectionSettingsSubmitPayload(
          profile: _profile('Created Box', 'created.local'),
          secrets: const ConnectionSecrets(password: 'secret-3'),
        ),
      ],
    );
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(
      _buildShell(controller, settingsOverlayDelegate: settingsOverlayDelegate),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop_dormant_roster')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add_connection')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dormant_connection_conn_created')),
      findsOneWidget,
    );
    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
      'conn_created',
    ]);
  });

  testWidgets('desktop dormant roster can delete a dormant connection', (
    tester,
  ) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final handoffStore = MemoryCodexConnectionHandoffStore(
      initialValues: <String, SavedConversationHandoff>{
        'conn_secondary': const SavedConversationHandoff(
          resumeThreadId: 'thread_saved',
        ),
      },
    );
    final controller = _buildWorkspaceController(
      clientsById: clientsById,
      handoffStore: handoffStore,
    );
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop_dormant_roster')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete_conn_secondary')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dormant_connection_conn_secondary')),
      findsNothing,
    );
    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
    ]);
    expect(
      await handoffStore.load('conn_secondary'),
      const SavedConversationHandoff(),
    );
  });
}

Widget _buildShell(
  ConnectionWorkspaceController controller, {
  ConnectionSettingsOverlayDelegate? settingsOverlayDelegate,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: ConnectionWorkspaceDesktopShell(
      workspaceController: controller,
      platformPolicy: PocketPlatformPolicy.resolve(
        platform: TargetPlatform.macOS,
      ),
      settingsOverlayDelegate:
          settingsOverlayDelegate ?? FakeConnectionSettingsOverlayDelegate(),
    ),
  );
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  MemoryCodexConnectionRepository? repository,
  MemoryCodexConnectionHandoffStore? handoffStore,
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
  final resolvedHandoffStore =
      handoffStore ?? MemoryCodexConnectionHandoffStore();

  return ConnectionWorkspaceController(
    connectionRepository: resolvedRepository,
    connectionHandoffStore: resolvedHandoffStore,
    laneBindingFactory:
        ({required connectionId, required connection, required handoff}) {
          final appServerClient = clientsById[connectionId]!;
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: resolvedRepository,
            ),
            conversationHandoffStore: ConnectionScopedConversationHandoffStore(
              connectionId: connectionId,
              handoffStore: resolvedHandoffStore,
            ),
            appServerClient: appServerClient,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            initialSavedConversationHandoff: handoff,
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
  );
}

Map<String, FakeCodexAppServerClient> _buildClientsById(
  String firstConnectionId,
  String secondConnectionId,
) {
  return <String, FakeCodexAppServerClient>{
    firstConnectionId: FakeCodexAppServerClient(),
    secondConnectionId: FakeCodexAppServerClient(),
  };
}

Future<void> _closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}
