import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_model_catalog_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'initializes an empty catalog into the dormant workspace state',
    () async {
      final controller = _buildWorkspaceController(
        clientsById: <String, FakeCodexAppServerClient>{},
        repository: MemoryCodexConnectionRepository(),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.catalog, const ConnectionCatalogState.empty());
      expect(controller.state.liveConnectionIds, isEmpty);
      expect(controller.state.dormantConnectionIds, isEmpty);
      expect(controller.state.selectedConnectionId, isNull);
      expect(
        controller.state.viewport,
        ConnectionWorkspaceViewport.dormantRoster,
      );
      expect(controller.selectedLaneBinding, isNull);
    },
  );

  test(
    'refreshRemoteRuntime stores inspected remote server state on the workspace controller',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
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
            detail: 'Remote Pocket Relay server is ready.',
          ),
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      final runtime = await controller.refreshRemoteRuntime(
        connectionId: 'conn_primary',
      );

      expect(runtime.server.status, ConnectionRemoteServerStatus.running);
      expect(runtime.server.port, 4100);
      expect(controller.state.remoteRuntimeFor('conn_primary'), runtime);
    },
  );

  test(
    'saveDormantConnection clears cached remote runtime when the connection becomes local',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: const _FakeRemoteHostProbe(
          CodexRemoteAppServerHostCapabilities(),
        ),
        remoteAppServerOwnerInspector: const _FakeRemoteOwnerInspector(
          CodexRemoteAppServerOwnerSnapshot(
            ownerId: 'conn_secondary',
            workspaceDir: '/workspace',
            status: CodexRemoteAppServerOwnerStatus.running,
            sessionName: 'pocket-relay:conn_secondary',
            endpoint: CodexRemoteAppServerEndpoint(
              host: '127.0.0.1',
              port: 4101,
            ),
          ),
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.refreshRemoteRuntime(connectionId: 'conn_secondary');
      expect(controller.state.remoteRuntimeFor('conn_secondary'), isNotNull);

      await controller.saveDormantConnection(
        connectionId: 'conn_secondary',
        profile: _profile(
          'Secondary Box',
          'secondary.local',
        ).copyWith(connectionMode: ConnectionMode.local),
        secrets: const ConnectionSecrets(password: 'secret-2'),
      );

      expect(controller.state.remoteRuntimeFor('conn_secondary'), isNull);
    },
  );

  test(
    'startRemoteServer refreshes controller runtime after an explicit start action',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final ownerControl = _MutableRemoteOwnerControl(
        snapshot: const CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.missing,
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: ownerControl,
        remoteAppServerOwnerInspector: ownerControl,
        remoteAppServerOwnerControl: ownerControl,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      final runtime = await controller.startRemoteServer(
        connectionId: 'conn_primary',
      );

      expect(ownerControl.startCalls, 1);
      expect(runtime.server.status, ConnectionRemoteServerStatus.running);
      expect(runtime.server.port, 4100);
      expect(controller.state.remoteRuntimeFor('conn_primary'), runtime);
    },
  );

  test(
    'stopRemoteServer refreshes controller runtime after an explicit stop action',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final ownerControl = _MutableRemoteOwnerControl(
        snapshot: const CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.running,
          sessionName: 'pocket-relay:conn_primary',
          endpoint: CodexRemoteAppServerEndpoint(host: '127.0.0.1', port: 4100),
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: ownerControl,
        remoteAppServerOwnerInspector: ownerControl,
        remoteAppServerOwnerControl: ownerControl,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      final runtime = await controller.stopRemoteServer(
        connectionId: 'conn_primary',
      );

      expect(ownerControl.stopCalls, 1);
      expect(runtime.server.status, ConnectionRemoteServerStatus.notRunning);
      expect(controller.state.remoteRuntimeFor('conn_primary'), runtime);
    },
  );

  test(
    'restartRemoteServer refreshes controller runtime after an explicit restart action',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final ownerControl = _MutableRemoteOwnerControl(
        snapshot: const CodexRemoteAppServerOwnerSnapshot(
          ownerId: 'conn_primary',
          workspaceDir: '/workspace',
          status: CodexRemoteAppServerOwnerStatus.running,
          sessionName: 'pocket-relay:conn_primary',
          endpoint: CodexRemoteAppServerEndpoint(host: '127.0.0.1', port: 4100),
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        remoteAppServerHostProbe: ownerControl,
        remoteAppServerOwnerInspector: ownerControl,
        remoteAppServerOwnerControl: ownerControl,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      final runtime = await controller.restartRemoteServer(
        connectionId: 'conn_primary',
      );

      expect(ownerControl.restartCalls, 1);
      expect(ownerControl.stopCalls, 1);
      expect(ownerControl.startCalls, 1);
      expect(runtime.server.status, ConnectionRemoteServerStatus.running);
      expect(runtime.server.port, 4100);
    },
  );

  test('initializes one live lane and keeps the rest dormant', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.liveConnectionIds, <String>['conn_primary']);
    expect(controller.state.dormantConnectionIds, <String>['conn_secondary']);
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
    expect(controller.selectedLaneBinding?.connectionId, 'conn_primary');
    expect(controller.bindingForConnectionId('conn_secondary'), isNull);
  });

  test(
    'saveConnectionModelCatalog and loadConnectionModelCatalog use the injected store',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final modelCatalogStore = MemoryConnectionModelCatalogStore();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      final catalog = ConnectionModelCatalog(
        connectionId: 'conn_secondary',
        fetchedAt: DateTime.utc(2026, 3, 22, 12),
        models: const <ConnectionAvailableModel>[
          ConnectionAvailableModel(
            id: 'preset_gpt_54',
            model: 'gpt-5.4',
            displayName: 'GPT-5.4',
            description: 'Latest frontier agentic coding model.',
            hidden: false,
            supportedReasoningEfforts:
                <ConnectionAvailableModelReasoningEffortOption>[
                  ConnectionAvailableModelReasoningEffortOption(
                    reasoningEffort: CodexReasoningEffort.medium,
                    description: 'Balanced default for general work.',
                  ),
                ],
            defaultReasoningEffort: CodexReasoningEffort.medium,
            inputModalities: <String>['text'],
            supportsPersonality: true,
            isDefault: true,
          ),
        ],
      );

      await controller.saveConnectionModelCatalog(catalog);

      expect(
        await controller.loadConnectionModelCatalog('conn_secondary'),
        catalog,
      );
    },
  );

  test(
    'saveLastKnownConnectionModelCatalog and loadLastKnownConnectionModelCatalog use the injected store',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final modelCatalogStore = MemoryConnectionModelCatalogStore();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      final catalog = ConnectionModelCatalog(
        connectionId: 'conn_primary',
        fetchedAt: DateTime.utc(2026, 3, 22, 12, 30),
        models: const <ConnectionAvailableModel>[
          ConnectionAvailableModel(
            id: 'preset_gpt_54',
            model: 'gpt-5.4',
            displayName: 'GPT-5.4',
            description: 'Latest frontier agentic coding model.',
            hidden: false,
            supportedReasoningEfforts:
                <ConnectionAvailableModelReasoningEffortOption>[
                  ConnectionAvailableModelReasoningEffortOption(
                    reasoningEffort: CodexReasoningEffort.medium,
                    description: 'Balanced default for general work.',
                  ),
                ],
            defaultReasoningEffort: CodexReasoningEffort.medium,
            inputModalities: <String>['text'],
            supportsPersonality: true,
            isDefault: true,
          ),
        ],
      );

      await controller.saveLastKnownConnectionModelCatalog(catalog);

      expect(await controller.loadLastKnownConnectionModelCatalog(), catalog);
    },
  );

  test(
    'initialization keeps the first live lane empty until history is explicitly picked',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          _savedConversationThread(threadId: 'thread_saved');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.selectedLaneBinding;
      expect(binding, isNotNull);

      await binding!.sessionController.initialize();

      expect(clientsById['conn_primary']?.connectCalls, 0);
      expect(clientsById['conn_primary']?.readThreadCalls, isEmpty);
      expect(binding.sessionController.transcriptBlocks, isEmpty);
      expect(binding.sessionController.sessionState.rootThreadId, isNull);
    },
  );

  test(
    'initialization restores the persisted selected lane, draft, and transcript target',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          _savedConversationThread(threadId: 'thread_saved');
      final backgroundedAt = DateTime.utc(2026, 3, 22, 12, 30);
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedAt: backgroundedAt,
          backgroundedLifecycleState:
              ConnectionWorkspaceBackgroundLifecycleState.paused,
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();

      final binding = controller.selectedLaneBinding;
      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(binding, isNotNull);
      expect(binding!.composerDraftHost.draft.text, 'Restore my draft');
      expect(
        binding.sessionController.sessionState.rootThreadId,
        'thread_saved',
      );
      expect(
        binding.sessionController.transcriptBlocks
            .whereType<CodexTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(clientsById['conn_secondary']!.readThreadCalls, <String>[
        'thread_saved',
      ]);
      expect(clientsById['conn_secondary']!.connectCalls, 1);
      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        isNull,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_secondary'),
        ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
      );
      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(diagnostics, isNotNull);
      expect(diagnostics!.lastBackgroundedAt, backgroundedAt);
      expect(
        diagnostics.lastBackgroundedLifecycleState,
        ConnectionWorkspaceBackgroundLifecycleState.paused,
      );
      expect(
        diagnostics.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.coldStart,
      );
      expect(
        diagnostics.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.conversationRestored,
      );
    },
  );

  test(
    'initialization marks the restored lane reconnecting while cold-start transport bootstrap is in flight',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          _savedConversationThread(threadId: 'thread_saved');
      clientsById['conn_secondary']!.connectGate = Completer<void>();
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedLifecycleState:
              ConnectionWorkspaceBackgroundLifecycleState.paused,
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      final initialization = controller.initialize();
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isTrue,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
      );
      expect(
        controller.selectedLaneBinding?.composerDraftHost.draft.text,
        'Restore my draft',
      );
      final reconnectingDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(reconnectingDiagnostics, isNotNull);
      expect(
        reconnectingDiagnostics!.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.coldStart,
      );
      expect(reconnectingDiagnostics.lastRecoveryStartedAt, isNotNull);
      expect(reconnectingDiagnostics.lastRecoveryCompletedAt, isNull);
      expect(reconnectingDiagnostics.lastRecoveryOutcome, isNull);

      clientsById['conn_secondary']!.connectGate!.complete();
      await initialization;

      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        isNull,
      );
      expect(
        controller
            .selectedLaneBinding
            ?.sessionController
            .sessionState
            .rootThreadId,
        'thread_saved',
      );
      final restoredDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(restoredDiagnostics, isNotNull);
      expect(
        restoredDiagnostics!.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.conversationRestored,
      );
      expect(restoredDiagnostics.lastRecoveryCompletedAt, isNotNull);
    },
  );

  test(
    'initialization keeps the restored lane visible and marks remote session unavailable when cold-start transport bootstrap fails',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.connectError =
          const CodexAppServerException('connect failed');
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedLifecycleState:
              ConnectionWorkspaceBackgroundLifecycleState.paused,
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();

      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(controller.selectedLaneBinding, isNotNull);
      expect(
        controller.selectedLaneBinding!.composerDraftHost.draft.text,
        'Restore my draft',
      );
      expect(
        controller.state.requiresTransportReconnect('conn_secondary'),
        isTrue,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_secondary'),
        ConnectionWorkspaceLiveReattachPhase.reconnecting,
      );
      final unavailableDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(unavailableDiagnostics, isNotNull);
      expect(
        unavailableDiagnostics!.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.coldStart,
      );
      expect(
        unavailableDiagnostics.lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.connectFailed,
      );
      expect(
        unavailableDiagnostics.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
      );
      expect(
        controller
            .selectedLaneBinding!
            .sessionController
            .sessionState
            .rootThreadId,
        isNull,
      );
      expect(clientsById['conn_secondary']!.readThreadCalls, isEmpty);
    },
  );

  test(
    'initialization stores remote stopped runtime when cold-start transport bootstrap cannot attach to the managed owner',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.connectError =
          const CodexRemoteAppServerAttachException(
            snapshot: CodexRemoteAppServerOwnerSnapshot(
              ownerId: 'conn_secondary',
              workspaceDir: '/workspace',
              status: CodexRemoteAppServerOwnerStatus.stopped,
              sessionName: 'pocket-relay:conn_secondary',
              detail: 'Remote Pocket Relay server is not running.',
            ),
            message: 'Remote Pocket Relay server is not running.',
          );
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedLifecycleState:
              ConnectionWorkspaceBackgroundLifecycleState.paused,
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();

      final remoteRuntime = controller.state.remoteRuntimeFor('conn_secondary');
      expect(remoteRuntime, isNotNull);
      expect(
        remoteRuntime!.server.status,
        ConnectionRemoteServerStatus.notRunning,
      );
      expect(
        remoteRuntime.server.detail,
        'Remote Pocket Relay server is not running.',
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_secondary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_secondary'),
        ConnectionWorkspaceLiveReattachPhase.ownerMissing,
      );
    },
  );

  test(
    'initialization restores the persisted selected lane, draft, and transcript target from secure recovery storage',
    () async {
      final originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(() {
        SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
        SharedPreferences.setMockInitialValues(<String, Object>{});
      });

      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          _savedConversationThread(threadId: 'thread_saved');
      final secureStorage = _FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final recoveryStore = SecureConnectionWorkspaceRecoveryStore(
        secureStorage: secureStorage,
        preferences: preferences,
      );
      await recoveryStore.save(
        const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();

      final binding = controller.selectedLaneBinding;
      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(binding, isNotNull);
      expect(binding!.composerDraftHost.draft.text, 'Restore my draft');
      expect(
        binding.sessionController.sessionState.rootThreadId,
        'thread_saved',
      );
      expect(
        binding.sessionController.transcriptBlocks
            .whereType<CodexTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(clientsById['conn_secondary']!.readThreadCalls, <String>[
        'thread_saved',
      ]);
      expect(
        await preferences.getString('pocket_relay.workspace.recovery_state'),
        isNot(contains('Restore my draft')),
      );
      expect(
        secureStorage
            .data['pocket_relay.workspace.recovery_state.draft_text.conn_secondary'],
        'Restore my draft',
      );
    },
  );

  test(
    'instantiating a dormant connection keeps the lane empty until history is explicitly picked',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          _savedConversationThread(threadId: 'thread_saved');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      await controller.instantiateConnection('conn_secondary');

      expect(controller.state.liveConnectionIds, <String>[
        'conn_primary',
        'conn_secondary',
      ]);
      expect(controller.state.dormantConnectionIds, isEmpty);
      expect(controller.state.selectedConnectionId, 'conn_secondary');
      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(
        controller.bindingForConnectionId('conn_primary'),
        same(firstBinding),
      );
      expect(controller.bindingForConnectionId('conn_secondary'), isNotNull);
      await controller
          .bindingForConnectionId('conn_secondary')!
          .sessionController
          .initialize();
      expect(clientsById['conn_secondary']?.readThreadCalls, isEmpty);
      expect(
        controller
            .bindingForConnectionId('conn_secondary')
            ?.sessionController
            .transcriptBlocks,
        isEmpty,
      );
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );

  test('terminating one live lane leaves the others intact', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await controller.instantiateConnection('conn_secondary');

    controller.terminateConnection('conn_secondary');

    expect(controller.state.liveConnectionIds, <String>['conn_primary']);
    expect(controller.state.dormantConnectionIds, <String>['conn_secondary']);
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
    expect(controller.bindingForConnectionId('conn_secondary'), isNull);
    expect(clientsById['conn_secondary']?.disconnectCalls, 1);
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  test(
    'terminating the last live lane shows the dormant roster and clears selection',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();

      controller.terminateConnection('conn_primary');

      expect(controller.state.liveConnectionIds, isEmpty);
      expect(controller.state.dormantConnectionIds, <String>[
        'conn_primary',
        'conn_secondary',
      ]);
      expect(controller.state.selectedConnectionId, isNull);
      expect(
        controller.state.viewport,
        ConnectionWorkspaceViewport.dormantRoster,
      );
      expect(controller.selectedLaneBinding, isNull);
      expect(clientsById['conn_primary']?.disconnectCalls, 1);
      expect(clientsById['conn_secondary']?.disconnectCalls, 0);
    },
  );

  test('showDormantRoster preserves the selected live lane', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();

    controller.showDormantRoster();

    expect(
      controller.state.viewport,
      ConnectionWorkspaceViewport.dormantRoster,
    );
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(controller.selectedLaneBinding?.connectionId, 'conn_primary');
  });

  test(
    'instantiating from the dormant roster returns the workspace to a live lane',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      controller.showDormantRoster();

      await controller.instantiateConnection('conn_secondary');

      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(controller.state.selectedConnectionId, 'conn_secondary');
    },
  );

  test(
    'selecting the current live connection exits dormant-roster mode',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      controller.showDormantRoster();

      controller.selectConnection('conn_primary');

      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(controller.state.selectedConnectionId, 'conn_primary');
    },
  );

  test('createConnection appends a new dormant saved connection', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final repository = MemoryCodexConnectionRepository(
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
      connectionIdGenerator: () => 'conn_created',
    );
    final controller = _buildWorkspaceController(
      clientsById: clientsById,
      repository: repository,
    );
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();

    final createdConnectionId = await controller.createConnection(
      profile: _profile('Third Box', 'third.local'),
      secrets: const ConnectionSecrets(password: 'secret-3'),
    );

    expect(createdConnectionId, 'conn_created');
    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
      'conn_created',
    ]);
    expect(controller.state.liveConnectionIds, <String>['conn_primary']);
    expect(controller.state.dormantConnectionIds, <String>[
      'conn_secondary',
      'conn_created',
    ]);
    expect(controller.bindingForConnectionId('conn_created'), isNull);
  });

  test(
    'saveDormantConnection updates the saved definition immediately',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();

      await controller.saveDormantConnection(
        connectionId: 'conn_secondary',
        profile: _profile('Secondary Renamed', 'secondary.changed'),
        secrets: const ConnectionSecrets(password: 'new-secret'),
      );

      final updatedConnection = controller.state.catalog.connectionForId(
        'conn_secondary',
      );
      expect(updatedConnection?.profile.label, 'Secondary Renamed');
      expect(updatedConnection?.profile.host, 'secondary.changed');
      expect(controller.bindingForConnectionId('conn_secondary'), isNull);
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
      expect(clientsById['conn_secondary']?.disconnectCalls, 0);
    },
  );

  test(
    'saveLiveConnectionEdits stages reconnect-required state without disconnecting the lane',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: _profile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );

      expect(controller.state.requiresReconnect('conn_primary'), isTrue);
      expect(
        controller.state.requiresSavedSettingsReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
      expect(controller.state.reconnectRequiredConnectionIds, <String>{
        'conn_primary',
      });
      expect(
        controller.state.catalog.connectionForId('conn_primary')?.profile.host,
        'primary.changed',
      );
      expect(
        controller.bindingForConnectionId('conn_primary'),
        same(firstBinding),
      );
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
      expect(clientsById['conn_secondary']?.disconnectCalls, 0);
    },
  );

  test(
    'saveLiveConnectionEdits clears reconnect-required state when the saved definition matches the running lane again',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: _profile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: _profile('Primary Box', 'primary.local'),
        secrets: const ConnectionSecrets(password: 'secret-1'),
      );

      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(controller.state.reconnectRequiredConnectionIds, isEmpty);
      expect(
        controller.state.catalog.connectionForId('conn_primary')?.profile.host,
        'primary.local',
      );
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );

  test(
    'unexpected transport disconnect stages transport reconnect without replacing the live lane',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);

      clientsById['conn_primary']!.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.bindingForConnectionId('conn_primary'), same(binding));
      expect(controller.state.requiresReconnect('conn_primary'), isTrue);
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.requiresSavedSettingsReconnect('conn_primary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.lost,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.transportLost,
      );
      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(diagnostics, isNotNull);
      expect(
        diagnostics!.lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.appServerExitError,
      );
      expect(diagnostics.lastTransportLossAt, isNotNull);
      expect(controller.state.reconnectRequiredConnectionIds, <String>{
        'conn_primary',
      });
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );

  test(
    'unexpected graceful app-server exit records a distinct transport loss reason',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);

      clientsById['conn_primary']!.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 0),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_primary')!
            .lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.appServerExitGraceful,
      );
    },
  );

  test(
    'cold-start connect failures keep specific SSH loss reasons instead of downgrading to generic connect failure',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!
        ..connectEventsBeforeThrow.add(
          const CodexAppServerSshConnectFailedEvent(
            host: 'secondary.local',
            port: 22,
            message: 'No route to host',
          ),
        )
        ..connectError = const CodexAppServerException('connect failed');
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_secondary',
          selectedThreadId: 'thread_saved',
          draftText: 'Restore my draft',
          backgroundedLifecycleState:
              ConnectionWorkspaceBackgroundLifecycleState.paused,
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();

      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_secondary',
      );
      expect(diagnostics, isNotNull);
      expect(
        diagnostics!.lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.sshConnectFailed,
      );
      expect(
        diagnostics.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
      );
    },
  );

  test(
    'transport reconnect state clears when the live lane reconnects through the existing binding',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);

      clientsById['conn_primary']!.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.lost,
      );

      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        isNull,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_primary')!
            .lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportRestored,
      );
      expect(clientsById['conn_primary']?.connectCalls, 2);
      expect(controller.bindingForConnectionId('conn_primary'), same(binding));
    },
  );

  test(
    'reconnectConnection on a transport-loss lane reconnects through the existing binding before clearing transport recovery state',
    () async {
      final repository = MemoryCodexConnectionRepository(
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
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient();
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');
      await clientsByConnectionId['conn_primary']!.first.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await Future<void>.delayed(Duration.zero);
      await clientsByConnectionId['conn_primary']!.first.disconnect();
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.lost,
      );

      await controller.reconnectConnection('conn_primary');

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, same(firstBinding));
      expect(clientsByConnectionId['conn_primary'], hasLength(1));
      expect(clientsByConnectionId['conn_primary']!.first.connectCalls, 2);
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        isNull,
      );
    },
  );

  test(
    'reconnectConnection replaces the targeted live binding and clears reconnect-required state',
    () async {
      final repository = MemoryCodexConnectionRepository(
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
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient();
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: _profile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );
      await controller.reconnectConnection('conn_primary');

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, isNot(same(firstBinding)));
      expect(nextBinding?.sessionController.profile.host, 'primary.changed');
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 1);
      expect(clientsByConnectionId['conn_primary']!.last.disconnectCalls, 0);
    },
  );

  test(
    'reconnectConnection preserves an explicitly resumed transcript selection on the recreated lane',
    () async {
      final repository = MemoryCodexConnectionRepository(
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
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient()
            ..threadHistoriesById['thread_saved'] = _savedConversationThread(
              threadId: 'thread_saved',
            );
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      await controller.resumeConversation(
        connectionId: 'conn_primary',
        threadId: 'thread_saved',
      );
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: _profile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );

      await controller.reconnectConnection('conn_primary');

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(clientsByConnectionId['conn_primary'], hasLength(3));
      expect(
        clientsByConnectionId['conn_primary']!.last.readThreadCalls,
        <String>['thread_saved'],
      );
      expect(
        nextBinding!.sessionController.transcriptBlocks
            .whereType<CodexTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(
        nextBinding.sessionController.sessionState.rootThreadId,
        'thread_saved',
      );
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
    },
  );

  test(
    'reconnectConnection preserves the composer draft on the recreated lane',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Keep this draft');

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: _profile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );
      await controller.reconnectConnection('conn_primary');

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, isNot(same(firstBinding)));
      expect(nextBinding!.composerDraftHost.draft.text, 'Keep this draft');
    },
  );

  test(
    'resuming after background preserves the selected lane and draft without forcing reconnect',
    () async {
      final repository = MemoryCodexConnectionRepository(
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
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        recoveryStore: MemoryConnectionWorkspaceRecoveryStore(),
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient();
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      await controller.instantiateConnection('conn_secondary');
      controller.selectConnection('conn_primary');
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Draft survives');

      await controller.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, same(firstBinding));
      expect(nextBinding!.composerDraftHost.draft.text, 'Draft survives');
      expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 0);
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(controller.state.requiresReconnect('conn_secondary'), isFalse);
    },
  );

  test(
    'resumed auto-reconnects the selected lane after confirmed transport loss',
    () async {
      final repository = MemoryCodexConnectionRepository(
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
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient()
            ..threadHistoriesById['thread_123'] = _savedConversationThread(
              threadId: 'thread_123',
            );
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Recover me');
      await _startBusyTurn(
        firstBinding,
        clientsByConnectionId['conn_primary']!.first,
      );

      await controller.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clientsByConnectionId['conn_primary']!.first.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.lost,
      );

      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, same(firstBinding));
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        isNull,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.liveReattached,
      );
      final resumedDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(resumedDiagnostics, isNotNull);
      expect(
        resumedDiagnostics!.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.foregroundResume,
      );
      expect(
        resumedDiagnostics.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportRestored,
      );
      expect(clientsByConnectionId['conn_primary'], hasLength(1));
      expect(clientsByConnectionId['conn_primary']!.first.connectCalls, 1);
      expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 0);
      expect(
        clientsByConnectionId['conn_primary']!.first.readThreadCalls,
        <String>['thread_123'],
      );
      expect(nextBinding!.composerDraftHost.draft.text, 'Recover me');
      expect(
        nextBinding.sessionController.sessionState.rootThreadId,
        'thread_123',
      );
    },
  );

  test(
    'resumed auto-reconnect keeps the lane visible and marks remote session unavailable when transport reconnect fails',
    () async {
      final repository = MemoryCodexConnectionRepository(
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
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient()
            ..connectError =
                clientsByConnectionId[connectionId]!.isEmpty &&
                    connectionId == 'conn_primary'
                ? null
                : const CodexAppServerException('connect failed');
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Recover me');
      await _startBusyTurn(
        firstBinding,
        clientsByConnectionId['conn_primary']!.first,
      );
      clientsByConnectionId['conn_primary']!.first.connectError =
          const CodexAppServerException('connect failed');

      await controller.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clientsByConnectionId['conn_primary']!.first.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 1),
      );
      await Future<void>.delayed(Duration.zero);

      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, same(firstBinding));
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      final unavailableDiagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(unavailableDiagnostics, isNotNull);
      expect(
        unavailableDiagnostics!.lastRecoveryOrigin,
        ConnectionWorkspaceRecoveryOrigin.foregroundResume,
      );
      expect(
        unavailableDiagnostics.lastTransportLossReason,
        ConnectionWorkspaceTransportLossReason.connectFailed,
      );
      expect(
        unavailableDiagnostics.lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
      );
      expect(nextBinding!.composerDraftHost.draft.text, 'Recover me');
      expect(clientsByConnectionId['conn_primary'], hasLength(1));
      expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 0);
      expect(
        clientsByConnectionId['conn_primary']!.first.readThreadCalls,
        <String>['thread_123'],
      );
    },
  );

  test(
    'resumed auto-reconnect stores remote unhealthy runtime when attach to the managed owner fails',
    () async {
      final repository = MemoryCodexConnectionRepository(
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
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient()
            ..connectError =
                clientsByConnectionId[connectionId]!.isEmpty &&
                    connectionId == 'conn_primary'
                ? null
                : const CodexRemoteAppServerAttachException(
                    snapshot: CodexRemoteAppServerOwnerSnapshot(
                      ownerId: 'conn_primary',
                      workspaceDir: '/workspace',
                      status: CodexRemoteAppServerOwnerStatus.unhealthy,
                      sessionName: 'pocket-relay:conn_primary',
                      endpoint: CodexRemoteAppServerEndpoint(
                        host: '127.0.0.1',
                        port: 4100,
                      ),
                      detail: 'readyz failed',
                    ),
                    message: 'readyz failed',
                  );
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Recover me');
      await _startBusyTurn(
        firstBinding,
        clientsByConnectionId['conn_primary']!.first,
      );
      clientsByConnectionId['conn_primary']!.first.connectError =
          const CodexRemoteAppServerAttachException(
            snapshot: CodexRemoteAppServerOwnerSnapshot(
              ownerId: 'conn_primary',
              workspaceDir: '/workspace',
              status: CodexRemoteAppServerOwnerStatus.unhealthy,
              sessionName: 'pocket-relay:conn_primary',
              endpoint: CodexRemoteAppServerEndpoint(
                host: '127.0.0.1',
                port: 4100,
              ),
              detail: 'readyz failed',
            ),
            message: 'readyz failed',
          );

      await controller.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clientsByConnectionId['conn_primary']!.first.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 1),
      );
      await Future<void>.delayed(Duration.zero);

      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      final remoteRuntime = controller.state.remoteRuntimeFor('conn_primary');
      expect(remoteRuntime, isNotNull);
      expect(
        remoteRuntime!.server.status,
        ConnectionRemoteServerStatus.unhealthy,
      );
      expect(remoteRuntime.server.detail, 'readyz failed');
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy,
      );
      expect(
        controller.state.recoveryDiagnosticsFor('conn_primary')!
            .lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
      );
      expect(
        controller.bindingForConnectionId('conn_primary'),
        same(firstBinding),
      );
    },
  );

  test(
    'resumed does not auto-reconnect when only saved settings are pending',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: _profile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );

      await controller.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      expect(
        controller.bindingForConnectionId('conn_primary'),
        same(firstBinding),
      );
      expect(controller.state.requiresReconnect('conn_primary'), isTrue);
      expect(
        controller.state.requiresSavedSettingsReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
      expect(clientsById['conn_primary']?.disconnectCalls, 0);
    },
  );

  test(
    'resumed auto-reconnects lanes that need transport recovery even when saved settings are also pending',
    () async {
      final repository = MemoryCodexConnectionRepository(
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
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient()
            ..threadHistoriesById['thread_123'] = _savedConversationThread(
              threadId: 'thread_123',
            );
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Recover edited lane');
      await _startBusyTurn(
        firstBinding,
        clientsByConnectionId['conn_primary']!.first,
      );

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: _profile('Primary Renamed', 'primary.changed'),
        secrets: const ConnectionSecrets(password: 'updated-secret'),
      );

      await controller.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      clientsByConnectionId['conn_primary']!.first.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.reconnectRequirementFor('conn_primary'),
        ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings,
      );

      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, isNot(same(firstBinding)));
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(
        controller.state.requiresSavedSettingsReconnect('conn_primary'),
        isFalse,
      );
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isFalse,
      );
      expect(clientsByConnectionId['conn_primary'], hasLength(2));
      expect(nextBinding!.composerDraftHost.draft.text, 'Recover edited lane');
      expect(
        nextBinding.sessionController.sessionState.rootThreadId,
        'thread_123',
      );
      expect(nextBinding.sessionController.profile.host, 'primary.changed');
      expect(
        nextBinding.sessionController.secrets,
        const ConnectionSecrets(password: 'updated-secret'),
      );
    },
  );

  test(
    'inactive without pause snapshots recovery state but does not reconnect the selected lane',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore();
      final snapshotTime = DateTime(2026, 3, 22, 14, 5);
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        now: () => snapshotTime,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Keep me');

      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.inactive,
      );
      final backgroundedRecoveryState = await recoveryStore.load();
      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      final recoveryState = await recoveryStore.load();
      expect(nextBinding, same(firstBinding));
      expect(clientsById['conn_primary']!.disconnectCalls, 0);
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(backgroundedRecoveryState, isNotNull);
      expect(backgroundedRecoveryState!.draftText, 'Keep me');
      expect(backgroundedRecoveryState.backgroundedAt, snapshotTime);
      expect(
        backgroundedRecoveryState.backgroundedLifecycleState,
        ConnectionWorkspaceBackgroundLifecycleState.inactive,
      );
      expect(recoveryState, isNotNull);
      expect(recoveryState!.backgroundedAt, isNull);
      expect(recoveryState.backgroundedLifecycleState, isNull);
      final diagnostics = controller.state.recoveryDiagnosticsFor(
        'conn_primary',
      );
      expect(diagnostics, isNotNull);
      expect(diagnostics!.lastResumedAt, snapshotTime);
      expect(diagnostics.lastBackgroundedAt, isNull);
    },
  );

  test(
    'selected lane draft bursts debounce into one persisted recovery snapshot',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final recoveryStore = _RecordingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: '',
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: Duration.zero,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      recoveryStore.savedStates.clear();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      binding.restoreComposerDraft('D');
      binding.restoreComposerDraft('Dr');
      binding.restoreComposerDraft('Draft');
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.savedStates, hasLength(1));
      expect(recoveryStore.savedStates.single?.draftText, 'Draft');
      expect(recoveryStore.savedStates.single?.connectionId, 'conn_primary');
    },
  );

  test('dispose flushes a pending debounced recovery snapshot', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final recoveryStore = _RecordingConnectionWorkspaceRecoveryStore(
      initialState: const ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_primary',
        draftText: '',
      ),
    );
    final controller = _buildWorkspaceController(
      clientsById: clientsById,
      recoveryStore: recoveryStore,
      recoveryPersistenceDebounceDuration: const Duration(minutes: 5),
    );
    addTearDown(() async {
      await _closeClients(clientsById);
    });

    await controller.initialize();
    recoveryStore.savedStates.clear();
    final binding = controller.bindingForConnectionId('conn_primary')!;

    binding.restoreComposerDraft('Pending draft');
    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(recoveryStore.savedStates, isNotEmpty);
    expect(recoveryStore.savedStates.last?.connectionId, 'conn_primary');
    expect(recoveryStore.savedStates.last?.draftText, 'Pending draft');
  });

  test(
    'selected lane thread changes persist immediately without waiting for debounce',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          _savedConversationThread(threadId: 'thread_saved');
      final recoveryStore = _RecordingConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          draftText: '',
        ),
      );
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
        recoveryPersistenceDebounceDuration: const Duration(minutes: 5),
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      recoveryStore.savedStates.clear();
      final binding = controller.bindingForConnectionId('conn_primary')!;

      await binding.sessionController.selectConversationForResume(
        'thread_saved',
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));

      expect(recoveryStore.savedStates, isNotEmpty);
      expect(recoveryStore.savedStates.last?.connectionId, 'conn_primary');
      expect(recoveryStore.savedStates.last?.selectedThreadId, 'thread_saved');
    },
  );

  test('non-selected lane changes do not persist recovery snapshots', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final recoveryStore = _RecordingConnectionWorkspaceRecoveryStore(
      initialState: const ConnectionWorkspaceRecoveryState(
        connectionId: 'conn_primary',
        draftText: '',
      ),
    );
    final controller = _buildWorkspaceController(
      clientsById: clientsById,
      recoveryStore: recoveryStore,
      recoveryPersistenceDebounceDuration: Duration.zero,
    );
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await controller.instantiateConnection('conn_secondary');
    controller.selectConnection('conn_primary');
    recoveryStore.savedStates.clear();

    controller
        .bindingForConnectionId('conn_secondary')!
        .restoreComposerDraft('Ignored draft');
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(recoveryStore.savedStates, isEmpty);
    expect(await recoveryStore.load(), recoveryStore.initialState);
  });

  test('terminateConnection refuses to close a busy live lane', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await _startBusyTurn(
      controller.bindingForConnectionId('conn_primary')!,
      clientsById['conn_primary']!,
    );

    controller.terminateConnection('conn_primary');

    expect(controller.state.liveConnectionIds, contains('conn_primary'));
    expect(controller.bindingForConnectionId('conn_primary'), isNotNull);
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  test('resumeConversation refuses to replace a busy live lane', () async {
    final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
      'conn_primary': <FakeCodexAppServerClient>[],
      'conn_secondary': <FakeCodexAppServerClient>[],
    };
    final repository = MemoryCodexConnectionRepository(
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
    final controller = ConnectionWorkspaceController(
      connectionRepository: repository,
      laneBindingFactory: ({required connectionId, required connection}) {
        final appServerClient = FakeCodexAppServerClient();
        appServerClient.threadsById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
        clientsByConnectionId[connectionId]!.add(appServerClient);
        return ConnectionLaneBinding(
          connectionId: connectionId,
          profileStore: ConnectionScopedProfileStore(
            connectionId: connectionId,
            connectionRepository: repository,
          ),
          appServerClient: appServerClient,
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
      await _closeClientLists(clientsByConnectionId);
    });

    await controller.initialize();
    final firstBinding = controller.bindingForConnectionId('conn_primary')!;
    await _startBusyTurn(
      firstBinding,
      clientsByConnectionId['conn_primary']!.first,
    );

    await controller.resumeConversation(
      connectionId: 'conn_primary',
      threadId: 'thread_saved',
    );

    expect(
      controller.bindingForConnectionId('conn_primary'),
      same(firstBinding),
    );
    expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 0);
    expect(clientsByConnectionId['conn_primary']!, hasLength(1));
  });

  test('reconnectConnection refuses to replace a busy live lane', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final controller = _buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    final firstBinding = controller.bindingForConnectionId('conn_primary')!;
    await _startBusyTurn(firstBinding, clientsById['conn_primary']!);
    await controller.saveLiveConnectionEdits(
      connectionId: 'conn_primary',
      profile: _profile('Primary Renamed', 'primary.changed'),
      secrets: const ConnectionSecrets(password: 'updated-secret'),
    );

    await controller.reconnectConnection('conn_primary');

    expect(
      controller.bindingForConnectionId('conn_primary'),
      same(firstBinding),
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
    expect(controller.state.requiresReconnect('conn_primary'), isTrue);
  });

  test('deleteDormantConnection removes the saved definition', () async {
    final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
    final modelCatalogStore = MemoryConnectionModelCatalogStore(
      initialCatalogs: <ConnectionModelCatalog>[
        ConnectionModelCatalog(
          connectionId: 'conn_secondary',
          fetchedAt: DateTime.utc(2026, 3, 22, 12),
          models: const <ConnectionAvailableModel>[
            ConnectionAvailableModel(
              id: 'preset_gpt_54',
              model: 'gpt-5.4',
              displayName: 'GPT-5.4',
              description: 'Latest frontier agentic coding model.',
              hidden: false,
              supportedReasoningEfforts:
                  <ConnectionAvailableModelReasoningEffortOption>[
                    ConnectionAvailableModelReasoningEffortOption(
                      reasoningEffort: CodexReasoningEffort.medium,
                      description: 'Balanced default for general work.',
                    ),
                  ],
              defaultReasoningEffort: CodexReasoningEffort.medium,
              inputModalities: <String>['text'],
              supportsPersonality: true,
              isDefault: true,
            ),
          ],
        ),
      ],
    );
    final controller = _buildWorkspaceController(
      clientsById: clientsById,
      modelCatalogStore: modelCatalogStore,
    );
    addTearDown(() async {
      controller.dispose();
      await _closeClients(clientsById);
    });

    await controller.initialize();
    await controller.deleteDormantConnection('conn_secondary');

    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
    ]);
    expect(controller.state.dormantConnectionIds, isEmpty);
    expect(await modelCatalogStore.load('conn_secondary'), isNull);
  });

  test(
    'resumeConversation replaces the live binding and restores the selected transcript',
    () async {
      final repository = MemoryCodexConnectionRepository(
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
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient();
          appServerClient.threadsById['thread_resumed'] =
              _savedConversationThread(threadId: 'thread_resumed');
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      await controller.resumeConversation(
        connectionId: 'conn_primary',
        threadId: 'thread_resumed',
      );

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, isNot(same(firstBinding)));
      expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 1);
      expect(clientsByConnectionId['conn_primary']!.last.disconnectCalls, 0);
      expect(
        clientsByConnectionId['conn_primary']!.last.readThreadCalls,
        <String>['thread_resumed'],
      );
      expect(clientsByConnectionId['conn_primary']!.last.startSessionCalls, 0);
      expect(
        nextBinding!.sessionController.transcriptBlocks
            .whereType<CodexTextBlock>()
            .single
            .body,
        'Restored answer',
      );
      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(controller.state.liveReattachPhaseFor('conn_primary'), isNull);
    },
  );

  test(
    'resumeConversation preserves transport reconnect state when the recreated lane cannot reconnect',
    () async {
      final repository = MemoryCodexConnectionRepository(
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
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
        'conn_secondary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient()
            ..connectError =
                clientsByConnectionId[connectionId]!.isEmpty &&
                    connectionId == 'conn_primary'
                ? null
                : const CodexAppServerException('connect failed');
          appServerClient.threadsById['thread_resumed'] =
              _savedConversationThread(threadId: 'thread_resumed');
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      await clientsByConnectionId['conn_primary']!.first.connect(
        profile: firstBinding.sessionController.profile,
        secrets: firstBinding.sessionController.secrets,
      );
      await Future<void>.delayed(Duration.zero);

      clientsByConnectionId['conn_primary']!.first.emit(
        const CodexAppServerDisconnectedEvent(exitCode: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );

      await controller.resumeConversation(
        connectionId: 'conn_primary',
        threadId: 'thread_resumed',
      );

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, isNot(same(firstBinding)));
      expect(
        controller.state.requiresTransportReconnect('conn_primary'),
        isTrue,
      );
      expect(
        controller.state.reconnectRequirementFor('conn_primary'),
        ConnectionWorkspaceReconnectRequirement.transport,
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
      );
      expect(clientsByConnectionId['conn_primary'], hasLength(2));
      expect(
        clientsByConnectionId['conn_primary']!.last.readThreadCalls,
        isEmpty,
      );
    },
  );

  test(
    'resumeConversation does not create recovery state before the user sends',
    () async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_missing'] = _savedConversationThread(
          threadId: 'thread_missing',
        );
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
        await client.close();
      });

      await controller.initialize();
      await controller.resumeConversation(
        connectionId: 'conn_primary',
        threadId: 'thread_missing',
      );
      expect(
        controller
            .selectedLaneBinding!
            .sessionController
            .conversationRecoveryState,
        isNull,
      );
      expect(client.startSessionCalls, 0);
    },
  );

  test(
    'resumeConversation activates the replacement lane before transcript restore completes',
    () async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: _profile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final restoreGate = Completer<void>();
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient()
            ..threadHistoriesById['thread_resumed'] = _savedConversationThread(
              threadId: 'thread_resumed',
            );
          if (clientsByConnectionId[connectionId]!.isNotEmpty) {
            appServerClient.readThreadWithTurnsGate = restoreGate;
          }
          clientsByConnectionId[connectionId]!.add(appServerClient);
          return ConnectionLaneBinding(
            connectionId: connectionId,
            profileStore: ConnectionScopedProfileStore(
              connectionId: connectionId,
              connectionRepository: repository,
            ),
            appServerClient: appServerClient,
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
        await _closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      final resumeFuture = controller.resumeConversation(
        connectionId: 'conn_primary',
        threadId: 'thread_resumed',
      );
      for (var attempt = 0; attempt < 20; attempt += 1) {
        if (clientsByConnectionId['conn_primary']!.length >= 2) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }

      expect(clientsByConnectionId['conn_primary']!, hasLength(2));
      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, isNot(same(firstBinding)));
      expect(controller.selectedLaneBinding, same(nextBinding));
      expect(
        nextBinding!
            .sessionController
            .historicalConversationRestoreState
            ?.phase,
        ChatHistoricalConversationRestorePhase.loading,
      );

      restoreGate.complete();
      await resumeFuture;

      expect(
        clientsByConnectionId['conn_primary']!.last.readThreadCalls,
        <String>['thread_resumed'],
      );
      expect(
        nextBinding.sessionController.historicalConversationRestoreState,
        isNull,
      );
    },
  );

  test(
    'deleting the final dormant connection leaves a valid empty workspace',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        repository: MemoryCodexConnectionRepository(
          initialConnections: <SavedConnection>[
            SavedConnection(
              id: 'conn_primary',
              profile: _profile('Primary Box', 'primary.local'),
              secrets: const ConnectionSecrets(password: 'secret-1'),
            ),
          ],
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();

      controller.terminateConnection('conn_primary');
      await controller.deleteDormantConnection('conn_primary');

      expect(controller.state.catalog, const ConnectionCatalogState.empty());
      expect(controller.state.liveConnectionIds, isEmpty);
      expect(controller.state.dormantConnectionIds, isEmpty);
      expect(controller.state.selectedConnectionId, isNull);
      expect(
        controller.state.viewport,
        ConnectionWorkspaceViewport.dormantRoster,
      );
      expect(controller.selectedLaneBinding, isNull);
      expect(clientsById['conn_primary']?.disconnectCalls, 1);
    },
  );
}

