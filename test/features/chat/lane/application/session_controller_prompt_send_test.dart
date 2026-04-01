import 'session_controller_test_support.dart';

void main() {
  test('sendPrompt runs session flow without ChatScreen', () async {
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

    final sent = await controller.sendPrompt('Hello controller');

    expect(sent, isTrue);
    expect(appServerClient.connectCalls, 1);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.startSessionRequests.single.model, isNull);
    expect(appServerClient.startSessionRequests.single.reasoningEffort, isNull);
    expect(appServerClient.sentMessages, <String>['Hello controller']);
    expect(controller.transcriptBlocks.length, 1);
    expect(
      controller.transcriptBlocks.first,
      isA<TranscriptUserMessageBlock>(),
    );
    expect(controller.sessionState.headerMetadata.cwd, '/workspace');
    expect(controller.sessionState.headerMetadata.model, 'gpt-5.3-codex');
    final messageBlock =
        controller.transcriptBlocks.first as TranscriptUserMessageBlock;
    expect(messageBlock.text, 'Hello controller');
    expect(messageBlock.deliveryState, TranscriptUserMessageDeliveryState.sent);
  });

  test('sendPrompt allows steering while a turn is already running', () async {
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

    final sentWhileRunning = await controller.sendPrompt('Steer the agent');

    expect(sentWhileRunning, isTrue);
    expect(appServerClient.startSessionCalls, 1);
    expect(appServerClient.sentMessages, <String>[
      'First prompt',
      'Steer the agent',
    ]);
  });

  test(
    'sendPrompt starts a fresh conversation after controller restart until history is explicitly picked',
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

      expect(await controller.sendPrompt('Continue after restart'), isTrue);
      expect(appServerClient.startSessionCalls, 1);
      expect(appServerClient.sentTurns, <
        ({
          String threadId,
          CodexAppServerTurnInput input,
          String text,
          String? model,
          CodexReasoningEffort? effort,
        })
      >[
        (
          threadId: 'thread_123',
          input: const CodexAppServerTurnInput.text('Continue after restart'),
          text: 'Continue after restart',
          model: null,
          effort: null,
        ),
      ]);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        isNull,
      );
    },
  );
}
