import 'controller_test_support.dart';

void main() {
  test(
    'resuming after background preserves the selected lane and draft without forcing reconnect',
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
        await closeClientLists(clientsByConnectionId);
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
            ..threadHistoriesById['thread_123'] = savedConversationThread(
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
        await closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Recover me');
      await startBusyTurn(
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
        ConnectionWorkspaceRecoveryOutcome.liveReattached,
      );
      expect(clientsByConnectionId['conn_primary'], hasLength(1));
      expect(clientsByConnectionId['conn_primary']!.first.connectCalls, 1);
      expect(clientsByConnectionId['conn_primary']!.first.disconnectCalls, 0);
      expect(clientsByConnectionId['conn_primary']!.first.startSessionCalls, 1);
      expect(
        clientsByConnectionId['conn_primary']!
            .first
            .startSessionRequests
            .single
            .resumeThreadId,
        'thread_123',
      );
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
    'resumed auto-reconnect replays pending user input so the lane can still submit it through the workspace path',
    () async {
      const replayedRequest = CodexAppServerRequestEvent(
        requestId: 'input_replay_1',
        method: 'item/tool/requestUserInput',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_running',
          'itemId': 'item_input_1',
          'questions': <Object?>[
            <String, Object?>{
              'id': 'q1',
              'header': 'Name',
              'question': 'What is your name?',
            },
          ],
        },
      );
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile('Primary Box', 'primary.local'),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
        ],
      );
      final clientsByConnectionId = <String, List<FakeCodexAppServerClient>>{
        'conn_primary': <FakeCodexAppServerClient>[],
      };
      final controller = ConnectionWorkspaceController(
        connectionRepository: repository,
        laneBindingFactory: ({required connectionId, required connection}) {
          final appServerClient = FakeCodexAppServerClient()
            ..threadHistoriesById['thread_123'] = savedConversationThread(
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
        await closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final binding = controller.bindingForConnectionId('conn_primary')!;
      await startBusyTurn(
        binding,
        clientsByConnectionId['conn_primary']!.first,
      );
      clientsByConnectionId['conn_primary']!.first.emit(replayedRequest);
      await Future<void>.delayed(Duration.zero);

      expect(
        binding.sessionController.sessionState.pendingUserInputRequests
            .containsKey('input_replay_1'),
        isTrue,
      );

      clientsByConnectionId['conn_primary']!
              .first
              .resumeThreadReplayEventsByThreadId['thread_123'] =
          <CodexAppServerEvent>[replayedRequest];

      await controller.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await clientsByConnectionId['conn_primary']!.first.disconnect();
      await Future<void>.delayed(Duration.zero);
      await controller.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );

      final reboundBinding = controller.bindingForConnectionId('conn_primary')!;
      expect(reboundBinding, same(binding));
      expect(
        reboundBinding.sessionController.sessionState.pendingUserInputRequests
            .containsKey('input_replay_1'),
        isTrue,
      );

      await reboundBinding.sessionController.submitUserInput(
        'input_replay_1',
        const <String, List<String>>{
          'q1': <String>['Vince'],
        },
      );

      expect(
        clientsByConnectionId['conn_primary']!.first.userInputResponses,
        <({String requestId, Map<String, List<String>> answers})>[
          (
            requestId: 'input_replay_1',
            answers: const <String, List<String>>{
              'q1': <String>['Vince'],
            },
          ),
        ],
      );
    },
  );
}
