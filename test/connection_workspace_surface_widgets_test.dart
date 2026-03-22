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
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_draft.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_dormant_roster_content.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_live_lane_surface.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';

import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

void main() {
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
            inputModalities: <String>['text'],
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
        settingsOverlayDelegate.launchedAllowReferenceModelFallbacks.single,
        isFalse,
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
        settingsOverlayDelegate.launchedAllowReferenceModelFallbacks.single,
        isFalse,
      );
      expect(settingsOverlayDelegate.launchedRefreshCallbacks.single, isNull);

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
        settingsOverlayDelegate.launchedAllowReferenceModelFallbacks.single,
        isFalse,
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
        settingsOverlayDelegate.launchedAllowReferenceModelFallbacks.single,
        isFalse,
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
        settingsOverlayDelegate.launchedAllowReferenceModelFallbacks.single,
        isFalse,
      );
      expect(
        settingsOverlayDelegate.launchedRefreshCallbacks.single,
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
          inputModalities: <String>['text'],
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
            inputModalities: <String>['text'],
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
      expect(client.listModelCalls, isEmpty);
      expect(settingsOverlayDelegate.launchedRefreshCallbacks.single, isNull);

      settingsOverlayDelegate.complete(null);
      await tester.pumpAndSettle();
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

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  CodexConnectionRepository? repository,
  ConnectionModelCatalogStore? modelCatalogStore,
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

ConnectionProfile _profile(String label, String host) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
    workspaceDir: '/workspace',
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
  final List<bool> launchedAllowReferenceModelFallbacks = <bool>[];
  final List<
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
  >
  launchedRefreshCallbacks =
      <
        Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
      >[];
  Completer<ConnectionSettingsSubmitPayload?> _completer =
      Completer<ConnectionSettingsSubmitPayload?>();

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ConnectionProfile initialProfile,
    required ConnectionSecrets initialSecrets,
    required PocketPlatformBehavior platformBehavior,
    ConnectionModelCatalog? availableModelCatalog,
    bool allowReferenceModelFallback = true,
    Future<ConnectionModelCatalog?> Function(ConnectionSettingsDraft draft)?
    onRefreshModelCatalog,
  }) {
    launchCount += 1;
    launchedSettings.add((initialProfile, initialSecrets));
    launchedModelCatalogs.add(availableModelCatalog);
    launchedAllowReferenceModelFallbacks.add(allowReferenceModelFallback);
    launchedRefreshCallbacks.add(onRefreshModelCatalog);
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
