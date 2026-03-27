import '../support/workspace_surface_test_support.dart';

void main() {
  testWidgets(
    'dormant roster edit action launches settings with the cached model catalog',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final modelCatalogStore = MemoryConnectionModelCatalogStore();
      final cachedCatalog = ConnectionModelCatalog(
        connectionId: 'conn_secondary',
        fetchedAt: DateTime.utc(2026, 3, 22),
        models: const <ConnectionAvailableModel>[
          ConnectionAvailableModel(
            id: 'preset_cached_secondary_default',
            model: 'gpt-cached-secondary',
            displayName: 'GPT Cached Secondary',
            description: 'Dormant cached backend default.',
            hidden: false,
            supportedReasoningEfforts:
                <ConnectionAvailableModelReasoningEffortOption>[
                  ConnectionAvailableModelReasoningEffortOption(
                    reasoningEffort: CodexReasoningEffort.medium,
                    description: 'Balanced cached mode.',
                  ),
                ],
            defaultReasoningEffort: CodexReasoningEffort.medium,
            inputModalities: <String>['text'],
            supportsPersonality: false,
            isDefault: true,
          ),
        ],
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await controller.saveConnectionModelCatalog(cachedCatalog);
      await tester.pumpWidget(
        buildDormantRosterApp(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('edit_conn_secondary')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
      await tester.pump();

      expect(settingsOverlayDelegate.launchCount, 1);
      expect(
        settingsOverlayDelegate.launchedModelCatalogs.single,
        cachedCatalog,
      );
      expect(
        settingsOverlayDelegate.launchedModelCatalogSources.single,
        ConnectionSettingsModelCatalogSource.connectionCache,
      );
      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dormant roster add action uses the last known model catalog when available',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final lastKnownCatalog = ConnectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22),
        models: const <ConnectionAvailableModel>[
          ConnectionAvailableModel(
            id: 'preset_global_default',
            model: 'gpt-global-default',
            displayName: 'GPT Global Default',
            description: 'Last known backend default.',
            hidden: false,
            supportedReasoningEfforts:
                <ConnectionAvailableModelReasoningEffortOption>[
                  ConnectionAvailableModelReasoningEffortOption(
                    reasoningEffort: CodexReasoningEffort.medium,
                    description: 'Balanced global mode.',
                  ),
                ],
            defaultReasoningEffort: CodexReasoningEffort.medium,
            inputModalities: <String>['text'],
            supportsPersonality: false,
            isDefault: true,
          ),
        ],
      );
      final modelCatalogStore = MemoryConnectionModelCatalogStore(
        initialLastKnownCatalog: lastKnownCatalog,
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
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

      await tester.tap(find.byKey(const ValueKey('add_connection')));
      await tester.pump();

      expect(settingsOverlayDelegate.launchCount, 1);
      expect(
        settingsOverlayDelegate.launchedModelCatalogs.single,
        lastKnownCatalog,
      );
      expect(
        settingsOverlayDelegate.launchedModelCatalogSources.single,
        ConnectionSettingsModelCatalogSource.lastKnownCache,
      );
      expect(settingsOverlayDelegate.launchedRefreshCallbacks.single, isNull);
      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dormant roster edit action uses the last known model catalog when the connection cache is empty',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final lastKnownCatalog = ConnectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22),
        models: const <ConnectionAvailableModel>[
          ConnectionAvailableModel(
            id: 'preset_global_default',
            model: 'gpt-global-default',
            displayName: 'GPT Global Default',
            description: 'Last known backend default.',
            hidden: false,
            supportedReasoningEfforts:
                <ConnectionAvailableModelReasoningEffortOption>[
                  ConnectionAvailableModelReasoningEffortOption(
                    reasoningEffort: CodexReasoningEffort.medium,
                    description: 'Balanced global mode.',
                  ),
                ],
            defaultReasoningEffort: CodexReasoningEffort.medium,
            inputModalities: <String>['text'],
            supportsPersonality: false,
            isDefault: true,
          ),
        ],
      );
      final modelCatalogStore = MemoryConnectionModelCatalogStore(
        initialLastKnownCatalog: lastKnownCatalog,
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
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

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('edit_conn_secondary')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
      await tester.pump();

      expect(settingsOverlayDelegate.launchCount, 1);
      expect(
        settingsOverlayDelegate.launchedModelCatalogs.single,
        lastKnownCatalog,
      );
      expect(
        settingsOverlayDelegate.launchedModelCatalogSources.single,
        ConnectionSettingsModelCatalogSource.lastKnownCache,
      );
      expect(settingsOverlayDelegate.launchedRefreshCallbacks.single, isNull);

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dormant roster edit action disables reference fallback when no cached model catalog exists',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final modelCatalogStore = MemoryConnectionModelCatalogStore();
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
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

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('edit_conn_secondary')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
      await tester.pump();

      expect(settingsOverlayDelegate.launchCount, 1);
      expect(settingsOverlayDelegate.launchedModelCatalogs.single, isNull);
      expect(
        settingsOverlayDelegate.launchedModelCatalogSources.single,
        isNull,
      );
      expect(settingsOverlayDelegate.launchedRefreshCallbacks.single, isNull);

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dormant roster offers return to open lane when every saved connection is already live',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await controller.instantiateConnection('conn_secondary');
      controller.showSavedConnections();

      await tester.pumpWidget(buildDormantRosterApp(controller));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('saved_connection_conn_primary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('saved_connection_conn_secondary')),
        findsOneWidget,
      );
    },
  );

  testWidgets('dormant roster uses tighter panel corners', (tester) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(buildDormantRosterApp(controller));
    await tester.pumpAndSettle();

    final panelSurfaces = tester.widgetList<PocketPanelSurface>(
      find.byType(PocketPanelSurface),
    );

    expect(panelSurfaces, isNotEmpty);
    expect(panelSurfaces.every((surface) => surface.radius == 12), isTrue);
  });

  testWidgets(
    'live lane settings use the last known model catalog without auto fetching on open',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      await client.connect(
        profile: workspaceProfile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

      final lastKnownCatalog = ConnectionModelCatalog(
        connectionId: 'conn_secondary',
        fetchedAt: DateTime.utc(2026, 3, 22),
        models: const <ConnectionAvailableModel>[
          ConnectionAvailableModel(
            id: 'preset_global_default',
            model: 'gpt-global-default',
            displayName: 'GPT Global Default',
            description: 'Last known backend default.',
            hidden: false,
            supportedReasoningEfforts:
                <ConnectionAvailableModelReasoningEffortOption>[
                  ConnectionAvailableModelReasoningEffortOption(
                    reasoningEffort: CodexReasoningEffort.medium,
                    description: 'Balanced global mode.',
                  ),
                ],
            defaultReasoningEffort: CodexReasoningEffort.medium,
            inputModalities: <String>['text'],
            supportsPersonality: false,
            isDefault: true,
          ),
        ],
      );
      final modelCatalogStore = MemoryConnectionModelCatalogStore(
        initialLastKnownCatalog: lastKnownCatalog,
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
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
      expect(
        settingsOverlayDelegate.launchedModelCatalogs.single,
        lastKnownCatalog,
      );
      expect(
        settingsOverlayDelegate.launchedModelCatalogSources.single,
        ConnectionSettingsModelCatalogSource.lastKnownCache,
      );
      expect(
        settingsOverlayDelegate.launchedRefreshCallbacks.single,
        isNotNull,
      );
      expect(
        settingsOverlayDelegate.launchedRemoteRuntimeCallbacks.single,
        isNotNull,
      );
      expect(client.listModelCalls, isEmpty);

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );
}
