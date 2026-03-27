import 'session_controller_test_support.dart';

void main() {
  test(
    'branchSelectedConversation forks the selected conversation and restores the forked history',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        )
        ..forkThreadId = 'thread_forked'
        ..threadHistoriesById['thread_forked'] = savedConversationThread(
          threadId: 'thread_forked',
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

      final branched = await controller.branchSelectedConversation();

      expect(branched, isTrue);
      expect(appServerClient.forkThreadRequests.single, (
        threadId: 'thread_saved',
        path: null,
        cwd: null,
        model: null,
        modelProvider: null,
        ephemeral: null,
        persistExtendedHistory: true,
      ));
      expect(appServerClient.readThreadCalls.last, 'thread_forked');
      expect(controller.sessionState.rootThreadId, 'thread_forked');
      expect(controller.sessionState.currentThreadId, 'thread_forked');
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        <String>['Restore this', 'Second prompt'],
      );
    },
  );

  test(
    'branchSelectedConversation refuses to fork while a turn is active',
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

      final branched = await controller.branchSelectedConversation();

      expect(branched, isFalse);
      expect(appServerClient.forkThreadRequests, isEmpty);
    },
  );

  test(
    'branchSelectedConversation keeps the transcript intact and reports feedback when fork fails',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        )
        ..forkThreadError = StateError('fork broke');
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
      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      final branched = await controller.branchSelectedConversation();

      expect(branched, isFalse);
      expect(appServerClient.forkThreadRequests, isEmpty);
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        originalUserTexts,
      );
      expect(
        await snackBarMessage,
        '[${PocketErrorCatalog.chatSessionBranchConversationFailed.code}] Branch conversation failed. Could not branch this conversation from Codex.',
      );
    },
  );
}
