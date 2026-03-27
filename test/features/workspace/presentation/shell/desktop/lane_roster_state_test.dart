import 'desktop_shell_test_support.dart';

void main() {
  testWidgets('selecting a live lane from the sidebar returns to the lane', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await controller.instantiateConnection('conn_secondary');
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    controller.showSavedConnections();
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('desktop_connection_conn_secondary')),
    );
    await tester.pumpAndSettle();

    expect(controller.state.isShowingLiveLane, isTrue);
    expect(controller.state.selectedConnectionId, 'conn_secondary');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
        matching: find.text('Secondary Box'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
        matching: find.text('secondary.local · /workspace'),
      ),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets('closing a live lane from the sidebar keeps other lanes intact', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await controller.instantiateConnection('conn_secondary');
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('desktop_close_lane_conn_primary')),
    );
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, <String>['conn_secondary']);
    expect(controller.state.selectedConnectionId, 'conn_secondary');
    expect(controller.state.nonLiveSavedConnectionIds, <String>[
      'conn_primary',
    ]);
    expect(
      find.byKey(const ValueKey('desktop_connection_conn_primary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('desktop_close_lane_conn_primary')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
        matching: find.text('Secondary Box'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
        matching: find.text('secondary.local · /workspace'),
      ),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 1);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets('closing the last live lane shows the dormant roster', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('desktop_close_lane_conn_primary')),
    );
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, isEmpty);
    expect(controller.state.selectedConnectionId, isNull);
    expect(controller.state.isShowingSavedConnections, isTrue);
    expect(
      find.byKey(const ValueKey('saved_connection_conn_primary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('saved_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 1);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets('empty workspace shows the first-connection CTA', (tester) async {
    final controller = buildWorkspaceController(
      clientsById: <String, FakeCodexAppServerClient>{},
      repository: MemoryCodexConnectionRepository(),
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    expect(find.text('No saved workspaces yet.'), findsOneWidget);
    expect(find.text('Return to open lane'), findsNothing);
    expect(find.byKey(const ValueKey('add_connection')), findsOneWidget);
  });

  testWidgets(
    'desktop live rows show a saved-changes badge when reconnect is pending',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
        results: <ConnectionSettingsSubmitPayload?>[
          ConnectionSettingsSubmitPayload(
            profile: workspaceProfile('Primary Renamed', 'primary.changed'),
            secrets: const ConnectionSecrets(password: 'updated-secret'),
          ),
        ],
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();

      expect(controller.state.requiresReconnect('conn_primary'), isTrue);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('lane_connection_status_strip')),
          matching: find.text('Changes pending'),
        ),
        findsNothing,
      );
      expect(find.text('Apply changes'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lane_connection_action_reconnect')),
        findsOneWidget,
      );
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );
}
