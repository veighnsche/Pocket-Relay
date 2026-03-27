import 'mobile_shell_test_support.dart';

void main() {
  testWidgets('swiping offscreen does not dispose the live lane', (
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

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  testWidgets('iPhone saved connections page uses material primitives', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(
      buildShell(controller, platform: TargetPlatform.iOS),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved connections'), findsWidgets);
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Add connection'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open lane'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Edit'), findsWidgets);
  });

  testWidgets('instantiating from the roster opens a new live lane', (
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

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('open_connection_conn_secondary')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('open_connection_conn_secondary')),
    );
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
    ]);
    expect(controller.state.selectedConnectionId, 'conn_secondary');
    expect(controller.state.isShowingLiveLane, isTrue);
    expect(find.text('Secondary Box'), findsOneWidget);
    expect(find.text('secondary.local'), findsOneWidget);
    final pageView = tester.widget<PageView>(
      find.byKey(const ValueKey('workspace_page_view')),
    );
    expect(pageView.childrenDelegate.estimatedChildCount, 3);
  });

  testWidgets('closing the only live lane from the overflow shows the roster', (
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

    await tester.tap(find.byKey(const ValueKey('lane_connection_action_close')));
    await tester.pumpAndSettle();

    expect(controller.state.liveConnectionIds, isEmpty);
    expect(controller.state.nonLiveSavedConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
    ]);
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

  testWidgets(
    'empty workspace shows a first-connection CTA and can create the first saved connection',
    (tester) async {
      final controller = buildWorkspaceController(
        clientsById: <String, FakeCodexAppServerClient>{},
        repository: MemoryCodexConnectionRepository(
          connectionIdGenerator: () => 'conn_created',
        ),
      );
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
        results: <ConnectionSettingsSubmitPayload?>[
          ConnectionSettingsSubmitPayload(
            profile: workspaceProfile('Created Box', 'created.local'),
            secrets: const ConnectionSecrets(password: 'secret-3'),
          ),
        ],
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await tester.pumpWidget(
        buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No saved connections yet.'), findsOneWidget);
      expect(find.text('Return to open lane'), findsNothing);
      expect(find.byKey(const ValueKey('add_connection')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('add_connection')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('saved_connection_conn_created')),
        findsOneWidget,
      );
      expect(controller.state.catalog.orderedConnectionIds, <String>[
        'conn_created',
      ]);
      expect(controller.state.liveConnectionIds, isEmpty);
      expect(controller.state.isShowingSavedConnections, isTrue);
    },
  );
}
