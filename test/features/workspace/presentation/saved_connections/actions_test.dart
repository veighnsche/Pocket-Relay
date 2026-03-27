import '../support/workspace_surface_test_support.dart';

void main() {
  testWidgets(
    'dormant roster add action launches settings only once while pending',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate =
          DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        buildDormantRosterApp(
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
      expect(
        settingsOverlayDelegate.launchedSystemTemplates.single,
        isNotEmpty,
      );
      expect(settingsOverlayDelegate.launchedSystemTesters.single, isNotNull);

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'saved connections edit action enters busy state before loading saved settings',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final repository = DelayedMemoryCodexConnectionRepository(
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
      )..loadConnectionGates['conn_secondary'] = Completer<void>();
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        repository: repository,
      );
      final settingsOverlayDelegate =
          DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        buildDormantRosterApp(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();
      final initialLoadCount =
          repository.loadConnectionCallsById['conn_secondary'] ?? 0;

      await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
      await tester.pump();

      final editButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('edit_conn_secondary')),
      );
      expect(editButton.onPressed, isNull);

      expect(
        repository.loadConnectionCallsById['conn_secondary'],
        greaterThan(initialLoadCount),
      );

      repository.loadConnectionGates['conn_secondary']!.complete();
      await tester.pump();

      expect(settingsOverlayDelegate.launchCount, 1);

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'saved connections edit action stages reconnect changes for an open row',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate =
          DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final originalBinding = controller.bindingForConnectionId('conn_primary');

      await tester.pumpWidget(
        buildDormantRosterApp(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('edit_conn_primary')));
      await tester.pump();

      expect(settingsOverlayDelegate.launchCount, 1);

      settingsOverlayDelegate.complete(
        ConnectionSettingsSubmitPayload(
          profile: workspaceProfile('Primary Renamed', 'primary.changed'),
          secrets: const ConnectionSecrets(password: 'updated-secret'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        controller.state.requiresSavedSettingsReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.catalog.connectionForId('conn_primary')?.profile.host,
        'primary.changed',
      );
      expect(
        controller.bindingForConnectionId('conn_primary'),
        originalBinding,
      );
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );

  testWidgets(
    'saved connections roster does not render remote server controls',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector:
            MapRemoteOwnerInspector(<String, CodexRemoteAppServerOwnerSnapshot>{
              'conn_primary': notRunningOwnerSnapshot('conn_primary'),
              'conn_secondary': notRunningOwnerSnapshot('conn_secondary'),
            }),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(buildDormantRosterApp(controller));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('saved_connection_remote_server_start_conn_secondary'),
        ),
        findsNothing,
      );
    },
  );
}
