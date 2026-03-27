import 'controller_test_support.dart';

void main() {
  test(
    'instantiating a dormant connection keeps the lane empty until history is explicitly picked',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_secondary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final firstBinding = controller.bindingForConnectionId('conn_primary');

      await controller.instantiateConnection('conn_secondary');

      expect(controller.state.liveConnectionIds, <String>[
        'conn_primary',
        'conn_secondary',
      ]);
      expect(controller.state.nonLiveSavedConnectionIds, isEmpty);
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
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await controller.instantiateConnection('conn_secondary');

    controller.terminateConnection('conn_secondary');

    expect(controller.state.liveConnectionIds, <String>['conn_primary']);
    expect(controller.state.nonLiveSavedConnectionIds, <String>[
      'conn_secondary',
    ]);
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
    expect(controller.bindingForConnectionId('conn_secondary'), isNull);
    expect(clientsById['conn_secondary']?.disconnectCalls, 1);
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  test(
    'terminating the last live lane shows the dormant roster and clears selection',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      controller.terminateConnection('conn_primary');

      expect(controller.state.liveConnectionIds, isEmpty);
      expect(controller.state.nonLiveSavedConnectionIds, <String>[
        'conn_primary',
        'conn_secondary',
      ]);
      expect(controller.state.selectedConnectionId, isNull);
      expect(
        controller.state.viewport,
        ConnectionWorkspaceViewport.savedConnections,
      );
      expect(controller.selectedLaneBinding, isNull);
      expect(clientsById['conn_primary']?.disconnectCalls, 1);
      expect(clientsById['conn_secondary']?.disconnectCalls, 0);
    },
  );

  test('showSavedConnections preserves the selected live lane', () async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();

    controller.showSavedConnections();

    expect(
      controller.state.viewport,
      ConnectionWorkspaceViewport.savedConnections,
    );
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(controller.selectedLaneBinding?.connectionId, 'conn_primary');
  });

  test('showSavedSystems preserves the selected live lane', () async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();

    controller.showSavedSystems();

    expect(controller.state.viewport, ConnectionWorkspaceViewport.savedSystems);
    expect(controller.state.selectedConnectionId, 'conn_primary');
    expect(controller.selectedLaneBinding?.connectionId, 'conn_primary');
  });

  test(
    'instantiating from the dormant roster returns the workspace to a live lane',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      controller.showSavedConnections();

      await controller.instantiateConnection('conn_secondary');

      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(controller.state.selectedConnectionId, 'conn_secondary');
    },
  );

  test(
    'selecting the current live connection exits dormant-roster mode',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      controller.showSavedConnections();

      controller.selectConnection('conn_primary');

      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(controller.state.selectedConnectionId, 'conn_primary');
    },
  );

  test('createConnection appends a new dormant saved connection', () async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
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
      connectionIdGenerator: () => 'conn_created',
    );
    final controller = buildWorkspaceController(
      clientsById: clientsById,
      repository: repository,
    );
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();

    final createdConnectionId = await controller.createConnection(
      profile: workspaceProfile('Third Box', 'third.local'),
      secrets: const ConnectionSecrets(password: 'secret-3'),
    );

    expect(createdConnectionId, 'conn_created');
    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
      'conn_secondary',
      'conn_created',
    ]);
    expect(controller.state.liveConnectionIds, <String>['conn_primary']);
    expect(controller.state.nonLiveSavedConnectionIds, <String>[
      'conn_secondary',
      'conn_created',
    ]);
    expect(controller.bindingForConnectionId('conn_created'), isNull);
  });

  test(
    'createSystem appends a reusable system without opening a lane',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      var nextSystemId = 0;
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
        systemIdGenerator: () => 'sys_created_${nextSystemId++}',
      );
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        repository: repository,
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final initialSystemCount =
          controller.state.systemCatalog.orderedSystemIds.length;

      final createdSystemId = await controller.createSystem(
        profile: const SystemProfile(
          host: 'third.local',
          port: 22,
          username: 'vince',
          authMode: AuthMode.password,
          hostFingerprint: '',
        ),
        secrets: const ConnectionSecrets(password: 'secret-3'),
      );

      expect(createdSystemId, 'sys_created_2');
      expect(
        controller.state.systemCatalog.orderedSystemIds,
        contains('sys_created_2'),
      );
      expect(
        controller.state.systemCatalog.orderedSystemIds.length,
        initialSystemCount + 1,
      );
      expect(controller.state.liveConnectionIds, <String>['conn_primary']);
      expect(controller.bindingForConnectionId('sys_created'), isNull);
    },
  );

  test('deleteSavedSystem removes an unused reusable system', () async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    var nextSystemId = 0;
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
      systemIdGenerator: () => 'sys_created_${nextSystemId++}',
    );
    final controller = buildWorkspaceController(
      clientsById: clientsById,
      repository: repository,
    );
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    final createdSystemId = await controller.createSystem(
      profile: const SystemProfile(
        host: 'third.local',
        port: 22,
        username: 'vince',
        authMode: AuthMode.password,
        hostFingerprint: '',
      ),
      secrets: const ConnectionSecrets(password: 'secret-3'),
    );

    await controller.deleteSavedSystem(createdSystemId);

    expect(
      controller.state.systemCatalog.orderedSystemIds,
      isNot(contains(createdSystemId)),
    );
    expect(controller.state.liveConnectionIds, <String>['conn_primary']);
  });
}
