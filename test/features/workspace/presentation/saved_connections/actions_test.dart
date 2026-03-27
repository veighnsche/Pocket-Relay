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

      await tester.ensureVisible(
        find.byKey(const ValueKey('edit_conn_secondary')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
      await tester.pump();

      final editButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('edit_conn_secondary')),
      );
      expect(editButton.onPressed, isNull);

      expect(
        repository.loadConnectionCallsById['conn_secondary'],
        initialLoadCount + 1,
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

  testWidgets(
    'saved connections disables busy lane lifecycle actions without blocking go to lane',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector:
            MapRemoteOwnerInspector(<String, CodexRemoteAppServerOwnerSnapshot>{
              'conn_primary': runningOwnerSnapshot('conn_primary'),
              'conn_secondary': notRunningOwnerSnapshot('conn_secondary'),
            }),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      var binding = controller.bindingForConnectionId('conn_primary');
      if (binding == null) {
        await controller.instantiateConnection('conn_primary');
        binding = controller.bindingForConnectionId('conn_primary');
      }
      expect(binding, isNotNull);
      final liveBinding = binding!;
      await clientsById['conn_primary']!.connect(
        profile: liveBinding.sessionController.profile,
        secrets: liveBinding.sessionController.secrets,
      );
      clientsById['conn_primary']!.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{'id': 'thread_123'},
          },
        ),
      );
      clientsById['conn_primary']!.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{
              'id': 'turn_running',
              'status': 'running',
              'model': 'gpt-5.4',
              'effort': 'high',
            },
          },
        ),
      );
      await tester.pump();
      expect(liveBinding.sessionController.sessionState.isBusy, isTrue);

      await tester.pumpWidget(buildDormantRosterApp(controller));
      await tester.pump();

      final goToLaneButton = tester.widget<FilledButton>(
        find.byKey(const ValueKey('open_connection_conn_primary')),
      );
      final disconnectButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('disconnect_conn_primary')),
      );
      final closeLaneButton = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('close_lane_conn_primary')),
      );
      final restartServerButton = tester.widget<TextButton>(
        find.byKey(
          const ValueKey('saved_connection_remote_server_restart_conn_primary'),
        ),
      );
      final stopServerButton = tester.widget<TextButton>(
        find.byKey(
          const ValueKey('saved_connection_remote_server_stop_conn_primary'),
        ),
      );

      expect(goToLaneButton.onPressed, isNotNull);
      expect(disconnectButton.onPressed, isNull);
      expect(closeLaneButton.onPressed, isNull);
      expect(restartServerButton.onPressed, isNull);
      expect(stopServerButton.onPressed, isNull);
    },
  );
}
