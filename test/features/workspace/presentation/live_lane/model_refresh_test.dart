import '../support/workspace_surface_test_support.dart';

void main() {
  testWidgets(
    'live lane refresh callback fetches the backend catalog and saves connection and last known caches',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      client.listedModels.add(
        const CodexAppServerModel(
          id: 'preset_gpt_live_default',
          model: 'gpt-live-default',
          displayName: 'GPT Live Default',
          description: 'Live backend default.',
          hidden: false,
          supportedReasoningEfforts: <CodexAppServerReasoningEffortOption>[
            CodexAppServerReasoningEffortOption(
              reasoningEffort: CodexReasoningEffort.low,
              description: 'Fastest available lane setting.',
            ),
            CodexAppServerReasoningEffortOption(
              reasoningEffort: CodexReasoningEffort.xhigh,
              description: 'Deepest live lane setting.',
            ),
          ],
          defaultReasoningEffort: CodexReasoningEffort.xhigh,
          inputModalities: <String>['text'],
          supportsPersonality: false,
          isDefault: true,
        ),
      );
      await client.connect(
        profile: workspaceProfile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

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

      final refreshCallback =
          settingsOverlayDelegate.launchedRefreshCallbacks.single;
      expect(refreshCallback, isNotNull);

      final refreshedCatalog = await refreshCallback!(
        ConnectionSettingsDraft.fromConnection(
          profile: settingsOverlayDelegate.launchedSettings.single.$1,
          secrets: settingsOverlayDelegate.launchedSettings.single.$2,
        ),
      );

      expect(refreshedCatalog, isNotNull);
      expect(refreshedCatalog!.connectionId, 'conn_primary');
      expect(refreshedCatalog.visibleModels.single.model, 'gpt-live-default');
      expect(client.listModelCalls, hasLength(1));
      expect(client.listModelCalls.single.limit, 100);
      expect(client.listModelCalls.single.includeHidden, isTrue);
      expect(
        await controller.loadConnectionModelCatalog('conn_primary'),
        refreshedCatalog,
      );
      expect(
        await controller.loadLastKnownConnectionModelCatalog(),
        refreshedCatalog,
      );

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'live lane refresh treats repeated model cursors as a failed refresh and preserves cached catalogs',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      client.listedModelPages.addAll(<CodexAppServerModelListPage>[
        const CodexAppServerModelListPage(
          models: <CodexAppServerModel>[
            CodexAppServerModel(
              id: 'preset_page_1',
              model: 'gpt-page-1',
              displayName: 'GPT Page 1',
              description: 'First paginated model.',
              hidden: false,
              supportedReasoningEfforts:
                  <CodexAppServerReasoningEffortOption>[],
              defaultReasoningEffort: CodexReasoningEffort.medium,
              inputModalities: <String>['text'],
              supportsPersonality: false,
              isDefault: true,
            ),
          ],
          nextCursor: 'repeat-cursor',
        ),
        const CodexAppServerModelListPage(
          models: <CodexAppServerModel>[
            CodexAppServerModel(
              id: 'preset_page_2',
              model: 'gpt-page-2',
              displayName: 'GPT Page 2',
              description: 'Second paginated model.',
              hidden: false,
              supportedReasoningEfforts:
                  <CodexAppServerReasoningEffortOption>[],
              defaultReasoningEffort: CodexReasoningEffort.medium,
              inputModalities: <String>['text'],
              supportsPersonality: false,
              isDefault: false,
            ),
          ],
          nextCursor: 'repeat-cursor',
        ),
      ]);
      await client.connect(
        profile: workspaceProfile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

      final staleConnectionCatalog = connectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22, 8),
        model: 'gpt-cached-connection',
        displayName: 'GPT Cached Connection',
        description: 'Connection-scoped cached catalog.',
      );
      final staleLastKnownCatalog = connectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22, 7),
        model: 'gpt-cached-last-known',
        displayName: 'GPT Cached Last Known',
        description: 'Last-known cached catalog.',
      );
      final modelCatalogStore = MemoryConnectionModelCatalogStore(
        initialLastKnownCatalog: staleLastKnownCatalog,
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
      await controller.saveConnectionModelCatalog(staleConnectionCatalog);
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

      final refreshCallback =
          settingsOverlayDelegate.launchedRefreshCallbacks.single;
      final refreshedCatalog = await refreshCallback!(
        ConnectionSettingsDraft.fromConnection(
          profile: settingsOverlayDelegate.launchedSettings.single.$1,
          secrets: settingsOverlayDelegate.launchedSettings.single.$2,
        ),
      );

      expect(client.listModelCalls, hasLength(2));
      expect(client.listModelCalls.first.cursor, isNull);
      expect(client.listModelCalls.last.cursor, 'repeat-cursor');
      expect(refreshedCatalog, isNull);
      expect(
        await controller.loadConnectionModelCatalog('conn_primary'),
        staleConnectionCatalog,
      );
      expect(
        await controller.loadLastKnownConnectionModelCatalog(),
        staleLastKnownCatalog,
      );

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'live lane refresh uses an explicit page size so healthy large catalogs are not truncated by tiny backend pages',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!
        ..listModelsDefaultPageSize = 1
        ..listedModels.addAll(
          List<CodexAppServerModel>.generate(
            101,
            (index) => backendModel(
              id: 'preset_page_${index + 1}',
              model: 'gpt-page-${index + 1}',
              displayName: 'GPT Page ${index + 1}',
              description: 'Paginated model ${index + 1}.',
              isDefault: index == 0,
            ),
          ),
        );
      await client.connect(
        profile: workspaceProfile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

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

      final refreshCallback =
          settingsOverlayDelegate.launchedRefreshCallbacks.single;
      final refreshedCatalog = await refreshCallback!(
        ConnectionSettingsDraft.fromConnection(
          profile: settingsOverlayDelegate.launchedSettings.single.$1,
          secrets: settingsOverlayDelegate.launchedSettings.single.$2,
        ),
      );

      expect(client.listModelCalls, hasLength(2));
      expect(client.listModelCalls.first.limit, 100);
      expect(client.listModelCalls.last.limit, 100);
      expect(client.listModelCalls.first.cursor, isNull);
      expect(client.listModelCalls.last.cursor, '100');
      expect(refreshedCatalog, isNotNull);
      expect(refreshedCatalog!.models, hasLength(101));
      expect(refreshedCatalog.models.first.model, 'gpt-page-1');
      expect(refreshedCatalog.models.last.model, 'gpt-page-101');
      expect(
        await controller.loadConnectionModelCatalog('conn_primary'),
        refreshedCatalog,
      );
      expect(
        await controller.loadLastKnownConnectionModelCatalog(),
        refreshedCatalog,
      );

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'live lane refresh treats model page-cap exhaustion as a failed refresh and preserves cached catalogs',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      client.listedModelPages.addAll(
        List<CodexAppServerModelListPage>.generate(
          101,
          (index) => CodexAppServerModelListPage(
            models: <CodexAppServerModel>[
              CodexAppServerModel(
                id: 'preset_page_${index + 1}',
                model: 'gpt-page-${index + 1}',
                displayName: 'GPT Page ${index + 1}',
                description: 'Paginated model ${index + 1}.',
                hidden: false,
                supportedReasoningEfforts:
                    const <CodexAppServerReasoningEffortOption>[],
                defaultReasoningEffort: CodexReasoningEffort.medium,
                inputModalities: const <String>['text'],
                supportsPersonality: false,
                isDefault: index == 0,
              ),
            ],
            nextCursor: 'cursor-${index + 1}',
          ),
        ),
      );
      await client.connect(
        profile: workspaceProfile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

      final staleConnectionCatalog = connectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22, 8),
        model: 'gpt-cached-connection',
        displayName: 'GPT Cached Connection',
        description: 'Connection-scoped cached catalog.',
      );
      final staleLastKnownCatalog = connectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22, 7),
        model: 'gpt-cached-last-known',
        displayName: 'GPT Cached Last Known',
        description: 'Last-known cached catalog.',
      );
      final modelCatalogStore = MemoryConnectionModelCatalogStore(
        initialLastKnownCatalog: staleLastKnownCatalog,
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
      await controller.saveConnectionModelCatalog(staleConnectionCatalog);
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

      final refreshCallback =
          settingsOverlayDelegate.launchedRefreshCallbacks.single;
      final refreshedCatalog = await refreshCallback!(
        ConnectionSettingsDraft.fromConnection(
          profile: settingsOverlayDelegate.launchedSettings.single.$1,
          secrets: settingsOverlayDelegate.launchedSettings.single.$2,
        ),
      );

      expect(client.listModelCalls, hasLength(100));
      expect(refreshedCatalog, isNull);
      expect(
        await controller.loadConnectionModelCatalog('conn_primary'),
        staleConnectionCatalog,
      );
      expect(
        await controller.loadLastKnownConnectionModelCatalog(),
        staleLastKnownCatalog,
      );
      expect(client.listedModelPages, hasLength(1));

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );
}
