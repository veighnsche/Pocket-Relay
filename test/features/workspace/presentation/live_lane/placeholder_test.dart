import '../support/workspace_surface_test_support.dart';

void main() {
  testWidgets(
    'live lane settings receive the controller-owned initial remote runtime for the selected connection',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: const FakeRemoteOwnerInspector(
          CodexRemoteAppServerOwnerSnapshot(
            ownerId: 'conn_primary',
            workspaceDir: '/workspace',
            status: CodexRemoteAppServerOwnerStatus.running,
            sessionName: 'pocket-relay-conn_primary',
            endpoint: CodexRemoteAppServerEndpoint(
              host: '127.0.0.1',
              port: 4100,
            ),
          ),
        ),
      );
      final settingsOverlayDelegate =
          DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pump();

      expect(
        settingsOverlayDelegate.launchedInitialRemoteRuntimes.single,
        controller.state.remoteRuntimeFor('conn_primary'),
      );

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'live lane shows a typed local recovery warning when bootstrap discards corrupted recovery state',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: const ThrowingConnectionWorkspaceRecoveryStore(
          ConnectionWorkspaceRecoveryStoreCorruptedException(
            'Persisted workspace recovery metadata is malformed JSON.',
          ),
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Local recovery unavailable'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.appBootstrapRecoveryStateLoadFailed.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('malformed JSON'), findsOneWidget);
    },
  );

  testWidgets(
    'live lane shows typed device continuity warnings from workspace state',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      controller.setWakeLockWarning(
        DeviceCapabilityErrors.wakeLockEnableFailed(
          error: StateError('wakelock plugin unavailable'),
        ),
      );

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wake lock unavailable'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.deviceWakeLockEnableFailed.code}]',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('wakelock plugin unavailable'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live empty lane connect action starts the remote server for the selected lane',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final ownerControl = RecordingRemoteOwnerControl();
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': notRunningOwnerSnapshot('conn_primary'),
          },
        ),
        remoteAppServerOwnerControl: ownerControl,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Server stopped.'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
      );
      await tester.pumpAndSettle();

      expect(ownerControl.startCalls, hasLength(1));
      expect(ownerControl.startCalls.single.ownerId, 'conn_primary');
    },
  );

  testWidgets(
    'live empty lane shows workspace controls inside the placeholder instead of the strip',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('lane_connection_status_strip')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('lane_empty_state_workspace_path')),
        findsOneWidget,
      );
      expect(find.text('/workspace'), findsOneWidget);
      expect(find.text('Workspace'), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live empty local lane keeps the recovery strip when placeholder controls are unavailable',
    (tester) async {
      final profile = workspaceProfile(
        'Primary Box',
        'primary.local',
      ).copyWith(connectionMode: ConnectionMode.local, host: '', username: '');
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: profile,
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient();
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: client,
            initialSavedProfile: SavedProfile(
              profile: connection.profile,
              secrets: connection.secrets,
            ),
            ownsAppServerClient: false,
          );
        },
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await client.connect(
        profile: profile,
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );
      await client.disconnect();

      await tester.pumpWidget(
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('lane_connection_status_strip')),
        findsOneWidget,
      );
      expect(find.text('Live transport lost'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('lane_empty_state_workspace_path')),
        findsNothing,
      );
    },
  );
}
