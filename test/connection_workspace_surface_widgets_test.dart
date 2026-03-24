import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_host.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_dormant_roster_content.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_live_lane_surface.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

void main() {
  testWidgets(
    'live lane settings receive the controller-owned initial remote runtime for the selected connection',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const _FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: const _FakeRemoteOwnerInspector(
          CodexRemoteAppServerOwnerSnapshot(
            ownerId: 'conn_primary',
            workspaceDir: '/workspace',
            status: CodexRemoteAppServerOwnerStatus.running,
            sessionName: 'pocket-relay:conn_primary',
            endpoint: CodexRemoteAppServerEndpoint(
              host: '127.0.0.1',
              port: 4100,
            ),
          ),
        ),
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        _buildLiveLaneApp(
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
    'live lane settings receive explicit remote server action callbacks for saved connections',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        _buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pump();

      expect(
        settingsOverlayDelegate.launchedStartRemoteServerCallbacks.single,
        isNotNull,
      );
      expect(
        settingsOverlayDelegate.launchedStopRemoteServerCallbacks.single,
        isNotNull,
      );
      expect(
        settingsOverlayDelegate.launchedRestartRemoteServerCallbacks.single,
        isNotNull,
      );

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dormant roster add action launches settings only once while pending',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildDormantRosterApp(
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
    'dormant roster edit action enters busy state before loading saved settings',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final repository = _DelayedMemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: _profile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      )..loadConnectionGates['conn_secondary'] = Completer<void>();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        repository: repository,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildDormantRosterApp(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('edit_conn_secondary')));
      await tester.pump();

      expect(repository.loadConnectionCallsById['conn_secondary'], 1);

      repository.loadConnectionGates['conn_secondary']!.complete();
      await tester.pump();

      expect(settingsOverlayDelegate.launchCount, 1);

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dormant roster edit action launches settings with the cached model catalog',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
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
            inputModalities: const <String>['text'],
            supportsPersonality: false,
            isDefault: true,
          ),
        ],
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await controller.saveConnectionModelCatalog(cachedCatalog);
      await tester.pumpWidget(
        _buildDormantRosterApp(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
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
      expect(
        settingsOverlayDelegate.launchedStartRemoteServerCallbacks.single,
        isNotNull,
      );
      expect(
        settingsOverlayDelegate.launchedStopRemoteServerCallbacks.single,
        isNotNull,
      );
      expect(
        settingsOverlayDelegate.launchedRestartRemoteServerCallbacks.single,
        isNotNull,
      );

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dormant roster add action uses the last known model catalog when available',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
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
            inputModalities: const <String>['text'],
            supportsPersonality: false,
            isDefault: true,
          ),
        ],
      );
      final modelCatalogStore = MemoryConnectionModelCatalogStore(
        initialLastKnownCatalog: lastKnownCatalog,
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildDormantRosterApp(
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
      expect(
        settingsOverlayDelegate.launchedStartRemoteServerCallbacks.single,
        isNull,
      );
      expect(
        settingsOverlayDelegate.launchedStopRemoteServerCallbacks.single,
        isNull,
      );
      expect(
        settingsOverlayDelegate.launchedRestartRemoteServerCallbacks.single,
        isNull,
      );

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'dormant roster edit action uses the last known model catalog when the connection cache is empty',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
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
            inputModalities: const <String>['text'],
            supportsPersonality: false,
            isDefault: true,
          ),
        ],
      );
      final modelCatalogStore = MemoryConnectionModelCatalogStore(
        initialLastKnownCatalog: lastKnownCatalog,
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildDormantRosterApp(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
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
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final modelCatalogStore = MemoryConnectionModelCatalogStore();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        _buildDormantRosterApp(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
        ),
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
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await controller.instantiateConnection('conn_secondary');
      controller.showDormantRoster();

      await tester.pumpWidget(_buildDormantRosterApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Return to open lane'), findsOneWidget);

      await tester.tap(find.text('Return to open lane'));
      await tester.pumpAndSettle();

      expect(controller.state.isShowingLiveLane, isTrue);
      expect(controller.state.selectedConnectionId, 'conn_secondary');
    },
  );

  testWidgets('dormant roster uses tighter panel corners', (tester) async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(_buildDormantRosterApp(controller));
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
      final clientsById = _buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      await client.connect(
        profile: _profile('Primary Box', 'primary.local'),
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
            inputModalities: const <String>['text'],
            supportsPersonality: false,
            isDefault: true,
          ),
        ],
      );
      final modelCatalogStore = MemoryConnectionModelCatalogStore(
        initialLastKnownCatalog: lastKnownCatalog,
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        _buildLiveLaneApp(
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

  testWidgets(
    'live lane refresh callback fetches the backend catalog and saves connection and last known caches',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
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
          inputModalities: const <String>['text'],
          supportsPersonality: false,
          isDefault: true,
        ),
      );
      await client.connect(
        profile: _profile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

      final modelCatalogStore = MemoryConnectionModelCatalogStore();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        _buildLiveLaneApp(
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
      final clientsById = _buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      client.listedModelPages.addAll(<CodexAppServerModelListPage>[
        const CodexAppServerModelListPage(
          models: const <CodexAppServerModel>[
            CodexAppServerModel(
              id: 'preset_page_1',
              model: 'gpt-page-1',
              displayName: 'GPT Page 1',
              description: 'First paginated model.',
              hidden: false,
              supportedReasoningEfforts:
                  const <CodexAppServerReasoningEffortOption>[],
              defaultReasoningEffort: CodexReasoningEffort.medium,
              inputModalities: const <String>['text'],
              supportsPersonality: false,
              isDefault: true,
            ),
          ],
          nextCursor: 'repeat-cursor',
        ),
        const CodexAppServerModelListPage(
          models: const <CodexAppServerModel>[
            CodexAppServerModel(
              id: 'preset_page_2',
              model: 'gpt-page-2',
              displayName: 'GPT Page 2',
              description: 'Second paginated model.',
              hidden: false,
              supportedReasoningEfforts:
                  const <CodexAppServerReasoningEffortOption>[],
              defaultReasoningEffort: CodexReasoningEffort.medium,
              inputModalities: const <String>['text'],
              supportsPersonality: false,
              isDefault: false,
            ),
          ],
          nextCursor: 'repeat-cursor',
        ),
      ]);
      await client.connect(
        profile: _profile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

      final staleConnectionCatalog = _connectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22, 8),
        model: 'gpt-cached-connection',
        displayName: 'GPT Cached Connection',
        description: 'Connection-scoped cached catalog.',
      );
      final staleLastKnownCatalog = _connectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22, 7),
        model: 'gpt-cached-last-known',
        displayName: 'GPT Cached Last Known',
        description: 'Last-known cached catalog.',
      );
      final modelCatalogStore = MemoryConnectionModelCatalogStore(
        initialLastKnownCatalog: staleLastKnownCatalog,
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await controller.saveConnectionModelCatalog(staleConnectionCatalog);
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        _buildLiveLaneApp(
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
      final clientsById = _buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!
        ..listModelsDefaultPageSize = 1
        ..listedModels.addAll(
          List<CodexAppServerModel>.generate(
            101,
            (index) => _backendModel(
              id: 'preset_page_${index + 1}',
              model: 'gpt-page-${index + 1}',
              displayName: 'GPT Page ${index + 1}',
              description: 'Paginated model ${index + 1}.',
              isDefault: index == 0,
            ),
          ),
        );
      await client.connect(
        profile: _profile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

      final modelCatalogStore = MemoryConnectionModelCatalogStore();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        _buildLiveLaneApp(
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
      final clientsById = _buildClientsById('conn_primary');
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
        profile: _profile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

      final staleConnectionCatalog = _connectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22, 8),
        model: 'gpt-cached-connection',
        displayName: 'GPT Cached Connection',
        description: 'Connection-scoped cached catalog.',
      );
      final staleLastKnownCatalog = _connectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22, 7),
        model: 'gpt-cached-last-known',
        displayName: 'GPT Cached Last Known',
        description: 'Last-known cached catalog.',
      );
      final modelCatalogStore = MemoryConnectionModelCatalogStore(
        initialLastKnownCatalog: staleLastKnownCatalog,
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await controller.saveConnectionModelCatalog(staleConnectionCatalog);
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        _buildLiveLaneApp(
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

  testWidgets(
    'live lane ignores connection settings results after the surface unmounts',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        repository: repository,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        _buildLiveLaneApp(
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
          profile: _profile('Primary Renamed', 'primary.changed'),
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
      final clientsById = _buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      final modelCatalogStore = MemoryConnectionModelCatalogStore();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
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
            inputModalities: const <String>['text'],
            supportsPersonality: false,
            isDefault: true,
          ),
        ],
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await controller.saveConnectionModelCatalog(cachedCatalog);
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: _profile('Primary Updated', 'changed.local'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );
      final laneBinding = controller.selectedLaneBinding!;

      await tester.pumpWidget(
        _buildLiveLaneApp(
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

  testWidgets(
    'transport reconnect keeps last-known model catalog fallback available in live settings',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
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
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final laneBinding = controller.selectedLaneBinding!;
      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await clientsById['conn_primary']!.disconnect();
      await tester.pumpWidget(
        _buildLiveLaneApp(
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
      expect(settingsOverlayDelegate.launchedRefreshCallbacks.single, isNull);

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'live lane shows transport-loss and reconnecting notices during empty-lane recovery',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
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
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        _buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: _DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Live transport lost'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);

      final reconnectGate = Completer<void>();
      client.connectGate = reconnectGate;
      unawaited(controller.reconnectConnection('conn_primary'));
      await tester.pump();
      await tester.pump();

      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
      );
      expect(find.text('Reconnecting to remote session'), findsOneWidget);
      expect(find.text('Reconnecting…'), findsOneWidget);

      reconnectGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Live transport lost'), findsNothing);
      expect(find.text('Reconnecting to remote session'), findsNothing);
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
    },
  );

  testWidgets(
    'live lane shows remote-session-unavailable notice when transport reconnect fails',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
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
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        _buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: _DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.connectError = const CodexAppServerException('connect failed');
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote session unavailable'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
    },
  );

  testWidgets(
    'live lane shows remote-server-stopped notice when transport reconnect cannot attach to the managed owner',
    (tester) async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
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
      controller.selectedLaneBinding!.restoreComposerDraft('Keep me');
      await client.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await client.disconnect();

      await tester.pumpWidget(
        _buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: _DeferredConnectionSettingsOverlayDelegate(),
        ),
      );
      await tester.pumpAndSettle();

      client.connectError = const CodexRemoteAppServerAttachException(
        snapshot: CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.stopped,
          sessionName: 'pocket-relay:conn_primary',
          detail: 'Remote Pocket Relay server is not running.',
        ),
        message: 'Remote Pocket Relay server is not running.',
      );
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote server stopped'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
    },
  );
}