ConnectionWorkspaceController _buildWorkspaceController({
  required Map<String, FakeCodexAppServerClient> clientsById,
  MemoryCodexConnectionRepository? repository,
  ConnectionModelCatalogStore? modelCatalogStore,
  ConnectionWorkspaceRecoveryStore? recoveryStore,
  CodexRemoteAppServerHostProbe remoteAppServerHostProbe =
      const _FakeRemoteHostProbe(CodexRemoteAppServerHostCapabilities()),
  CodexRemoteAppServerOwnerInspector remoteAppServerOwnerInspector =
      const _ThrowingRemoteOwnerInspector(),
  CodexRemoteAppServerOwnerControl remoteAppServerOwnerControl =
      const _ThrowingRemoteOwnerControl(),
  Duration? recoveryPersistenceDebounceDuration,
  WorkspaceNow? now,
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
    recoveryStore: recoveryStore,
    remoteAppServerHostProbe: remoteAppServerHostProbe,
    remoteAppServerOwnerInspector: remoteAppServerOwnerInspector,
    remoteAppServerOwnerControl: remoteAppServerOwnerControl,
    recoveryPersistenceDebounceDuration:
        recoveryPersistenceDebounceDuration ??
        const Duration(milliseconds: 250),
    now: now,
    laneBindingFactory: ({required connectionId, required connection}) {
      final appServerClient = clientsById[connectionId]!;
      return ConnectionLaneBinding(
        connectionId: connectionId,
        profileStore: ConnectionScopedProfileStore(
          connectionId: connectionId,
          connectionRepository: resolvedRepository,
        ),
        appServerClient: appServerClient,
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

final class _ThrowingRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  const _ThrowingRemoteOwnerControl();

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    throw StateError('remote owner control should not have been requested');
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
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
}

final class _MutableRemoteOwnerControl
    implements CodexRemoteAppServerOwnerControl {
  _MutableRemoteOwnerControl({
    required CodexRemoteAppServerOwnerSnapshot snapshot,
  }) : _snapshot = snapshot;

  CodexRemoteAppServerOwnerSnapshot _snapshot;
  int startCalls = 0;
  int stopCalls = 0;
  int restartCalls = 0;

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    return _snapshot;
  }

  @override
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    return const CodexRemoteAppServerHostCapabilities();
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    restartCalls += 1;
    await stopOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
    return startOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: workspaceDir,
    );
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    startCalls += 1;
    _snapshot = CodexRemoteAppServerOwnerSnapshot(
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      status: CodexRemoteAppServerOwnerStatus.running,
      sessionName: 'pocket-relay:$ownerId',
      endpoint: const CodexRemoteAppServerEndpoint(
        host: '127.0.0.1',
        port: 4100,
      ),
      detail: 'Remote Pocket Relay server is ready.',
    );
    return _snapshot;
  }

  @override
  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  }) async {
    stopCalls += 1;
    _snapshot = CodexRemoteAppServerOwnerSnapshot(
      ownerId: ownerId,
      workspaceDir: workspaceDir,
      status: CodexRemoteAppServerOwnerStatus.missing,
      sessionName: 'pocket-relay:$ownerId',
      detail: 'No Pocket Relay server is running for this connection.',
    );
    return _snapshot;
  }
}

