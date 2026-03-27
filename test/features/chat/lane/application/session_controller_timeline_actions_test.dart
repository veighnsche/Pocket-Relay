import 'session_controller_test_support.dart';

void main() {
  test(
    'sendPrompt reselects the root timeline before sending from a child timeline',
    () async {
      final appServerClient = FakeCodexAppServerClient();
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
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{
              'id': 'thread_child',
              'agentNickname': 'Reviewer',
            },
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      controller.selectTimeline('thread_child');
      expect(controller.sessionState.currentThreadId, 'thread_child');

      expect(await controller.sendPrompt('Second prompt'), isTrue);

      expect(controller.sessionState.currentThreadId, 'thread_123');
      expect(appServerClient.sentMessages, <String>[
        'First prompt',
        'Second prompt',
      ]);
    },
  );

  test(
    'submitUserInput resolves a child-owned request even when another timeline is selected',
    () async {
      final appServerClient = FakeCodexAppServerClient();
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
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{
              'id': 'thread_child',
              'agentNickname': 'Reviewer',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerRequestEvent(
          requestId: 'input_child_1',
          method: 'item/tool/requestUserInput',
          params: <String, Object?>{
            'threadId': 'thread_child',
            'turnId': 'turn_child_1',
            'itemId': 'item_child_1',
            'questions': <Object?>[
              <String, Object?>{
                'id': 'q1',
                'header': 'Name',
                'question': 'What is your name?',
              },
            ],
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(controller.sessionState.currentThreadId, 'thread_123');
      expect(
        controller.sessionState.requestOwnerById['input_child_1'],
        'thread_child',
      );

      await controller.submitUserInput(
        'input_child_1',
        const <String, List<String>>{
          'q1': <String>['Vince'],
        },
      );

      expect(
        appServerClient.userInputResponses,
        <({String requestId, Map<String, List<String>> answers})>[
          (
            requestId: 'input_child_1',
            answers: const <String, List<String>>{
              'q1': <String>['Vince'],
            },
          ),
        ],
      );
    },
  );

  test('hydrates missing child thread metadata through thread/read', () async {
    final appServerClient = FakeCodexAppServerClient()
      ..threadsById['thread_child'] = const CodexAppServerThreadSummary(
        id: 'thread_child',
        name: 'Review Branch',
        agentNickname: 'Reviewer',
        agentRole: 'Code review',
        sourceKind: 'spawned',
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

    expect(await controller.sendPrompt('First prompt'), isTrue);
    appServerClient.emit(
      const CodexAppServerNotificationEvent(
        method: 'thread/started',
        params: <String, Object?>{
          'thread': <String, Object?>{'id': 'thread_child'},
        },
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final entry = controller.sessionState.threadRegistry['thread_child'];
    expect(appServerClient.readThreadCalls, contains('thread_child'));
    expect(entry?.threadName, 'Review Branch');
    expect(entry?.agentNickname, 'Reviewer');
    expect(entry?.agentRole, 'Code review');
    expect(entry?.sourceKind, 'spawned');
  });

  test(
    'stopActiveTurn targets the selected timeline turn explicitly',
    () async {
      final appServerClient = FakeCodexAppServerClient();
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
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'thread/started',
          params: <String, Object?>{
            'thread': <String, Object?>{
              'id': 'thread_child',
              'agentNickname': 'Reviewer',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/started',
          params: <String, Object?>{
            'threadId': 'thread_child',
            'turn': <String, Object?>{
              'id': 'turn_child_1',
              'status': 'running',
            },
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      controller.selectTimeline('thread_child');
      await controller.stopActiveTurn();

      expect(
        appServerClient.abortTurnCalls,
        <({String? threadId, String? turnId})>[
          (threadId: 'thread_child', turnId: 'turn_child_1'),
        ],
      );
    },
  );
}