Widget _buildDormantRosterApp(
  ConnectionWorkspaceController controller, {
  ConnectionSettingsOverlayDelegate? settingsOverlayDelegate,
}) {
  final resolvedSettingsOverlayDelegate =
      settingsOverlayDelegate ??
      (_DeferredConnectionSettingsOverlayDelegate()..complete(null));
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: ConnectionWorkspaceDormantRosterContent(
        workspaceController: controller,
        description: 'Saved connections test surface.',
        settingsOverlayDelegate: resolvedSettingsOverlayDelegate,
        useSafeArea: false,
      ),
    ),
  );
}

Widget _buildLiveLaneApp(
  ConnectionWorkspaceController controller,
  ConnectionLaneBinding laneBinding, {
  required ConnectionSettingsOverlayDelegate settingsOverlayDelegate,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: ConnectionWorkspaceLiveLaneSurface(
        workspaceController: controller,
        laneBinding: laneBinding,
        platformPolicy: PocketPlatformPolicy.resolve(
          platform: TargetPlatform.android,
        ),
        settingsOverlayDelegate: settingsOverlayDelegate,
      ),
    ),
  );
}

Widget _buildWorkspaceDrivenLiveLaneApp(
  ConnectionWorkspaceController controller, {
  required ConnectionSettingsOverlayDelegate settingsOverlayDelegate,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final laneBinding = controller.selectedLaneBinding;
        if (laneBinding == null) {
          return const SizedBox.shrink();
        }

        return Scaffold(
          body: ConnectionWorkspaceLiveLaneSurface(
            workspaceController: controller,
            laneBinding: laneBinding,
            platformPolicy: PocketPlatformPolicy.resolve(
              platform: TargetPlatform.android,
            ),
            settingsOverlayDelegate: settingsOverlayDelegate,
          ),
        );
      },
    ),
  );
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  CodexConnectionRepository? repository,
  ConnectionModelCatalogStore? modelCatalogStore,
  CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
      const _FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
  CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
      const _ThrowingRemoteOwnerInspector(),
}) {
  final resolvedRepository =
      repository ??
      MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: _profile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
      );
  return ConnectionWorkspaceController(
    connectionRepository: resolvedRepository,
    modelCatalogStore: modelCatalogStore,
    remoteAppServerHostProbe: remoteAppServerHostProbe,
    remoteAppServerOwnerInspector: remoteAppServerOwnerInspector,
    laneBindingFactory: ({required connectionId, required connection}) {
      return ConnectionLaneBinding(
        connectionId: connectionId,
        profileStore: ConnectionScopedProfileStore(
          connectionId: connectionId,
          connectionRepository: resolvedRepository,
        ),
        appServerClient: clientsById[connectionId]!,
        initialSavedProfile: SavedProfile(
          profile: connection.profile,
          secrets: connection.secrets,
        ),
        ownsAppServerClient: false,
      );
    },
  );
}

