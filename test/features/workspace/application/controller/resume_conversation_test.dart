import 'controller_test_support.dart';

void main() {
  test(
    'resumeConversation replaces the live binding and restores the selected transcript',
    () async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile('Secondary Box', 'secondary.local'),
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
          appServerClient.threadHistoriesById['thread_resumed'] =
              savedConversationThread(threadId: 'thread_resumed');
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
        await closeClientLists(clientsByConnectionId);
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
            .whereType<TranscriptTextBlock>()
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
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile('Secondary Box', 'secondary.local'),
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
          appServerClient.threadHistoriesById['thread_resumed'] =
              savedConversationThread(threadId: 'thread_resumed');
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
        await closeClientLists(clientsByConnectionId);
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
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final client = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_missing'] = savedConversationThread(
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
            profile: workspaceProfile('Primary Box', 'primary.local'),
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
            ..threadHistoriesById['thread_resumed'] = savedConversationThread(
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
        await closeClientLists(clientsByConnectionId);
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
}
