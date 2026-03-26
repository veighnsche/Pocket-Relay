import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
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
import 'package:pocket_relay/src/features/workspace/presentation/workspace_saved_connections_content.dart';
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
            sessionName: 'pocket-relay-conn_primary',
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
    'live empty lane connect action starts the remote server for the selected lane',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
      final ownerControl = _RecordingRemoteOwnerControl();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const _FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: _MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': _notRunningOwnerSnapshot('conn_primary'),
          },
        ),
        remoteAppServerOwnerControl: ownerControl,
      );
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
          settingsOverlayDelegate: _DeferredConnectionSettingsOverlayDelegate()
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
      final clientsById = _buildClientsById('conn_primary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
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
          settingsOverlayDelegate: _DeferredConnectionSettingsOverlayDelegate()
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
      final profile = _profile(
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
        _buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: _DeferredConnectionSettingsOverlayDelegate(),
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
    'saved connections edit action enters busy state before loading saved settings',
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
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate =
          _DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final originalBinding = controller.bindingForConnectionId('conn_primary');

      await tester.pumpWidget(
        _buildDormantRosterApp(
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
          profile: _profile('Primary Renamed', 'primary.changed'),
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
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const _FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: _MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': _notRunningOwnerSnapshot('conn_primary'),
            'conn_secondary': _notRunningOwnerSnapshot('conn_secondary'),
          },
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(_buildDormantRosterApp(controller));
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
    'live empty lane shows a disconnected status and connect action when the remote server is running',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const _FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: _MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': _runningOwnerSnapshot('conn_primary'),
          },
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await clientsById['conn_primary']!.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final laneBinding = controller.selectedLaneBinding!;
      await tester.pumpWidget(
        _buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: _DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('lane_connection_status_strip')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('lane_connection_status_label')),
        findsNothing,
      );
      expect(find.textContaining('Disconnected.'), findsNothing);
      expect(find.text('Connect'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'live empty lane connect action keeps the placeholder clean and exposes connected-lane controls in overflow',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const _FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: _MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': _runningOwnerSnapshot('conn_primary'),
          },
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final laneBinding = controller.selectedLaneBinding!;
      await tester.pumpWidget(
        _buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: _DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
      );
      await tester.pumpAndSettle();

      expect(client.connectCalls, 1);
      expect(
        find.byKey(const ValueKey<String>('lane_connection_status_strip')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
        findsNothing,
      );
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('Conversation history'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      await controller.flushRecoveryPersistence();
    },
  );

  testWidgets(
    'live empty lane connect action can start the remote server and attach in one click',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
      final remoteOwnerRuntime = _StatefulRemoteOwnerRuntime(
        statusesByOwnerId: <String, CodexRemoteAppServerOwnerStatus>{
          'conn_primary': CodexRemoteAppServerOwnerStatus.stopped,
        },
      );
      final client = clientsById['conn_primary']!;
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const _FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: remoteOwnerRuntime,
        remoteAppServerOwnerControl: remoteOwnerRuntime,
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      final laneBinding = controller.selectedLaneBinding!;
      await tester.pumpWidget(
        _buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: _DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
      );
      await tester.pumpAndSettle();

      expect(remoteOwnerRuntime.startCalls, hasLength(1));
      expect(remoteOwnerRuntime.startCalls.single.ownerId, 'conn_primary');
      expect(client.connectCalls, 1);
      await controller.flushRecoveryPersistence();
    },
  );

  testWidgets(
    'live lane connect action surfaces a coded snackbar when transport attach fails',
    (tester) async {
      final clientsById = _buildClientsById('conn_primary');
      final client = clientsById['conn_primary']!;
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const _FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: _MapRemoteOwnerInspector(
          <String, CodexRemoteAppServerOwnerSnapshot>{
            'conn_primary': _runningOwnerSnapshot('conn_primary'),
          },
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await client.dispose();
      });

      await controller.initialize();
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
      client.connectError = const CodexAppServerException('connect failed');
      final laneBinding = controller.selectedLaneBinding!;
      await tester.pumpWidget(
        _buildLiveLaneApp(
          controller,
          laneBinding,
          settingsOverlayDelegate: _DeferredConnectionSettingsOverlayDelegate()
            ..complete(null),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey<String>('lane_connection_action_connect')),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionTransportUnavailable.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Could not connect lane'), findsOneWidget);
      expect(
        find.textContaining('Underlying error: connect failed'),
        findsOneWidget,
      );
      expect(find.textContaining('Disconnected.'), findsNothing);
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
      controller.showSavedConnections();

      await tester.pumpWidget(_buildDormantRosterApp(controller));
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
      expect(find.text('Reconnecting…'), findsNothing);
      expect(find.text('Reconnect'), findsOneWidget);

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
    'live lane shows remote-continuity-unavailable notice when the host lacks required continuity support',
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
        remoteAppServerHostProbe: const _FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(
            issues: <ConnectionRemoteHostCapabilityIssue>{
              ConnectionRemoteHostCapabilityIssue.tmuxMissing,
            },
            detail: 'tmux is not installed on this host.',
          ),
        ),
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
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
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

      expect(find.text('Remote continuity unavailable'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionReconnectContinuityUnsupported.code}]',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('tmux is not installed on this host.'),
        findsOneWidget,
      );
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
      );
    },
  );

  testWidgets(
    'live lane shows remote-continuity-unavailable notice when host capability probing fails',
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
        remoteAppServerHostProbe: const _ThrowingRemoteHostProbe(
          'ssh probe failed',
        ),
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
      await controller.refreshRemoteRuntime(connectionId: 'conn_primary');
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

      expect(find.text('Remote continuity unavailable'), findsOneWidget);
      expect(find.textContaining('ssh probe failed'), findsOneWidget);
      expect(find.text('Reconnect'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Keep me',
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
          sessionName: 'pocket-relay-conn_primary',
          detail: 'Managed remote app-server is not running.',
        ),
        message: 'Managed remote app-server is not running.',
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

  testWidgets(
    'live lane shows remote-server-unhealthy notice when transport reconnect cannot attach to an unhealthy managed owner',
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
          status: CodexRemoteAppServerOwnerStatus.unhealthy,
          sessionName: 'pocket-relay-conn_primary',
          endpoint: CodexRemoteAppServerEndpoint(host: '127.0.0.1', port: 4100),
          detail: 'readyz failed',
        ),
        message: 'readyz failed',
      );
      await controller.reconnectConnection('conn_primary');
      await tester.pumpAndSettle();

      expect(find.text('Remote server unhealthy'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionReconnectServerUnhealthy.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('readyz failed'), findsWidgets);
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
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return ConnectionWorkspaceSavedConnectionsContent(
            workspaceController: controller,
            description: 'Saved connections test surface.',
            settingsOverlayDelegate: resolvedSettingsOverlayDelegate,
            useSafeArea: false,
          );
        },
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
  CodexRemoteAppServerOwnerControl remoteAppServerOwnerControl =
      const _ThrowingRemoteOwnerControl(),
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
    remoteAppServerOwnerControl: remoteAppServerOwnerControl,
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

final class _MapRemoteOwnerInspector
    implements CodexRemoteAppServerOwnerInspector {
  const _MapRemoteOwnerInspector(this.snapshotsByOwnerId);

  final Map<String, CodexRemoteAppServerOwnerSnapshot> snapshotsByOwnerId;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return snapshotsByOwnerId[ownerId] ??
        _notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }
}