final class _FakeRemoteHostProbe implements CodexRemoteAppServerHostProbe {
  const _FakeRemoteHostProbe(this.capabilities);

  final CodexRemoteAppServerHostCapabilities capabilities;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return capabilities;
  }
}

final class _FakeRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const _FakeRemoteOwnerInspector(this.snapshot);

  final CodexRemoteAppServerOwnerSnapshot snapshot;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshot;
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}

final class _ThrowingRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const _ThrowingRemoteOwnerInspector();

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('owner inspection should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}

ConnectionProfile _profile(String label, String host) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

ConnectionModelCatalog _connectionModelCatalog({
  required String connectionId,
  required DateTime fetchedAt,
  required String model,
  required String displayName,
  required String description,
}) {
  return ConnectionModelCatalog(
    connectionId: connectionId,
    fetchedAt: fetchedAt,
    models: <ConnectionAvailableModel>[
      ConnectionAvailableModel(
        id: 'preset_$model',
        model: model,
        displayName: displayName,
        description: description,
        hidden: false,
        supportedReasoningEfforts:
            const <ConnectionAvailableModelReasoningEffortOption>[
              ConnectionAvailableModelReasoningEffortOption(
                reasoningEffort: CodexReasoningEffort.medium,
                description: 'Balanced mode.',
              ),
            ],
        defaultReasoningEffort: CodexReasoningEffort.medium,
        inputModalities: const <String>['text'],
        supportsPersonality: false,
        isDefault: true,
      ),
    ],
  );
}

CodexAppServerModel _backendModel({
  required String id,
  required String model,
  required String displayName,
  required String description,
  bool isDefault = false,
}) {
  return CodexAppServerModel(
    id: id,
    model: model,
    displayName: displayName,
    description: description,
    hidden: false,
    supportedReasoningEfforts: const <CodexAppServerReasoningEffortOption>[],
    defaultReasoningEffort: CodexReasoningEffort.medium,
    inputModalities: const <String>['text'],
    supportsPersonality: false,
    isDefault: isDefault,
  );
}

Map<String, FakeCodexAppServerClient> _buildClientsById([
  String firstConnectionId = 'conn_primary',
  String? secondConnectionId,
]) {
  final secondaryClients = secondConnectionId == null
      ? null
      : <String, FakeCodexAppServerClient>{
          secondConnectionId: FakeCodexAppServerClient(),
        };
  return <String, FakeCodexAppServerClient>{
    firstConnectionId: FakeCodexAppServerClient(),
    ...?secondaryClients,
  };
}

Future<void> _closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}

