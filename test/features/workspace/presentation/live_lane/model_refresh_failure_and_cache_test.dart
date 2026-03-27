import '../support/workspace_surface_test_support.dart';

void main() {
  testWidgets(
    'live lane refresh keeps fresh models visible and shows a typed warning when saving the connection cache fails',
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
          supportedReasoningEfforts: <CodexAppServerReasoningEffortOption>[],
          defaultReasoningEffort: CodexReasoningEffort.medium,
          inputModalities: <String>['text'],
          supportsPersonality: false,
          isDefault: true,
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
      final modelCatalogStore = ThrowingConnectionModelCatalogStore(
        initialCatalogs: <ConnectionModelCatalog>[staleConnectionCatalog],
        saveError: StateError('connection cache failed'),
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

      final refreshCallback =
          settingsOverlayDelegate.launchedRefreshCallbacks.single;
      final refreshedCatalog = await refreshCallback!(
        ConnectionSettingsDraft.fromConnection(
          profile: settingsOverlayDelegate.launchedSettings.single.$1,
          secrets: settingsOverlayDelegate.launchedSettings.single.$2,
        ),
      );
      await tester.pump();

      expect(refreshedCatalog, isNotNull);
      expect(refreshedCatalog!.visibleModels.single.model, 'gpt-live-default');
      expect(
        await controller.loadConnectionModelCatalog('conn_primary'),
        staleConnectionCatalog,
      );
      expect(
        await controller.loadLastKnownConnectionModelCatalog(),
        refreshedCatalog,
      );
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionSettingsModelCatalogConnectionCacheSaveFailed.code}]',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Underlying error: connection cache failed'),
        findsOneWidget,
      );

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'live lane refresh keeps fresh models visible and shows a typed warning when saving the last known cache fails',
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
          supportedReasoningEfforts: <CodexAppServerReasoningEffortOption>[],
          defaultReasoningEffort: CodexReasoningEffort.medium,
          inputModalities: <String>['text'],
          supportsPersonality: false,
          isDefault: true,
        ),
      );
      await client.connect(
        profile: workspaceProfile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

      final staleLastKnownCatalog = connectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22, 7),
        model: 'gpt-cached-last-known',
        displayName: 'GPT Cached Last Known',
        description: 'Last-known cached catalog.',
      );
      final modelCatalogStore = ThrowingConnectionModelCatalogStore(
        initialLastKnownCatalog: staleLastKnownCatalog,
        saveLastKnownError: StateError('last-known cache failed'),
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

      final refreshCallback =
          settingsOverlayDelegate.launchedRefreshCallbacks.single;
      final refreshedCatalog = await refreshCallback!(
        ConnectionSettingsDraft.fromConnection(
          profile: settingsOverlayDelegate.launchedSettings.single.$1,
          secrets: settingsOverlayDelegate.launchedSettings.single.$2,
        ),
      );
      await tester.pump();

      expect(refreshedCatalog, isNotNull);
      expect(refreshedCatalog!.visibleModels.single.model, 'gpt-live-default');
      expect(
        await controller.loadConnectionModelCatalog('conn_primary'),
        refreshedCatalog,
      );
      expect(
        await controller.loadLastKnownConnectionModelCatalog(),
        staleLastKnownCatalog,
      );
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionSettingsModelCatalogLastKnownCacheSaveFailed.code}]',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Underlying error: last-known cache failed'),
        findsOneWidget,
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
      await expectLater(
        refreshCallback!(
          ConnectionSettingsDraft.fromConnection(
            profile: settingsOverlayDelegate.launchedSettings.single.$1,
            secrets: settingsOverlayDelegate.launchedSettings.single.$2,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => '$error',
            'message',
            contains('exceeded 100 pages'),
          ),
        ),
      );

      expect(client.listModelCalls, hasLength(100));
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

  testWidgets(
    'live lane refresh throws a typed failure when the live backend disconnects before refresh',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
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

      await client.connect(
        profile: workspaceProfile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );
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

      await client.disconnect();

      final refreshCallback =
          settingsOverlayDelegate.launchedRefreshCallbacks.single;
      await expectLater(
        refreshCallback!(
          ConnectionSettingsDraft.fromConnection(
            profile: settingsOverlayDelegate.launchedSettings.single.$1,
            secrets: settingsOverlayDelegate.launchedSettings.single.$2,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => '$error',
            'message',
            contains('no longer available for model refresh'),
          ),
        ),
      );

      expect(client.listModelCalls, isEmpty);
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
}

final class ThrowingConnectionModelCatalogStore
    implements ConnectionModelCatalogStore {
  ThrowingConnectionModelCatalogStore({
    Iterable<ConnectionModelCatalog> initialCatalogs =
        const <ConnectionModelCatalog>[],
    ConnectionModelCatalog? initialLastKnownCatalog,
    this.saveError,
    this.saveLastKnownError,
  }) : _delegate = MemoryConnectionModelCatalogStore(
         initialCatalogs: initialCatalogs,
         initialLastKnownCatalog: initialLastKnownCatalog,
       );

  final MemoryConnectionModelCatalogStore _delegate;
  final Object? saveError;
  final Object? saveLastKnownError;

  @override
  Future<ConnectionModelCatalog?> load(String connectionId) {
    return _delegate.load(connectionId);
  }

  @override
  Future<void> save(ConnectionModelCatalog catalog) async {
    if (saveError case final error?) {
      throw error;
    }
    await _delegate.save(catalog);
  }

  @override
  Future<void> delete(String connectionId) {
    return _delegate.delete(connectionId);
  }

  @override
  Future<ConnectionModelCatalog?> loadLastKnown() {
    return _delegate.loadLastKnown();
  }

  @override
  Future<void> saveLastKnown(ConnectionModelCatalog catalog) async {
    if (saveLastKnownError case final error?) {
      throw error;
    }
    await _delegate.saveLastKnown(catalog);
  }
}