final class _ThrowingRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  const _ThrowingRemoteOwnerControl();

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return CodexRemoteAppServerOwnerSnapshot(
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      status: CodexRemoteAppServerOwnerStatus.missing,
      sessionName: 'pocket-relay-$ownerId',
      detail: 'No managed remote app-server is running for this connection.',
    );
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }
}

typedef _RemoteOwnerControlCall = ({
  ConnectionProfile profile,
  ConnectionSecrets secrets,
  String ownerId,
  String workspaceDir,
});

final class _RecordingRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  final List<_RemoteOwnerControlCall> startCalls = <_RemoteOwnerControlCall>[];
  final List<_RemoteOwnerControlCall> stopCalls = <_RemoteOwnerControlCall>[];
  final List<_RemoteOwnerControlCall> restartCalls =
      <_RemoteOwnerControlCall>[];

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return _notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    startCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    return _notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    stopCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    return _notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    restartCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    return _notRunningOwnerSnapshot(ownerId, workspaceDir: workspaceDir);
  }
}

final class _StatefulRemoteOwnerRuntime
    implements
        CodexRemoteAppServerOwnerInspector,
        CodexRemoteAppServerOwnerControl {
  _StatefulRemoteOwnerRuntime({
    Map<String, CodexRemoteAppServerOwnerStatus>? statusesByOwnerId,
  }) : _statusesByOwnerId = Map<String, CodexRemoteAppServerOwnerStatus>.from(
         statusesByOwnerId ?? const <String, CodexRemoteAppServerOwnerStatus>{},
       );

  final Map<String, CodexRemoteAppServerOwnerStatus> _statusesByOwnerId;
  final List<_RemoteOwnerControlCall> startCalls = <_RemoteOwnerControlCall>[];
  final List<_RemoteOwnerControlCall> stopCalls = <_RemoteOwnerControlCall>[];
  final List<_RemoteOwnerControlCall> restartCalls =
      <_RemoteOwnerControlCall>[];

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    startCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    _statusesByOwnerId[ownerId] = CodexRemoteAppServerOwnerStatus.running;
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    stopCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    _statusesByOwnerId[ownerId] = CodexRemoteAppServerOwnerStatus.stopped;
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    restartCalls.add((
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    ));
    _statusesByOwnerId[ownerId] = CodexRemoteAppServerOwnerStatus.running;
    return _snapshotFor(ownerId, workspaceDir: workspaceDir);
  }

  CodexRemoteAppServerOwnerSnapshot _snapshotFor(
    String ownerId, {
    required String workspaceDir,
  }) {
    return switch (_statusesByOwnerId[ownerId] ??
        CodexRemoteAppServerOwnerStatus.stopped) {
      CodexRemoteAppServerOwnerStatus.running => _runningOwnerSnapshot(
        ownerId,
        workspaceDir: workspaceDir,
      ),
      CodexRemoteAppServerOwnerStatus.unhealthy =>
        CodexRemoteAppServerOwnerSnapshot(
          ownerId: ownerId,
          workspaceDir: workspaceDir,
          status: CodexRemoteAppServerOwnerStatus.unhealthy,
          sessionName: 'pocket-relay-$ownerId',
          endpoint: const CodexRemoteAppServerEndpoint(
            host: '127.0.0.1',
            port: 4100,
          ),
          detail: 'readyz failed',
        ),
      CodexRemoteAppServerOwnerStatus.missing ||
      CodexRemoteAppServerOwnerStatus.stopped => _notRunningOwnerSnapshot(
        ownerId,
        workspaceDir: workspaceDir,
      ),
    };
  }
}

