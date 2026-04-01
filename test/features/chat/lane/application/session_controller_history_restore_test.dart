import 'session_controller_test_support.dart';

void main() {
  test(
    'initialize ignores unavailable history until the user explicitly resumes',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_empty'] =
            const CodexAppServerThreadHistory(
              id: 'thread_empty',
              name: 'Empty conversation',
              sourceKind: 'app-server',
              turns: <CodexAppServerHistoryTurn>[],
            );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      expect(appServerClient.startSessionCalls, 0);
      expect(appServerClient.connectCalls, 0);
      expect(appServerClient.readThreadCalls, isEmpty);
      expect(controller.historicalConversationRestoreState, isNull);
      expect(controller.sessionState.rootThreadId, isNull);
      expect(controller.transcriptBlocks, isEmpty);
      expect(await controller.sendPrompt('stay fresh after startup'), isTrue);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        isNull,
      );
      expect(appServerClient.sentTurns.single, (
        threadId: 'thread_123',
        input: const CodexAppServerTurnInput.text('stay fresh after startup'),
        text: 'stay fresh after startup',
        model: null,
        effort: null,
      ));
    },
  );

  test(
    'selectConversationForResume hydrates the saved conversation transcript',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      await controller.selectConversationForResume('thread_saved');

      expect(appServerClient.connectCalls, 1);
      expect(appServerClient.readThreadCalls, <String>['thread_saved']);
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        contains('Restore this'),
      );
      expect(
        controller.transcriptBlocks.whereType<CodexTextBlock>().map(
          (block) => block.body,
        ),
        contains('Restored answer'),
      );
      expect(controller.sessionState.rootThreadId, 'thread_saved');
    },
  );

  test(
    'reattachConversation resumes the same thread without rereading transcript history',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      await controller.selectConversationForResume('thread_saved');
      final restoredUserTexts = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .map((block) => block.text)
          .toList(growable: false);
      final restoredAssistantTexts = controller.transcriptBlocks
          .whereType<CodexTextBlock>()
          .map((block) => block.body)
          .toList(growable: false);

      appServerClient.readThreadCalls.clear();
      appServerClient.startSessionCalls = 0;
      appServerClient.startSessionRequests.clear();

      await controller.reattachConversation('thread_saved');

      expect(appServerClient.readThreadCalls, isEmpty);
      expect(appServerClient.startSessionCalls, 1);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        'thread_saved',
      );
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        restoredUserTexts,
      );
      expect(
        controller.transcriptBlocks.whereType<CodexTextBlock>().map(
          (block) => block.body,
        ),
        restoredAssistantTexts,
      );
      expect(controller.sessionState.rootThreadId, 'thread_saved');
      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'reattachConversation restores the selected transcript when the lane is empty',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_live'] = savedConversationThread(
          threadId: 'thread_live',
        );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.reattachConversation('thread_live');

      expect(appServerClient.connectCalls, 1);
      expect(appServerClient.readThreadCalls, <String>['thread_live']);
      expect(appServerClient.startSessionCalls, 1);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        'thread_live',
      );
      expect(controller.sessionState.rootThreadId, 'thread_live');
      expect(controller.sessionState.currentThreadId, 'thread_live');
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        contains('Restore this'),
      );
      expect(
        controller.transcriptBlocks.whereType<CodexTextBlock>().map(
          (block) => block.body,
        ),
        contains('Restored answer'),
      );
      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'reattachConversation preserves live header metadata when history omits it on an empty lane',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..startSessionModel = 'gpt-5.4'
        ..startSessionReasoningEffort = 'high'
        ..threadHistoriesById['thread_live'] = savedConversationThread(
          threadId: 'thread_live',
        );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.reattachConversation('thread_live');

      expect(controller.sessionState.headerMetadata.model, 'gpt-5.4');
      expect(controller.sessionState.headerMetadata.reasoningEffort, 'high');
    },
  );

  test(
    'reattachConversation restores history and keeps the latest running turn active on an empty lane',
    () async {
      const replayedRequest = CodexAppServerRequestEvent(
        requestId: 'input_running',
        method: 'item/tool/requestUserInput',
        params: <String, Object?>{
          'threadId': 'thread_live',
          'turnId': 'turn_running',
          'itemId': 'item_assistant_running',
          'questions': <Object?>[
            <String, Object?>{
              'id': 'q1',
              'header': 'Approval',
              'question': 'Continue?',
            },
          ],
        },
      );
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_live'] = runningConversationThread(
          threadId: 'thread_live',
        )
        ..resumeThreadReplayEventsByThreadId['thread_live'] =
            <CodexAppServerEvent>[replayedRequest];
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      await controller.reattachConversation('thread_live');

      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.readThreadCalls, <String>['thread_live']);
      expect(controller.sessionState.currentThreadId, 'thread_live');
      expect(controller.sessionState.activeTurn?.turnId, 'turn_running');
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        containsAll(<String>['Restore this', 'Keep going']),
      );
      expect(
        controller.transcriptBlocks.whereType<CodexTextBlock>().map(
          (block) => block.body,
        ),
        containsAll(<String>['Restored answer', 'Still running']),
      );
      expect(
        controller.sessionState.pendingUserInputRequests.containsKey(
          'input_running',
        ),
        isTrue,
      );
    },
  );

  test(
    'reattachConversation replays pending user input requests so they remain actionable after reconnect',
    () async {
      const replayedRequest = CodexAppServerRequestEvent(
        requestId: 'input_1',
        method: 'item/tool/requestUserInput',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'item_1',
          'questions': <Object?>[
            <String, Object?>{
              'id': 'q1',
              'header': 'Name',
              'question': 'What is your name?',
            },
          ],
        },
      );
      final appServerClient = FakeCodexAppServerClient()
        ..resumeThreadReplayEventsByThreadId['thread_123'] =
            <CodexAppServerEvent>[replayedRequest];
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('First prompt'), isTrue);
      appServerClient.emit(replayedRequest);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.sessionState.pendingUserInputRequests.containsKey('input_1'),
        isTrue,
      );

      await appServerClient.disconnect();
      await controller.reattachConversation('thread_123');
      await controller.submitUserInput('input_1', const <String, List<String>>{
        'q1': <String>['Vince'],
      });

      expect(
        appServerClient.userInputResponses,
        <({String requestId, Map<String, List<String>> answers})>[
          (
            requestId: 'input_1',
            answers: const <String, List<String>>{
              'q1': <String>['Vince'],
            },
          ),
        ],
      );
    },
  );

  test(
    'reattachConversation replays pending approval requests so they remain actionable after reconnect',
    () async {
      const replayedRequest = CodexAppServerRequestEvent(
        requestId: 'approval_1',
        method: 'item/permissions/requestApproval',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_1',
          'itemId': 'item_approval_1',
          'message': 'Need permission to continue.',
        },
      );
      final appServerClient = FakeCodexAppServerClient()
        ..resumeThreadReplayEventsByThreadId['thread_123'] =
            <CodexAppServerEvent>[replayedRequest];
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('First prompt'), isTrue);
      appServerClient.emit(replayedRequest);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.sessionState.pendingApprovalRequests.containsKey(
          'approval_1',
        ),
        isTrue,
      );

      await appServerClient.disconnect();
      await controller.reattachConversation('thread_123');
      await controller.approveRequest('approval_1');

      expect(
        appServerClient.approvalDecisions,
        <({String requestId, bool approved})>[
          (requestId: 'approval_1', approved: true),
        ],
      );
    },
  );
}
