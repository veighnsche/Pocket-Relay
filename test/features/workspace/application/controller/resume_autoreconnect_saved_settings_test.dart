import 'controller_test_support.dart';

void main() {
  test(
    'resumed does not auto-reconnect when only saved settings are pending',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary')!;

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
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
      firstBinding.restoreComposerDraft('Recover edited lane');
      await startBusyTurn(
        firstBinding,
        clientsByConnectionId['conn_primary']!.first,
      );

      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile('Primary Renamed', 'primary.changed'),
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
}
