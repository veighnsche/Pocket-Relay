import 'session_controller_test_support.dart';

void main() {
  test('invalid prompt submission emits snackbar feedback', () async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    final controller = ChatSessionController(
      profileStore: MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(),
        ),
      ),
      appServerClient: appServerClient,
      initialSavedProfile: SavedProfile(
        profile: configuredProfile(),
        secrets: const ConnectionSecrets(),
      ),
    );
    addTearDown(controller.dispose);

    final snackBarMessage = controller.snackBarMessages.first.timeout(
      const Duration(seconds: 1),
    );

    final sent = await controller.sendPrompt('Needs credentials');

    expect(sent, isFalse);
    expect(
      await snackBarMessage,
      '[${PocketErrorCatalog.chatSessionSshPasswordRequired.code}] Password required. This profile needs an SSH password.',
    );
    expect(appServerClient.sentMessages, isEmpty);
  });

  test(
    'local mode is rejected when desktop-local support is unavailable',
    () async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      final localProfile = configuredProfile().copyWith(
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
        '[${PocketErrorCatalog.chatSessionLocalModeUnsupported.code}] Local mode unavailable. Local agent adapters are only available on desktop.',
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

      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final sent = await controller.sendPrompt('Hello controller');

      expect(sent, isFalse);
      expect(
        controller.transcriptBlocks.first,
        isA<TranscriptUserMessageBlock>(),
      );
      expect(controller.sessionState.pendingLocalUserMessageBlockIds, isEmpty);
      expect(controller.sessionState.localUserMessageProviderBindings, isEmpty);
      final runtimeErrors = controller.transcriptBlocks
          .whereType<TranscriptErrorBlock>()
          .toList(growable: false);
      expect(runtimeErrors, hasLength(1));
      expect(
        runtimeErrors.single.body,
        contains('[${PocketErrorCatalog.chatSessionSendFailed.code}]'),
      );
      expect(
        await snackBarMessage,
        '[${PocketErrorCatalog.chatSessionSendFailed.code}] Send failed. Could not send the prompt to the remote Codex session.',
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

      expect(await controller.sendPrompt('Second prompt'), isTrue);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentMessages, <String>[
        'First prompt',
        'Second prompt',
      ]);
    },
  );

  test(
    'sendPrompt resumes the root thread after the transport drops the tracked thread',
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

      await appServerClient.disconnect();

      expect(await controller.sendPrompt('Resume after reconnect'), isTrue);
      expect(appServerClient.connectCalls, 2);
      expect(appServerClient.startSessionCalls, 2);
      expect(
        appServerClient.startSessionRequests.last.resumeThreadId,
        'thread_123',
      );
      expect(appServerClient.sentTurns.last, (
        threadId: 'thread_123',
        input: const CodexAppServerTurnInput.text('Resume after reconnect'),
        text: 'Resume after reconnect',
        model: null,
        effort: null,
      ));
    },
  );
}
