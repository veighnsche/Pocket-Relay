import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';

import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

void main() {
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
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore(
        initialState: const ConnectionWorkspaceRecoveryState(
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
      expect(binding.sessionController.sessionState.rootThreadId, 'thread_saved');
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
        laneBindingFactory:
            ({
              required connectionId,
              required connection,
            }) {
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
        laneBindingFactory:
            ({
              required connectionId,
              required connection,
            }) {
              final appServerClient = FakeCodexAppServerClient()
                ..threadHistoriesById['thread_saved'] =
                    _savedConversationThread(threadId: 'thread_saved');
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
    'resuming after background reconnects the selected lane, preserves its draft, and marks other live lanes stale',
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
        laneBindingFactory:
            ({
              required connectionId,
              required connection,
            }) {
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
      await controller.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      expect(nextBinding, isNotNull);
      expect(nextBinding, isNot(same(firstBinding)));
      expect(nextBinding!.composerDraftHost.draft.text, 'Draft survives');
      expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 1);
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(controller.state.requiresReconnect('conn_secondary'), isTrue);
    },
  );

  test(
    'inactive without pause snapshots recovery state but does not reconnect the selected lane',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final recoveryStore = MemoryConnectionWorkspaceRecoveryStore();
      final controller = _buildWorkspaceController(
        clientsById: clientsById,
        recoveryStore: recoveryStore,
      );
      addTearDown(() async {
        controller.dispose();
        await _closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Keep me');

      await controller.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await controller.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      final nextBinding = controller.bindingForConnectionId('conn_primary');
      final recoveryState = await recoveryStore.load();
      expect(nextBinding, same(firstBinding));
      expect(clientsById['conn_primary']!.disconnectCalls, 0);
      expect(controller.state.requiresReconnect('conn_primary'), isFalse);
      expect(recoveryState, isNotNull);
      expect(recoveryState!.draftText, 'Keep me');
      expect(recoveryState.backgroundedAt, isNotNull);
    },
  );

  test(
    'deleteDormantConnection removes the saved definition',
    () async {
      final clientsById = _buildClientsById('conn_primary', 'conn_secondary');
      final controller = _buildWorkspaceController(clientsById: clientsById);
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
    },
  );

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
        laneBindingFactory:
            ({
              required connectionId,
              required connection,
            }) {
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
        laneBindingFactory:
            ({
              required connectionId,
              required connection,
            }) {
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
        controller.selectedLaneBinding!.sessionController.conversationRecoveryState,
        isNull,
      );
      expect(
        client.startSessionCalls,
        0,
      );
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
        laneBindingFactory:
            ({
              required connectionId,
              required connection,
            }) {
              final appServerClient = FakeCodexAppServerClient()
                ..threadHistoriesById['thread_resumed'] =
                    _savedConversationThread(threadId: 'thread_resumed');
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
  ConnectionWorkspaceRecoveryStore? recoveryStore,
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
    recoveryStore: recoveryStore,
    laneBindingFactory:
        ({
          required connectionId,
          required connection,
        }) {
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
