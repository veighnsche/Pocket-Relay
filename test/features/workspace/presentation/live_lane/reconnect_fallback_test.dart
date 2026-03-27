import '../support/workspace_surface_test_support.dart';

void main() {
  testWidgets(
    'transport reconnect keeps last-known model catalog fallback available in live settings',
    (tester) async {
      final clientsById = buildClientsById('conn_primary');
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
      final controller = buildWorkspaceController(
        clientsById: clientsById,
        modelCatalogStore: modelCatalogStore,
      );
      final settingsOverlayDelegate =
          DeferredConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      final laneBinding = controller.selectedLaneBinding!;
      await clientsById['conn_primary']!.connect(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
      );
      await clientsById['conn_primary']!.disconnect();
      await tester.pumpWidget(
        buildLiveLaneApp(
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
            profile: workspaceProfile('Primary Box', 'primary.local'),
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
        buildWorkspaceDrivenLiveLaneApp(
          controller,
          settingsOverlayDelegate: DeferredConnectionSettingsOverlayDelegate(),
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
}
