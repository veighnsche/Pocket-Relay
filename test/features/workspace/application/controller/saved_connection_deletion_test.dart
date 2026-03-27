import 'controller_test_support.dart';

void main() {
  test('deleteSavedConnection removes the saved definition', () async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
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
    final controller = buildWorkspaceController(
      clientsById: clientsById,
      modelCatalogStore: modelCatalogStore,
    );
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await controller.deleteSavedConnection('conn_secondary');

    expect(controller.state.catalog.orderedConnectionIds, <String>[
      'conn_primary',
    ]);
    expect(controller.state.nonLiveSavedConnectionIds, isEmpty);
    expect(await modelCatalogStore.load('conn_secondary'), isNull);
  });

  test(
    'deleting the final dormant connection leaves a valid empty workspace',
    () async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        repository: MemoryCodexConnectionRepository(
          initialConnections: <SavedConnection>[
            SavedConnection(
              id: 'conn_primary',
              profile: workspaceProfile('Primary Box', 'primary.local'),
              secrets: const ConnectionSecrets(password: 'secret-1'),
            ),
          ],
        ),
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();

      controller.terminateConnection('conn_primary');
      await controller.deleteSavedConnection('conn_primary');

      expect(controller.state.catalog, const ConnectionCatalogState.empty());
      expect(controller.state.liveConnectionIds, isEmpty);
      expect(controller.state.nonLiveSavedConnectionIds, isEmpty);
      expect(controller.state.selectedConnectionId, isNull);
      expect(
        controller.state.viewport,
        ConnectionWorkspaceViewport.savedConnections,
      );
      expect(controller.selectedLaneBinding, isNull);
      expect(clientsById['conn_primary']?.disconnectCalls, 1);
    },
  );
}