class _DeferredConnectionSettingsOverlayDelegate
    implements ConnectionSettingsOverlayDelegate {
  int launchCount = 0;
  final List<(ConnectionProfile, ConnectionSecrets)> launchedSettings =
      <(ConnectionProfile, ConnectionSecrets)>[];
  final List<ConnectionModelCatalog?> launchedModelCatalogs =
      <ConnectionModelCatalog?>[];
  final List<ConnectionRemoteRuntimeState?> launchedInitialRemoteRuntimes =
      <ConnectionRemoteRuntimeState?>[];
  final List<ConnectionSettingsModelCatalogSource?>
  launchedModelCatalogSources = <ConnectionSettingsModelCatalogSource?>[];
  final List<
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  >
  launchedRefreshCallbacks =
      <
        Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
      >[];
  final List<ConnectionSettingsRemoteRuntimeRefresher?>
  launchedRemoteRuntimeCallbacks =
      <ConnectionSettingsRemoteRuntimeRefresher?>[];
  final List<ConnectionSettingsRemoteServerActionRunner?>
  launchedStartRemoteServerCallbacks =
      <ConnectionSettingsRemoteServerActionRunner?>[];
  final List<ConnectionSettingsRemoteServerActionRunner?>
  launchedStopRemoteServerCallbacks =
      <ConnectionSettingsRemoteServerActionRunner?>[];
  final List<ConnectionSettingsRemoteServerActionRunner?>
  launchedRestartRemoteServerCallbacks =
      <ConnectionSettingsRemoteServerActionRunner?>[];
  Completer<ConnectionSettingsSubmitPayload?> _completer =
      Completer<ConnectionSettingsSubmitPayload?>();

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
    ConnectionRemoteRuntimeState? initialRemoteRuntime,
    ConnectionModelCatalog? availableModelCatalog,
    ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
    onRefreshModelCatalog,
    ConnectionSettingsRemoteRuntimeRefresher? onRefreshRemoteRuntime,
    ConnectionSettingsRemoteServerActionRunner? onStartRemoteServer,
    ConnectionSettingsRemoteServerActionRunner? onStopRemoteServer,
    ConnectionSettingsRemoteServerActionRunner? onRestartRemoteServer,
  }) {
    launchCount += 1;
    launchedSettings.add((initialProfile, initialSecrets));
    launchedModelCatalogs.add(availableModelCatalog);
    launchedInitialRemoteRuntimes.add(initialRemoteRuntime);
    launchedModelCatalogSources.add(availableModelCatalogSource);
    launchedRefreshCallbacks.add(onRefreshModelCatalog);
    launchedRemoteRuntimeCallbacks.add(onRefreshRemoteRuntime);
    launchedStartRemoteServerCallbacks.add(onStartRemoteServer);
    launchedStopRemoteServerCallbacks.add(onStopRemoteServer);
    launchedRestartRemoteServerCallbacks.add(onRestartRemoteServer);
    return _completer.future;
  }

  void complete(ConnectionSettingsSubmitPayload? payload) {
    if (_completer.isCompleted) {
      _completer = Completer<ConnectionSettingsSubmitPayload?>();
      _completer.complete(payload);
      return;
    }
    _completer.complete(payload);
  }
}

class _DelayedMemoryCodexConnectionRepository
    extends MemoryCodexConnectionRepository {
  _DelayedMemoryCodexConnectionRepository({required super.initialConnections});

  final Map<String, int> loadConnectionCallsById = <String, int>{};
  final Map<String, Completer<void>> loadConnectionGates =
      <String, Completer<void>>{};

  @override
  Future<SavedConnection> loadConnection(String connectionId) async {
    loadConnectionCallsById[connectionId] =
        (loadConnectionCallsById[connectionId] ?? 0) + 1;
    final gate = loadConnectionGates[connectionId];
    if (gate != null) {
      await gate.future;
    }
    return super.loadConnection(connectionId);
  }
}
