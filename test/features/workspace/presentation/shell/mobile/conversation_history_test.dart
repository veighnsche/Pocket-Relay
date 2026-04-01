import 'mobile_shell_test_support.dart';

void main() {
  testWidgets('lane strip opens the workspace conversation history sheet', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    final repository = FakeCodexWorkspaceConversationHistoryRepository(
      conversations: <CodexWorkspaceConversationSummary>[
        CodexWorkspaceConversationSummary(
          threadId: 'thread_saved',
          preview: 'Saved backend thread',
          cwd: '/workspace',
          promptCount: 2,
          firstPromptAt: DateTime(2026, 3, 20, 9),
          lastActivityAt: DateTime(2026, 3, 20, 10),
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

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Saved backend thread'), findsOneWidget);
    expect(find.textContaining('2 prompts'), findsOneWidget);
    expect(repository.loadOwnerIds, <String?>['conn_primary']);
  });

  testWidgets(
    'mobile shell keeps the live lane empty until history is explicitly picked',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await tester.pumpWidget(buildShell(controller));
      await tester.pumpAndSettle();

      expect(find.text('Restored answer'), findsNothing);
      expect(clientsById['conn_primary']?.readThreadCalls, isEmpty);
    },
  );

  testWidgets(
    'mobile conversation history row resumes the selected Codex thread',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_saved'] =
          savedConversationThread(threadId: 'thread_saved');
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
                conversations: <CodexWorkspaceConversationSummary>[
                  CodexWorkspaceConversationSummary(
                    threadId: 'thread_saved',
                    preview: 'Saved backend thread',
                    cwd: '/workspace',
                    promptCount: 2,
                    firstPromptAt: DateTime(2026, 3, 20, 9),
                    lastActivityAt: DateTime(2026, 3, 20, 10),
                  ),
                ],
              ),
        ),
      );
      await tester.pumpAndSettle();

      await openLaneConversationHistory(tester);
      await tester.tap(
        find.byKey(const ValueKey('workspace_conversation_thread_saved')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restored answer'), findsOneWidget);
      expect(clientsById['conn_primary']?.disconnectCalls, 1);
    },
  );

  testWidgets(
    'mobile conversation history row surfaces unavailable-history chrome when the selected transcript is empty',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      clientsById['conn_primary']!.threadHistoriesById['thread_empty'] =
          const CodexAppServerThreadHistory(
            id: 'thread_empty',
            name: 'Empty conversation',
            sourceKind: 'app-server',
            turns: <CodexAppServerHistoryTurn>[],
          );
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
                conversations: <CodexWorkspaceConversationSummary>[
                  CodexWorkspaceConversationSummary(
                    threadId: 'thread_empty',
                    preview: 'Empty backend thread',
                    cwd: '/workspace',
                    promptCount: 0,
                    firstPromptAt: null,
                    lastActivityAt: DateTime(2026, 3, 20, 11),
                  ),
                ],
              ),
        ),
      );
      await tester.pumpAndSettle();

      await openLaneConversationHistory(tester);
      await tester.tap(
        find.byKey(const ValueKey('workspace_conversation_thread_empty')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transcript history unavailable'), findsOneWidget);
      expect(find.text('Retry load'), findsOneWidget);
    },
  );

  testWidgets('lane strip shows a generic conversation history backend error', (
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
  });

  testWidgets(
    'when reconnect is required and the saved profile has no workspace, the overflow hides conversation history',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final controller = buildWorkspaceController(clientsById: clientsById);
      addTearDown(() async {
        controller.dispose();
        await closeClients(clientsById);
      });

      await controller.initialize();
      await controller.saveLiveConnectionEdits(
        connectionId: 'conn_primary',
        profile: workspaceProfile(
          'Primary Box',
          'saved.primary.local',
        ).copyWith(workspaceDir: ''),
        secrets: const ConnectionSecrets(password: 'saved-secret'),
      );
      await tester.pumpWidget(buildShell(controller));
      await tester.pumpAndSettle();

      expect(controller.state.requiresReconnect('conn_primary'), isTrue);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('Conversation history'), findsNothing);
      expect(find.text('Workspaces'), findsOneWidget);
      expect(find.text('Close lane'), findsOneWidget);
    },
  );

  testWidgets(
    'when the active lane has no workspace, the lane strip disables history and the overflow keeps only roster actions',
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
}
