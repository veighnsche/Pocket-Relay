import 'desktop_shell_test_support.dart';

void main() {
  testWidgets(
    'desktop conversation history retries with saved connection edits when reconnect is required',
    (tester) async {
      final clientsById = buildClientsById('conn_primary', 'conn_secondary');
      final repository = FakeCodexWorkspaceConversationHistoryRepository();
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
        ).copyWith(hostFingerprint: 'SHA256:saved'),
        secrets: const ConnectionSecrets(password: 'saved-secret'),
      );

      await tester.pumpWidget(
        buildShell(controller, conversationHistoryRepository: repository),
      );
      await tester.pumpAndSettle();

      expect(controller.state.requiresReconnect('conn_primary'), isTrue);

      await openLaneConversationHistory(tester);

      expect(repository.loadCalls, hasLength(1));
      expect(repository.loadCalls.single.$1.host, 'saved.primary.local');
      expect(repository.loadCalls.single.$1.hostFingerprint, 'SHA256:saved');
      expect(repository.loadCalls.single.$2.password, 'saved-secret');
    },
  );

  testWidgets(
    'desktop conversation history row resumes the selected Codex thread',
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
                    promptCount: 3,
                    firstPromptAt: DateTime(2026, 3, 20, 9),
                    lastActivityAt: DateTime(2026, 3, 20, 11),
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

      expect(clientsById['conn_primary']?.disconnectCalls, 1);
      expect(controller.state.selectedConnectionId, 'conn_primary');
      expect(controller.state.viewport, ConnectionWorkspaceViewport.liveLane);
      expect(find.text('Restored answer'), findsOneWidget);
      expect(
        controller.selectedLaneBinding!.sessionController.transcriptBlocks
            .whereType<TranscriptTextBlock>()
            .single
            .body,
        'Restored answer',
      );
    },
  );

  testWidgets(
    'desktop conversation history row surfaces unavailable-history chrome when the selected transcript is empty',
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

  testWidgets(
    'desktop conversation history resume primes the lane so the next send stays on that conversation',
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
                    promptCount: 3,
                    firstPromptAt: DateTime(2026, 3, 20, 9),
                    lastActivityAt: DateTime(2026, 3, 20, 11),
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

      expect(clientsById['conn_primary']!.startSessionCalls, 0);

      expect(
        await controller.selectedLaneBinding!.sessionController.sendPrompt(
          'Continue this thread',
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));

      expect(clientsById['conn_primary']!.startSessionCalls, 1);
      expect(
        clientsById['conn_primary']!.startSessionRequests.single.resumeThreadId,
        'thread_saved',
      );
      expect(clientsById['conn_primary']!.sentTurns, <
        ({
          String threadId,
          CodexAppServerTurnInput input,
          String text,
          String? model,
          CodexReasoningEffort? effort,
        })
      >[
        (
          threadId: 'thread_saved',
          input: const CodexAppServerTurnInput.text('Continue this thread'),
          text: 'Continue this thread',
          model: null,
          effort: null,
        ),
      ]);
    },
  );
}
