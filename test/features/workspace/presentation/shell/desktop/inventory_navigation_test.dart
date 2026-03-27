import 'desktop_shell_test_support.dart';

void main() {
  testWidgets('renders lifecycle sections in the desktop sidebar', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    expect(find.text('Workspaces'), findsNWidgets(2));
    expect(find.text('Systems'), findsOneWidget);
    expect(find.text('Current lane'), findsNothing);
    expect(find.text('Saved workspaces'), findsNothing);
    expect(find.text('Open lanes'), findsOneWidget);
    expect(find.text('Needs attention'), findsNothing);
    expect(
      find.byKey(const ValueKey('desktop_connection_conn_primary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('desktop_connection_conn_secondary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('desktop_saved_connections')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('desktop_saved_systems')), findsOneWidget);
    expect(find.text('Manage workspaces'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop_sidebar_toggle')),
      findsOneWidget,
    );
    expect(find.byType(IconButton), findsWidgets);
  });

  testWidgets(
    'desktop shell keeps the live lane empty until history is explicitly picked',
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
    'desktop shell does not surface unavailable-history chrome on startup',
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
      await tester.pumpWidget(buildShell(controller));
      await tester.pumpAndSettle();

      expect(find.text('Transcript history unavailable'), findsNothing);
      expect(find.text('Retry load'), findsNothing);
      expect(clientsById['conn_primary']?.readThreadCalls, isEmpty);
    },
  );

  testWidgets(
    'desktop sidebar promotes unconfigured saved connections into Needs attention',
    (tester) async {
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
            profile: workspaceProfile(
              'Secondary Box',
              'secondary.local',
            ).copyWith(workspaceDir: ''),
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

      expect(find.text('Needs attention'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('desktop_connection_conn_secondary')),
          matching: find.text('Workspace not configured'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'macOS sidebar can collapse into a thin rail and still open saved connections',
    (tester) async {
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
              ),
        ),
      );
      await tester.pumpAndSettle();

      final expandedWidth = tester
          .getSize(find.byKey(const ValueKey('desktop_sidebar')))
          .width;

      await tester.tap(find.byKey(const ValueKey('desktop_sidebar_toggle')));
      await tester.pumpAndSettle();

      final collapsedWidth = tester
          .getSize(find.byKey(const ValueKey('desktop_sidebar')))
          .width;

      expect(collapsedWidth, lessThan(expandedWidth));
      expect(collapsedWidth, lessThanOrEqualTo(80));
      expect(find.text('Workspaces'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('desktop_saved_connections')));
      await tester.pumpAndSettle();

      expect(controller.state.isShowingSavedConnections, isTrue);
      expect(
        find.byKey(const ValueKey('saved_connection_conn_secondary')),
        findsOneWidget,
      );
    },
  );

  testWidgets('all connections action shows the full view in the main pane', (
    tester,
  ) async {
    final clientsById = buildClientsById('conn_primary', 'conn_secondary');
    final controller = buildWorkspaceController(clientsById: clientsById);
    addTearDown(() async {
      controller.dispose();
      await closeClients(clientsById);
    });

    await controller.initialize();
    await tester.pumpWidget(buildShell(controller));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('desktop_saved_connections')));
    await tester.pumpAndSettle();

    expect(controller.state.isShowingSavedConnections, isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('add_connection')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('New workspace'), findsOneWidget);
  });
}
