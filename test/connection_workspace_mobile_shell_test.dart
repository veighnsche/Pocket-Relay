import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_mobile_shell.dart';

import 'support/fake_codex_app_server_client.dart';

void main() {
  testWidgets('swiping past the live lane reveals the dormant roster', (
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

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dormant connections'), findsWidgets);
    expect(
      find.byKey(const ValueKey('dormant_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(controller.state.isShowingDormantRoster, isTrue);
    expect(controller.state.selectedConnectionId, 'conn_primary');
  });

  testWidgets('overflow menu opens the dormant roster page', (tester) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dormant connections'));
    await tester.pumpAndSettle();

    expect(controller.state.isShowingDormantRoster, isTrue);
    expect(find.byKey(const ValueKey('dormant_roster_page')), findsOneWidget);
  });

  testWidgets('swiping offscreen does not dispose the live lane', (
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

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  testWidgets('instantiating from the roster opens a new live lane', (
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

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('instantiate_conn_secondary')));
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
    ]);
    expect(controller.state.selectedConnectionId, 'conn_secondary');
    expect(controller.state.isShowingLiveLane, isTrue);
    expect(find.text('Secondary Box · secondary.local'), findsOneWidget);
    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('workspace_page_view')),
    );
    expect(pageView.childrenDelegate.estimatedChildCount, 3);
  });

  testWidgets('closing the only live lane from the overflow shows the roster', (
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

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close lane'));
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, isEmpty);
    expect(controller.state.dormantConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
    ]);
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

  testWidgets(
    'closing the selected live lane keeps the remaining live lane active',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(_buildShell(controller));
      await tester.pumpAndSettle();

      await tester.drag(
        find.byKey(const ValueKey('workspace_page_view')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('instantiate_conn_secondary')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close lane'));
      await tester.pumpAndSettle();

      expect(controller.state.liveConnectionIds, <String>['conn_primary']);
      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(controller.state.isShowingLiveLane, isTrue);
      expect(find.text('Primary Box · primary.local'), findsOneWidget);
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
      expect(clientsById['conn_secondary']?.disconnectCalls, 1);
    },
  );
}

Widget _buildShell(ConnectionWorkspaceController controller) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: ConnectionWorkspaceMobileShell(
      workspaceController: controller,
      platformPolicy: PocketPlatformPolicy.resolve(
        platform: TargetPlatform.android,
      ),
    ),
  );
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
}) {
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
  final handoffStore = MemoryCodexConnectionHandoffStore();

  return ConnectionWorkspaceController(
    connectionRepository: repository,
    connectionHandoffStore: handoffStore,
    laneBindingFactory:
        ({required connectionId, required connection, required handoff}) {
          final appServerClient = clientsById[connectionId]!;
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            conversationHandoffStore: ConnectionScopedConversationHandoffStore(
              connectionId: connectionId,
              handoffStore: handoffStore,
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
