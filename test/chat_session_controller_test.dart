import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/models/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

import 'support/fake_codex_app_server_client.dart';

void main() {
  test('sendPrompt runs session flow without ChatScreen', () async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    final controller = ChatSessionController(
      profileStore: MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      ),
      appServerClient: appServerClient,
      initialSavedProfile: SavedProfile(
        profile: _configuredProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
      ),
    );
    addTearDown(controller.dispose);

    final sent = await controller.sendPrompt('Hello controller');

    expect(sent, isTrue);
    expect(appServerClient.connectCalls, 1);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.startSessionRequests.single.model, isNull);
    expect(appServerClient.startSessionRequests.single.reasoningEffort, isNull);
    expect(appServerClient.sentMessages, <String>['Hello controller']);
    expect(controller.transcriptBlocks.length, 1);
    expect(controller.transcriptBlocks.first, isA<CodexUserMessageBlock>());
    final messageBlock =
        controller.transcriptBlocks.first as CodexUserMessageBlock;
    expect(messageBlock.text, 'Hello controller');
    expect(messageBlock.deliveryState, CodexUserMessageDeliveryState.sent);
  });

  test(
    'sendPrompt resumes the saved conversation handoff after controller restart',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      final conversationStateStore = _RecordingConversationHistoryStore(
        initialState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_saved',
        ),
      );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        conversationStateStore: conversationStateStore,
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
        initialConversationState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_saved',
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('Continue after restart'), isTrue);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentTurns, <
        ({
          String threadId,
          String text,
          String? model,
          CodexReasoningEffort? effort,
        })
      >[
        (
          threadId: 'thread_saved',
          text: 'Continue after restart',
          model: null,
          effort: null,
        ),
      ]);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        'thread_saved',
      );
      expect(
        (await conversationStateStore.loadState()).normalizedSelectedThreadId,
        'thread_saved',
      );
    },
  );

  test(
    'sendPrompt records selected thread id by thread id',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      final historyStore = _RecordingConversationHistoryStore(
        initialState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_123',
        ),
      );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        conversationStateStore: historyStore,
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('Second prompt'), isTrue);

      expect(historyStore.state.normalizedSelectedThreadId, 'thread_123');
    },
  );

  test(
    'sendPrompt forwards profile model and reasoning effort overrides',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final configuredProfile = _configuredProfile().copyWith(
        model: 'gpt-5.4',
        reasoningEffort: CodexReasoningEffort.high,
      );
      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: configuredProfile,
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: configuredProfile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('Use the configured model'), isTrue);
      expect(appServerClient.startSessionRequests.single.model, 'gpt-5.4');
      expect(
        appServerClient.startSessionRequests.single.reasoningEffort,
        CodexReasoningEffort.high,
      );
      expect(appServerClient.sentTurns.single.model, 'gpt-5.4');
      expect(
        appServerClient.sentTurns.single.effort,
        CodexReasoningEffort.high,
      );
    },
  );

  test('invalid prompt submission emits snackbar feedback', () async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    final controller = ChatSessionController(
      profileStore: MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(),
        ),
      ),
      appServerClient: appServerClient,
      initialSavedProfile: SavedProfile(
        profile: _configuredProfile(),
        secrets: const ConnectionSecrets(),
      ),
    );
    addTearDown(controller.dispose);

    final snackBarMessage = controller.snackBarMessages.first.timeout(
      const Duration(seconds: 1),
    );

    final sent = await controller.sendPrompt('Needs credentials');

    expect(sent, isFalse);
    expect(await snackBarMessage, 'This profile needs an SSH password.');
    expect(appServerClient.sentMessages, isEmpty);
  });

  test(
    'local mode is rejected when desktop-local support is unavailable',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final localProfile = _configuredProfile().copyWith(
        connectionMode: ConnectionMode.local,
        host: '',
        username: '',
      );
      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: localProfile,
            secrets: const ConnectionSecrets(),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: localProfile,
          secrets: const ConnectionSecrets(),
        ),
        supportsLocalConnectionMode: false,
      );
      addTearDown(controller.dispose);

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final sent = await controller.sendPrompt('Hello local');

      expect(sent, isFalse);
      expect(
        await snackBarMessage,
        'Local Codex is only available on desktop.',
      );
      expect(appServerClient.connectCalls, 0);
    },
  );

  test(
    'sendPrompt clears local prompt correlation state when sending fails before a turn starts',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..sendUserMessageError = StateError('transport broke');
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final sent = await controller.sendPrompt('Hello controller');

      expect(sent, isFalse);
      expect(controller.transcriptBlocks.first, isA<CodexUserMessageBlock>());
      expect(controller.sessionState.pendingLocalUserMessageBlockIds, isEmpty);
      expect(controller.sessionState.localUserMessageProviderBindings, isEmpty);
      expect(
        await snackBarMessage,
        'Could not send the prompt to the remote Codex session.',
      );
    },
  );

  test(
    'sendPrompt reuses the response-owned thread before thread notifications arrive',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
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
      await Future<void>.delayed(Duration.zero);

      expect(await controller.sendPrompt('Second prompt'), isTrue);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentMessages, <String>[
        'First prompt',
        'Second prompt',
      ]);
    },
  );

  test(
    'sendPrompt stays blocked after missing conversation recovery becomes active',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
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
      await Future<void>.delayed(Duration.zero);
      appServerClient.sendUserMessageError = const CodexAppServerException(
        'turn/start failed: thread not found',
      );

      expect(await controller.sendPrompt('Second prompt'), isFalse);
      expect(
        controller.conversationRecoveryState?.reason,
        ChatConversationRecoveryReason.missingRemoteConversation,
      );

      appServerClient.sendUserMessageError = null;

      expect(await controller.sendPrompt('Third prompt'), isFalse);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentMessages, <String>['First prompt']);
    },
  );

  test(
    'sendPrompt surfaces a missing conversation explicitly instead of silently starting fresh',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
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
      await Future<void>.delayed(Duration.zero);
      appServerClient.sendUserMessageError = const CodexAppServerException(
        'turn/start failed: thread not found',
      );

      final sent = await controller.sendPrompt('Second prompt');

      expect(sent, isFalse);
      expect(appServerClient.startSessionCalls, 1);
      expect(
        controller.conversationRecoveryState?.reason,
        ChatConversationRecoveryReason.missingRemoteConversation,
      );
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        <String>['First prompt', 'Second prompt'],
      );
      expect(
        controller.transcriptBlocks.whereType<CodexErrorBlock>().last.body,
        'Could not continue this conversation because the remote conversation was not found. Start a fresh conversation to continue.',
      );
    },
  );

  test(
    'sendPrompt surfaces an explicit recovery state when thread/resume returns a different thread id',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..startSessionError = const CodexAppServerException(
          'thread/resume returned a different thread id than requested.',
          data: <String, Object?>{
            'expectedThreadId': 'thread_old',
            'actualThreadId': 'thread_new',
          },
        );
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
        initialConversationState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_old',
        ),
      );
      addTearDown(controller.dispose);

      final sent = await controller.sendPrompt('Second prompt');

      expect(sent, isFalse);
      expect(
        controller.conversationRecoveryState?.reason,
        ChatConversationRecoveryReason.unexpectedRemoteConversation,
      );
      expect(
        controller.conversationRecoveryState?.expectedThreadId,
        'thread_old',
      );
      expect(
        controller.conversationRecoveryState?.actualThreadId,
        'thread_new',
      );
      expect(
        controller.transcriptBlocks.whereType<CodexErrorBlock>().last.body,
        'Pocket Relay expected remote conversation "thread_old", but the remote session returned "thread_new". Sending is blocked to avoid attaching your draft to a different conversation.',
      );
    },
  );

  test(
    'startFreshConversation clears the response-owned resume thread',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
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
      await Future<void>.delayed(Duration.zero);

      controller.startFreshConversation();

      expect(await controller.sendPrompt('Second prompt'), isTrue);
      expect(appServerClient.startSessionCalls, 2);
    },
  );

  test(
    'clearTranscript prevents reusing a previously tracked live thread',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
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
      await Future<void>.delayed(Duration.zero);
      controller.clearTranscript();

      expect(await controller.sendPrompt('Second prompt'), isTrue);
      expect(appServerClient.startSessionCalls, 2);
    },
  );

  test(
    'sendPrompt reselects the root timeline before sending from a child timeline',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
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
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
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
      ..threadsById['thread_child'] = const CodexAppServerThread(
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
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      ),
      appServerClient: appServerClient,
      initialSavedProfile: SavedProfile(
        profile: _configuredProfile(),
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
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
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

  test(
    'saveObservedHostFingerprint persists the prompt without disconnecting the active session',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);
      final profileStore = MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );

      final controller = ChatSessionController(
        profileStore: profileStore,
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      expect(await controller.sendPrompt('Hello controller'), isTrue);

      appServerClient.emit(
        const CodexAppServerUnpinnedHostKeyEvent(
          host: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: '7a:9f:d7:dc:2e:f2',
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final block = controller.transcriptBlocks
          .whereType<CodexSshUnpinnedHostKeyBlock>()
          .single;

      await controller.saveObservedHostFingerprint(block.id);

      expect(appServerClient.isConnected, isTrue);
      expect(controller.profile.hostFingerprint, '7a:9f:d7:dc:2e:f2');
      expect(
        (await profileStore.load()).profile.hostFingerprint,
        '7a:9f:d7:dc:2e:f2',
      );
      expect(
        controller.transcriptBlocks
            .whereType<CodexSshUnpinnedHostKeyBlock>()
            .single
            .isSaved,
        isTrue,
      );
    },
  );

  test(
    'sendPrompt suppresses duplicate generic transcript errors when SSH bootstrap already surfaced a typed failure',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..connectEventsBeforeThrow.add(
          const CodexAppServerSshConnectFailedEvent(
            host: 'example.com',
            port: 22,
            message: 'Connection refused',
          ),
        )
        ..connectError = StateError('connect failed after transport event');
      addTearDown(appServerClient.close);

      final controller = ChatSessionController(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: _configuredProfile(),
            secrets: const ConnectionSecrets(password: 'secret'),
          ),
        ),
        appServerClient: appServerClient,
        initialSavedProfile: SavedProfile(
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      );
      addTearDown(controller.dispose);

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final sent = await controller.sendPrompt('Hello controller');

      expect(sent, isFalse);
      final errors = controller.transcriptBlocks
          .whereType<CodexSshConnectFailedBlock>()
          .toList(growable: false);
      expect(errors, hasLength(1));
      expect(errors.single.message, contains('Connection refused'));
      expect(
        await snackBarMessage,
        'Could not send the prompt to the remote Codex session.',
      );
    },
  );
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    host: 'example.com',
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

class _RecordingConversationHistoryStore implements CodexConversationStateStore {
  _RecordingConversationHistoryStore({
    SavedConnectionConversationState? initialState,
  }) : state = initialState ?? const SavedConnectionConversationState();

  SavedConnectionConversationState state;

  @override
  Future<SavedConnectionConversationState> loadState() async {
    return state;
  }

  @override
  Future<void> saveState(SavedConnectionConversationState nextState) async {
    state = nextState;
  }
}