final class _ThrowingRemoteHostProbe implements CodexRemoteAppServerHostProbe {
  const _ThrowingRemoteHostProbe(this.message);

  final String message;

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    throw Exception(message);
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

CodexRemoteAppServerOwnerSnapshot _notRunningOwnerSnapshot(
  String ownerId, {
  String workspaceDir = '/workspace',
}) {
  return CodexRemoteAppServerOwnerSnapshot(
    ownerId: ownerId,
    workspaceDir: workspaceDir,
    status: CodexRemoteAppServerOwnerStatus.stopped,
    sessionName: 'pocket-relay-$ownerId',
  );
}

CodexRemoteAppServerOwnerSnapshot _runningOwnerSnapshot(
  String ownerId, {
  String workspaceDir = '/workspace',
}) {
  return CodexRemoteAppServerOwnerSnapshot(
    ownerId: ownerId,
    workspaceDir: workspaceDir,
    status: CodexRemoteAppServerOwnerStatus.running,
    sessionName: 'pocket-relay-$ownerId',
    endpoint: const CodexRemoteAppServerEndpoint(host: '127.0.0.1', port: 4100),
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
  }) {
    launchCount += 1;
    launchedSettings.add((initialProfile, initialSecrets));
    launchedModelCatalogs.add(availableModelCatalog);
    launchedInitialRemoteRuntimes.add(initialRemoteRuntime);
    launchedModelCatalogSources.add(availableModelCatalogSource);
    launchedRefreshCallbacks.add(onRefreshModelCatalog);
    launchedRemoteRuntimeCallbacks.add(onRefreshRemoteRuntime);
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
