import 'controller_test_support.dart';

void main() {
  test('terminateConnection refuses to close a busy live lane', () async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await startBusyTurn(
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
    final controller = ConnectionWorkspaceController(
      connectionRepository: repository,
      laneBindingFactory: ({required connectionId, required connection}) {
        final appServerClient = FakeCodexAppServerClient();
        appServerClient.threadHistoriesById['thread_saved'] =
            savedConversationThread(threadId: 'thread_saved');
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
    await startBusyTurn(
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
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    final firstBinding = controller.bindingForConnectionId('conn_primary')!;
    await startBusyTurn(firstBinding, clientsById['conn_primary']!);
    await controller.saveLiveConnectionEdits(
      connectionId: 'conn_primary',
      profile: workspaceProfile('Primary Renamed', 'primary.changed'),
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
}
