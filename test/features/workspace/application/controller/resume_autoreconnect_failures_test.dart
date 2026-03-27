import 'controller_test_support.dart';

void main() {
  test(
    'resumed auto-reconnect replays pending approvals so the lane can still approve through the workspace path',
    () async {
      const replayedRequest = CodexAppServerRequestEvent(
        requestId: 'approval_replay_1',
        method: 'item/permissions/requestApproval',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_running',
          'itemId': 'item_approval_1',
          'message': 'Need permission to continue.',
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
        binding.sessionController.sessionState.pendingApprovalRequests
            .containsKey('approval_replay_1'),
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
        reboundBinding.sessionController.sessionState.pendingApprovalRequests
            .containsKey('approval_replay_1'),
        isTrue,
      );

      await reboundBinding.sessionController.approveRequest(
        'approval_replay_1',
      );

      expect(
        clientsByConnectionId['conn_primary']!.first.approvalDecisions,
        <({String requestId, bool approved})>[
          (requestId: 'approval_replay_1', approved: true),
        ],
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
    'resumed auto-reconnect stores remote stopped runtime when attach to the managed owner fails',
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
                : const CodexRemoteAppServerAttachException(
                    snapshot: CodexRemoteAppServerOwnerSnapshot(
                      ownerId: 'conn_primary',
                      workspaceDir: '/workspace',
                      status: CodexRemoteAppServerOwnerStatus.stopped,
                      sessionName: 'pocket-relay-conn_primary',
                      detail: 'Managed remote app-server is not running.',
                    ),
                    message: 'Managed remote app-server is not running.',
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
      clientsByConnectionId['conn_primary']!.first.connectError =
          const CodexRemoteAppServerAttachException(
            snapshot: CodexRemoteAppServerOwnerSnapshot(
              ownerId: 'conn_primary',
              workspaceDir: '/workspace',
              status: CodexRemoteAppServerOwnerStatus.stopped,
              sessionName: 'pocket-relay-conn_primary',
              detail: 'Managed remote app-server is not running.',
            ),
            message: 'Managed remote app-server is not running.',
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
        ConnectionRemoteServerStatus.notRunning,
      );
      expect(
        remoteRuntime.server.detail,
        'Managed remote app-server is not running.',
      );
      expect(
        controller.state.transportRecoveryPhaseFor('conn_primary'),
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      expect(
        controller.state.liveReattachPhaseFor('conn_primary'),
        ConnectionWorkspaceLiveReattachPhase.ownerMissing,
      );
      expect(
        controller.state
            .recoveryDiagnosticsFor('conn_primary')!
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
    'resumed auto-reconnect stores remote unhealthy runtime when attach to the managed owner fails',
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
                : const CodexRemoteAppServerAttachException(
                    snapshot: CodexRemoteAppServerOwnerSnapshot(
                      ownerId: 'conn_primary',
                      workspaceDir: '/workspace',
                      status: CodexRemoteAppServerOwnerStatus.unhealthy,
                      sessionName: 'pocket-relay-conn_primary',
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
        await closeClientLists(clientsByConnectionId);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;
      firstBinding.restoreComposerDraft('Recover me');
      await startBusyTurn(
        firstBinding,
        clientsByConnectionId['conn_primary']!.first,
      );
      clientsByConnectionId['conn_primary']!
          .first
          .connectError = const CodexRemoteAppServerAttachException(
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
        controller.state
            .recoveryDiagnosticsFor('conn_primary')!
            .lastRecoveryOutcome,
        ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
      );
      expect(
        controller.bindingForConnectionId('conn_primary'),
        same(firstBinding),
      );
    },
  );
}
