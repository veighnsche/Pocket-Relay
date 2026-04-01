import 'session_controller_test_support.dart';

void main() {
  test(
    'sendPrompt stays blocked after missing conversation recovery becomes active',
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
        controller.transcriptBlocks.whereType<TranscriptUserMessageBlock>().map(
          (block) => block.text,
        ),
        <String>['First prompt', 'Second prompt'],
      );
      expect(
        controller.transcriptBlocks.whereType<TranscriptErrorBlock>().last.body,
        '[${PocketErrorCatalog.chatSessionSendConversationUnavailable.code}] Conversation unavailable. Could not continue this conversation because the remote conversation was not found. Start a fresh conversation to continue.',
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
        controller.transcriptBlocks.whereType<TranscriptErrorBlock>().last.body,
        '[${PocketErrorCatalog.chatSessionSendConversationChanged.code}] Conversation changed. Pocket Relay expected remote conversation "thread_old", but the remote session returned "thread_new". Sending is blocked to avoid attaching your draft to a different conversation.',
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
      await Future<void>.delayed(Duration.zero);

      controller.startFreshConversation();

      expect(await controller.sendPrompt('Second prompt'), isTrue);
      expect(appServerClient.startSessionCalls, 2);
    },
  );

  test(
    'startFreshConversation clears the in-memory resume target before the next send',
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
      await Future<void>.delayed(Duration.zero);

      controller.startFreshConversation();

      expect(await controller.sendPrompt('Second prompt'), isTrue);
      expect(appServerClient.startSessionCalls, 2);
      expect(appServerClient.startSessionRequests.last.resumeThreadId, isNull);
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
      await Future<void>.delayed(Duration.zero);
      controller.clearTranscript();

      expect(await controller.sendPrompt('Second prompt'), isTrue);
      expect(appServerClient.startSessionCalls, 2);
    },
  );

  test('clearTranscript refuses to reset while a turn is active', () async {
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

    expect(await controller.sendPrompt('Keep running'), isTrue);
    final originalRootThreadId = controller.sessionState.rootThreadId;
    final originalUserTexts = controller.transcriptBlocks
        .whereType<TranscriptUserMessageBlock>()
        .map((block) => block.text)
        .toList(growable: false);
    final snackBarMessage = controller.snackBarMessages.first.timeout(
      const Duration(seconds: 1),
    );

    controller.clearTranscript();

    expect(controller.sessionState.rootThreadId, originalRootThreadId);
    expect(
      controller.transcriptBlocks.whereType<TranscriptUserMessageBlock>().map(
        (block) => block.text,
      ),
      originalUserTexts,
    );
    expect(
      await snackBarMessage,
      '[${PocketErrorCatalog.chatSessionClearTranscriptBlocked.code}] Clear transcript blocked. Stop the active turn before clearing the transcript.',
    );
  });
}
