import 'desktop_shell_test_support.dart';

void main() {
  testWidgets(
    'desktop lane strip opens the workspace conversation history sheet',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      final repository = FakeCodexWorkspaceConversationHistoryRepository(
        conversations: <CodexWorkspaceConversationSummary>[
          CodexWorkspaceConversationSummary(
            threadId: 'thread_saved',
            preview: 'Saved backend thread',
            cwd: '/workspace',
            promptCount: 3,
            firstPromptAt: DateTime(2026, 3, 20, 9),
            lastActivityAt: DateTime(2026, 3, 20, 11),
          ),
        ],
      );
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        buildShell(controller, conversationHistoryRepository: repository),
      );
      await tester.pumpAndSettle();

      await openLaneConversationHistory(tester);

      expect(find.byType(BottomSheet), findsNothing);
      expect(
        find.byKey(
          const ValueKey<String>('desktop_conversation_history_surface'),
        ),
        findsOneWidget,
      );
      expect(find.text('Saved backend thread'), findsOneWidget);
      expect(repository.loadCalls, hasLength(1));
      expect(repository.loadCalls.single.$3, 'conn_primary');
    },
  );

  testWidgets(
    'desktop conversation history does not reload while the dialog rebuilds on resize',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      final repository = FakeCodexWorkspaceConversationHistoryRepository(
        conversations: <CodexWorkspaceConversationSummary>[
          CodexWorkspaceConversationSummary(
            threadId: 'thread_saved',
            preview: 'Saved backend thread',
            cwd: '/workspace',
            promptCount: 3,
            firstPromptAt: DateTime(2026, 3, 20, 9),
            lastActivityAt: DateTime(2026, 3, 20, 11),
          ),
        ],
      );
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        buildShell(controller, conversationHistoryRepository: repository),
      );
      await tester.pumpAndSettle();

      await openLaneConversationHistory(tester);

      expect(repository.loadCalls, hasLength(1));

      tester.view.physicalSize = const Size(1440, 960);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('desktop_conversation_history_surface'),
        ),
        findsOneWidget,
      );
      expect(repository.loadCalls, hasLength(1));
    },
  );

  testWidgets(
    'desktop overflow disables non-roster actions when the active lane has no workspace',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_primary',
            profile: workspaceProfile(
              'Primary Box',
              'primary.local',
            ).copyWith(workspaceDir: ''),
            secrets: const ConnectionSecrets(password: 'secret-1'),
          ),
          SavedConnection(
            id: 'conn_secondary',
            profile: workspaceProfile('Secondary Box', 'secondary.local'),
            secrets: const ConnectionSecrets(password: 'secret-2'),
          ),
        ],
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
      await tester.pumpWidget(buildShell(controller));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      final newThreadItem = tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('New thread'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );
      final clearTranscriptItem = tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('Clear transcript'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );
      final savedConnectionsItem = tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('Workspaces'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );

      expect(newThreadItem.enabled, isFalse);
      expect(clearTranscriptItem.enabled, isFalse);
      expect(
        find.byKey(const ValueKey('lane_connection_action_history')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('lane_connection_action_close')),
        findsNothing,
      );
      expect(savedConnectionsItem.enabled, isTrue);
      expect(
        find.ancestor(
          of: find.text('Close lane'),
          matching: find.byType(PopupMenuItem<int>),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('Conversation history'),
          matching: find.byType(PopupMenuItem<int>),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('desktop conversation history shows a generic backend error', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(
      buildShell(
        controller,
        conversationHistoryRepository:
            FakeCodexWorkspaceConversationHistoryRepository(
              error: StateError('history backend unavailable'),
            ),
      ),
    );
    await tester.pumpAndSettle();

    await openLaneConversationHistory(tester);
    expect(find.text('Could not load conversations'), findsOneWidget);
    expect(
      find.textContaining(
        '[${PocketErrorCatalog.connectionHistoryLoadFailed.code}]',
      ),
      findsOneWidget,
    );
    expect(clientsById['conn_primary']?.disconnectCalls, 0);
  });

  testWidgets(
    'desktop conversation history surfaces remote server health and opens connection settings',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
          conversationHistoryRepository:
              FakeCodexWorkspaceConversationHistoryRepository(
                error: const CodexRemoteAppServerAttachException(
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
                ),
              ),
        ),
      );
      await tester.pumpAndSettle();

      await openLaneConversationHistory(tester);

      expect(find.text('Remote server unhealthy'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionHistoryServerUnhealthy.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('readyz failed'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey('conversation_history_open_connection_settings'),
        ),
      );
      await tester.pumpAndSettle();

      expect(settingsOverlayDelegate.launchedSettings, hasLength(1));
      expect(
        settingsOverlayDelegate.launchedSettings.single.$1.host,
        'primary.local',
      );
    },
  );

  testWidgets(
    'desktop conversation history can open connection settings for an unpinned host key',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate();
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(
        buildShell(
          controller,
          settingsOverlayDelegate: settingsOverlayDelegate,
          conversationHistoryRepository:
              FakeCodexWorkspaceConversationHistoryRepository(
                error:
                    const CodexWorkspaceConversationHistoryUnpinnedHostKeyException(
                      host: 'example.com',
                      port: 22,
                      keyType: 'ssh-ed25519',
                      fingerprint: '7a:9f:d7:dc:2e:f2',
                    ),
              ),
        ),
      );
      await tester.pumpAndSettle();

      await openLaneConversationHistory(tester);

      expect(find.text('Host key not pinned'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionHistoryHostKeyUnpinned.code}]',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(
          const ValueKey('conversation_history_open_connection_settings'),
        ),
      );
      await tester.pumpAndSettle();

      expect(settingsOverlayDelegate.launchedSettings, hasLength(1));
      expect(
        settingsOverlayDelegate.launchedSettings.single.$1.host,
        'primary.local',
      );
      expect(
        settingsOverlayDelegate.launchedSettings.single.$2.password,
        'secret-1',
      );
    },
  );
}
