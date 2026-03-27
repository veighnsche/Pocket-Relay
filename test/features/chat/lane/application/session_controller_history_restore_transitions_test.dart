import 'session_controller_test_support.dart';

void main() {
  test(
    'sendPrompt resumes the restored conversation after selectConversationForResume',
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

      expect(
        await controller.sendPrompt('Continue restored conversation'),
        isTrue,
      );
      expect(appServerClient.startSessionCalls, 1);
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        'thread_saved',
      );
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
          threadId: 'thread_saved',
          input: const CodexAppServerTurnInput.text(
            'Continue restored conversation',
          ),
          text: 'Continue restored conversation',
          model: null,
          effort: null,
        ),
      ]);
    },
  );

  test(
    'selectConversationForResume exposes restore loading while transcript history is still in flight',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        )
        ..readThreadWithTurnsGate = Completer<void>();
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

      final loadingReached = Completer<void>();
      controller.addListener(() {
        if (controller.historicalConversationRestoreState?.phase ==
                ChatHistoricalConversationRestorePhase.loading &&
            !loadingReached.isCompleted) {
          loadingReached.complete();
        }
      });

      final restoreFuture = controller.selectConversationForResume(
        'thread_saved',
      );
      await loadingReached.future.timeout(const Duration(seconds: 1));

      expect(
        controller.historicalConversationRestoreState?.phase,
        ChatHistoricalConversationRestorePhase.loading,
      );
      expect(await controller.sendPrompt('blocked while restoring'), isFalse);

      appServerClient.readThreadWithTurnsGate!.complete();
      await restoreFuture;

      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'the latest explicit history selection wins if an earlier restore completes later',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_old'] = savedConversationThread(
          threadId: 'thread_old',
        )
        ..threadHistoriesById['thread_new'] = savedConversationThread(
          threadId: 'thread_new',
        )
        ..readThreadWithTurnsGatesByThreadId['thread_old'] = Completer<void>()
        ..readThreadWithTurnsGatesByThreadId['thread_new'] = Completer<void>();
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

      final firstRestore = controller.selectConversationForResume('thread_old');
      await Future<void>.delayed(Duration.zero);

      final secondRestore = controller.selectConversationForResume(
        'thread_new',
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.historicalConversationRestoreState?.threadId,
        'thread_new',
      );

      appServerClient.readThreadWithTurnsGatesByThreadId['thread_new']!
          .complete();
      await secondRestore;

      expect(controller.sessionState.rootThreadId, 'thread_new');
      expect(controller.historicalConversationRestoreState, isNull);

      appServerClient.readThreadWithTurnsGatesByThreadId['thread_old']!
          .complete();
      await firstRestore;

      expect(controller.sessionState.rootThreadId, 'thread_new');
      expect(controller.historicalConversationRestoreState, isNull);
    },
  );

  test(
    'selectConversationForResume surfaces a coded runtime error when transcript loading fails',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..readThreadWithTurnsError = StateError('history backend unavailable');
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

      await controller.selectConversationForResume('thread_saved');

      expect(
        controller.historicalConversationRestoreState?.phase,
        ChatHistoricalConversationRestorePhase.failed,
      );
      final runtimeErrors = controller.transcriptBlocks
          .whereType<CodexErrorBlock>()
          .toList(growable: false);
      expect(runtimeErrors, hasLength(1));
      expect(
        runtimeErrors.single.body,
        contains(
          '[${PocketErrorCatalog.chatSessionConversationLoadFailed.code}]',
        ),
      );
      expect(
        runtimeErrors.single.body,
        contains('history backend unavailable'),
      );
      expect(
        await snackBarMessage,
        '[${PocketErrorCatalog.chatSessionConversationLoadFailed.code}] Conversation load failed. Could not load the saved conversation transcript.',
      );
    },
  );

  test(
    'startFreshConversation invalidates an in-flight history restore',
    () async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        )
        ..readThreadWithTurnsGatesByThreadId['thread_saved'] =
            Completer<void>();
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

      final restoreFuture = controller.selectConversationForResume(
        'thread_saved',
      );
      await Future<void>.delayed(Duration.zero);

      controller.startFreshConversation();

      expect(controller.historicalConversationRestoreState, isNull);
      expect(controller.sessionState.rootThreadId, isNull);

      appServerClient.readThreadWithTurnsGatesByThreadId['thread_saved']!
          .complete();
      await restoreFuture;

      expect(controller.historicalConversationRestoreState, isNull);
      expect(controller.sessionState.rootThreadId, isNull);

      expect(
        await controller.sendPrompt('Fresh after cancelled restore'),
        isTrue,
      );
      expect(
        appServerClient.startSessionRequests.single.resumeThreadId,
        isNull,
      );
    },
  );

  test(
    'startFreshConversation refuses to reset while a turn is active',
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

      expect(await controller.sendPrompt('Keep running'), isTrue);
      final originalRootThreadId = controller.sessionState.rootThreadId;
      final originalUserTexts = controller.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .map((block) => block.text)
          .toList(growable: false);
      final snackBarMessage = controller.snackBarMessages.first.timeout(
        const Duration(seconds: 1),
      );

      controller.startFreshConversation();

      expect(controller.sessionState.rootThreadId, originalRootThreadId);
      expect(
        controller.transcriptBlocks.whereType<CodexUserMessageBlock>().map(
          (block) => block.text,
        ),
        originalUserTexts,
      );
      expect(
        controller.transcriptBlocks.whereType<CodexStatusBlock>(),
        isEmpty,
      );
      expect(
        await snackBarMessage,
        'Stop the active turn before starting a new thread.',
      );
    },
  );
}