class _RecordingConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  _RecordingConnectionWorkspaceRecoveryStore({this.initialState});

  final ConnectionWorkspaceRecoveryState? initialState;
  final List<ConnectionWorkspaceRecoveryState?> savedStates =
      <ConnectionWorkspaceRecoveryState?>[];
  ConnectionWorkspaceRecoveryState? _state;

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async {
    return _state ?? initialState;
  }

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    _state = state;
    savedStates.add(state);
  }
}

ConnectionProfile _profile(String label, String host) {
  return ConnectionProfile.defaults().copyWith(
    label: label,
    host: host,
    username: 'vince',
  );
}

CodexAppServerThreadHistory _savedConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_saved',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_saved',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

Future<void> _startBusyTurn(
  ConnectionLaneBinding binding,
  FakeCodexAppServerClient appServerClient,
) async {
  appServerClient.emit(
    const CodexAppServerNotificationEvent(
      method: 'thread/started',
      params: <String, Object?>{
        'thread': <String, Object?>{'id': 'thread_123'},
      },
    ),
  );
  appServerClient.emit(
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
  await Future<void>.delayed(Duration.zero);
  expect(binding.sessionController.sessionState.isBusy, isTrue);
}

class _FakeFlutterSecureStorage extends FlutterSecureStorage {
  _FakeFlutterSecureStorage(this.data);

  final Map<String, String> data;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
      return;
    }
    data[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

Map<String, FakeCodexAppServerClient> _buildClientsById(
  String firstConnectionId,
  String secondConnectionId,
) {
  return <String, FakeCodexAppServerClient>{
    firstConnectionId: FakeCodexAppServerClient(),
    secondConnectionId: FakeCodexAppServerClient(),
  };
}

Future<void> _closeClients(
  Map<String, FakeCodexAppServerClient> clientsById,
) async {
  for (final client in clientsById.values) {
    await client.close();
  }
}

Future<void> _closeClientLists(
  Map<String, List<FakeCodexAppServerClient>> clientsByConnectionId,
) async {
  for (final clients in clientsByConnectionId.values) {
    for (final client in clients) {
      await client.close();
    }
  }
}
