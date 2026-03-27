import '../support/workspace_surface_test_support.dart';

void main() {
  testWidgets(
    'live lane ignores connection settings results after the surface unmounts',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
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

      expect(settingsOverlayDelegate.launchCount, 1);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();
      settingsOverlayDelegate.complete(
        ConnectionSettingsSubmitPayload(
          profile: workspaceProfile('Primary Renamed', 'primary.changed'),
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

  testWidgets(
    'live lane settings reuse the cached model catalog when staged edits require reconnect',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      final modelCatalogStore = MemoryConnectionModelCatalogStore();
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          DeferredConnectionSettingsOverlayDelegate();
      final cachedCatalog = ConnectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22),
        models: const <ConnectionAvailableModel>[
          ConnectionAvailableModel(
            id: 'preset_cached_default',
            model: 'gpt-cached-default',
            displayName: 'GPT Cached Default',
            description: 'Cached backend default.',
            hidden: false,
            supportedReasoningEfforts:
                <ConnectionAvailableModelReasoningEffortOption>[
                  ConnectionAvailableModelReasoningEffortOption(
                    reasoningEffort: CodexReasoningEffort.high,
                    description: 'Cached deep reasoning mode.',
                  ),
                ],
            defaultReasoningEffort: CodexReasoningEffort.high,
            inputModalities: <String>['text'],
            supportsPersonality: false,
            isDefault: true,
          ),
        ],
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await controller.saveConnectionModelCatalog(cachedCatalog);
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Updated', 'changed.local'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );
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

      expect(settingsOverlayDelegate.launchCount, 1);
      expect(
        settingsOverlayDelegate.launchedSettings.single.$1.host,
        'changed.local',
      );
      expect(
        settingsOverlayDelegate.launchedModelCatalogs.single,
        cachedCatalog,
      );
      expect(
        settingsOverlayDelegate.launchedModelCatalogSources.single,
        ConnectionSettingsModelCatalogSource.connectionCache,
      );
      expect(client.listModelCalls, isEmpty);
      expect(settingsOverlayDelegate.launchedRefreshCallbacks.single, isNull);
      expect(
        settingsOverlayDelegate.launchedRemoteRuntimeCallbacks.single,
        isNotNull,
      );

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );
}
