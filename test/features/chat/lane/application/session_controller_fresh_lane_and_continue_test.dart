import 'session_controller_test_support.dart';

void main() {
  test(
    'initialize keeps a fresh lane empty until history is explicitly picked',
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

      await controller.initialize();

      expect(appServerClient.startSessionCalls, 0);
      expect(appServerClient.connectCalls, 0);
      expect(appServerClient.readThreadCalls, isEmpty);
      expect(controller.transcriptBlocks, isEmpty);
      expect(controller.sessionState.rootThreadId, isNull);
      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'sendPrompt stays fresh after initialize until history is explicitly picked',
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

      await controller.initialize();

      expect(
        await controller.sendPrompt('Continue restored startup lane'),
        isTrue,
      );
      expect(appServerClient.startSessionCalls, 1);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        isNull,
      );
      expect(appServerClient.sentTurns.single, (
        threadId: 'thread_123',
        input: const CodexAppServerTurnInput.text(
          'Continue restored startup lane',
        ),
        text: 'Continue restored startup lane',
        model: null,
        effort: null,
      ));
    },
  );

  test(
    'continueFromUserMessage rolls back the active conversation and returns the selected prompt text',
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

      await controller.initialize();
      await controller.selectConversationForResume('thread_saved');
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (b) => b.text,
        ),
        <String>['Restore this', 'Second prompt'],
      );

      appServerClient.threadHistoriesById['thread_saved'] =
          rewoundConversationThread(threadId: 'thread_saved');

      final selectedBlock = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .firstWhere((block) => block.text == 'Restore this');

      final draft = await controller.continueFromUserMessage(selectedBlock.id);

      expect(draft?.text, 'Restore this');
      expect(
        appServerClient.rollbackThreadCalls,
        <({String threadId, int numTurns})>[
          (threadId: 'thread_saved', numTurns: 2),
        ],
      );
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>(),
        isEmpty,
      );
      expect(
        controller.transcriptBlocks.whereType<CodexTextBlock>().map(
          (b) => b.body,
        ),
        <String>['Earlier answer only'],
      );
      expect(controller.sessionState.rootThreadId, 'thread_saved');
      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'continueFromUserMessage refuses to rewind while a turn is active',
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

      await controller.initialize();
      await controller.selectConversationForResume('thread_saved');
      expect(await controller.sendPrompt('Keep running'), isTrue);

      final selectedBlock = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .firstWhere((block) => block.text == 'Restore this');

      final draft = await controller.continueFromUserMessage(selectedBlock.id);

      expect(draft, isNull);
      expect(appServerClient.rollbackThreadCalls, isEmpty);
    },
  );

  test(
    'continueFromUserMessage keeps the transcript intact and reports feedback when rollback fails',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        )
        ..rollbackThreadError = StateError('transport broke');
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
      await controller.selectConversationForResume('thread_saved');
      final originalUserTexts = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .map((block) => block.text)
          .toList(growable: false);
      final originalAssistantTexts = controller.transcriptBlocks
          .whereType<CodexTextBlock>()
          .map((block) => block.body)
          .toList(growable: false);
      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final selectedBlock = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .firstWhere((block) => block.text == 'Restore this');

      final draft = await controller.continueFromUserMessage(selectedBlock.id);

      expect(draft, isNull);
      expect(
        appServerClient.rollbackThreadCalls,
        <({String threadId, int numTurns})>[
          (threadId: 'thread_saved', numTurns: 2),
        ],
      );
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        originalUserTexts,
      );
      expect(
        controller.transcriptBlocks.whereType<CodexTextBlock>().map(
          (block) => block.body,
        ),
        originalAssistantTexts,
      );
      expect(
        await snackBarMessage,
        '[${PocketErrorCatalog.chatSessionContinueFromPromptFailed.code}] Continue from prompt failed. Could not rewind this conversation to the selected prompt.',
      );
    },
  );

  test('continueFromUserMessage restores a structured image draft', () async {
    final appServerClient = FakeCodexAppServerClient()
      ..threadHistoriesById['thread_123'] = rewoundConversationThread(
        threadId: 'thread_123',
      );
    addTearDown(appServerClient.close);

    final profile = configuredProfile();
    final controller = ChatSessionController(
      profileStore: MemoryCodexProfileStore(
        initialValue: SavedProfile(
          profile: profile,
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      ),
      appServerClient: appServerClient,
      initialSavedProfile: SavedProfile(
        profile: profile,
        secrets: const ConnectionSecrets(password: 'secret'),
      ),
    );
    addTearDown(controller.dispose);

    expect(
      await controller.sendDraft(
        const ChatComposerDraft(
          text: 'See [Image #1]',
          textElements: <ChatComposerTextElement>[
            ChatComposerTextElement(
              start: 4,
              end: 14,
              placeholder: '[Image #1]',
            ),
          ],
          imageAttachments: <ChatComposerImageAttachment>[
            ChatComposerImageAttachment(
              imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
              displayName: 'reference.png',
              placeholder: '[Image #1]',
            ),
          ],
        ),
      ),
      isTrue,
    );

    final selectedBlock = controller.transcriptBlocks
        .whereType<CodexUserMessageBlock>()
        .single;
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

    final draft = await controller.continueFromUserMessage(selectedBlock.id);

    expect(
      draft,
      const ChatComposerDraft(
        text: 'See [Image #1]',
        textElements: <ChatComposerTextElement>[
          ChatComposerTextElement(start: 4, end: 14, placeholder: '[Image #1]'),
        ],
        imageAttachments: <ChatComposerImageAttachment>[
          ChatComposerImageAttachment(
            imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
            displayName: 'reference.png',
            placeholder: '[Image #1]',
          ),
        ],
      ),
    );
  });
}
