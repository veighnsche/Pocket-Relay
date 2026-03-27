import 'mobile_shell_test_support.dart';

void main() {
  testWidgets(
    'closing the selected live lane keeps the remaining live lane active',
    (tester) async {
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

      await tester.tap(
        find.byKey(const ValueKey('lane_connection_action_close')),
      );
      await tester.pumpAndSettle();

      expect(controller.state.liveConnectionIds, <String>['conn_primary']);
      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(controller.state.isShowingLiveLane, isTrue);
      expect(find.text('Primary Box'), findsOneWidget);
      expect(find.text('primary.local'), findsOneWidget);
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
      expect(clientsById['conn_secondary']?.disconnectCalls, 1);
    },
  );

  testWidgets('adding a dormant connection appends a new roster entry', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final repository = MemoryCodexConnectionRepository(
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
      connectionIdGenerator: () => 'conn_created',
    );
    final controller = buildWorkspaceController(
      clientsById: clientsById,
      repository: repository,
    );
    final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
      results: <ConnectionSettingsSubmitPayload?>[
        ConnectionSettingsSubmitPayload(
          profile: workspaceProfile('Created Box', 'created.local'),
          secrets: const ConnectionSecrets(password: 'secret-3'),
        ),
      ],
    );
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(
      buildShell(controller, settingsOverlayDelegate: settingsOverlayDelegate),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add_connection')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('saved_connection_conn_created')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('saved_connection_conn_created')),
      findsOneWidget,
    );
    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
      'conn_created',
    ]);
    expect(controller.state.nonLiveSavedConnectionIds, <String>[
      'conn_secondary',
      'conn_created',
    ]);
  });

  testWidgets('editing a dormant connection updates the roster entry', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate(
      results: <ConnectionSettingsSubmitPayload?>[
        ConnectionSettingsSubmitPayload(
          profile: workspaceProfile('Secondary Renamed', 'secondary.changed'),
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
      buildShell(controller, settingsOverlayDelegate: settingsOverlayDelegate),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('workspace_page_view')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('edit_conn_secondary')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
    await tester.pumpAndSettle();

    expect(find.text('Secondary Renamed'), findsOneWidget);
    expect(find.text('Secondary Renamed'), findsOneWidget);
    expect(find.text('secondary.changed · /workspace'), findsOneWidget);
    expect(
      controller.state.catalog.connectionForId('conn_secondary')?.profile.host,
      'secondary.changed',
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });

  testWidgets(
    'saved connection cards show a workspace fallback when the saved path is missing',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile(
              'Secondary Box',
              'secondary.local',
            ).copyWith(workspaceDir: ''),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        repository: repository,
      );
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

      expect(find.text('Secondary Box'), findsOneWidget);
      expect(find.text('secondary.local · Workspace not set'), findsOneWidget);
    },
  );

  testWidgets('deleting a dormant connection removes it from the roster', (
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
      find.byKey(const ValueKey('delete_conn_secondary')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete_conn_secondary')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('saved_connection_conn_secondary')),
      findsNothing,
    );
    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
    ]);
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
    expect(clientsById['conn_secondary']?.disconnectCalls, 0);
  });
}
