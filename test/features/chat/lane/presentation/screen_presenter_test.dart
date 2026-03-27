import '../../support/screen_presentation_test_support.dart';

void main() {
  group('ChatScreenPresenter', () {
    const presenter = ChatScreenPresenter();

    test(
      'derives header, actions, composer, and settings payload from raw top-level state',
      () {
        final profile = configuredProfile();
        final secrets = const ConnectionSecrets(password: 'secret');

        final contract = presenter.present(
          isLoading: false,
          profile: profile,
          secrets: secrets,
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: null,
          composerDraft: const ChatComposerDraft(),
          transcriptFollow: defaultTranscriptFollowContract,
        );

        expect(contract.header.title, 'Dev Box');
        expect(contract.header.subtitle, 'devbox.local');
        expect(
          contract.toolbarActions.map((action) => action.id),
          <ChatScreenActionId>[ChatScreenActionId.openSettings],
        );
        expect(
          contract.menuActions.map((action) => action.id),
          <ChatScreenActionId>[
            ChatScreenActionId.newThread,
            ChatScreenActionId.branchConversation,
            ChatScreenActionId.clearTranscript,
          ],
        );
        expect(contract.composer.draftText, isEmpty);
        expect(contract.composer.isSendActionEnabled, isTrue);
        expect(contract.composer.allowsImageAttachment, isTrue);
        expect(contract.connectionSettings.initialProfile, same(profile));
        expect(contract.connectionSettings.initialSecrets, same(secrets));
        expect(
          contract.transcriptFollow,
          same(defaultTranscriptFollowContract),
        );
      },
    );

    test('enables image attachment for configured lanes', () {
      final contract = presenter.present(
        isLoading: false,
        profile: configuredProfile().copyWith(
          connectionMode: ConnectionMode.local,
        ),
        secrets: const ConnectionSecrets(password: 'secret'),
        sessionState: CodexSessionState.initial(),
        conversationRecoveryState: null,
        composerDraft: const ChatComposerDraft(),
        transcriptFollow: defaultTranscriptFollowContract,
      );

      expect(contract.composer.allowsImageAttachment, isTrue);
    });

    test(
      'disables image attachment when the effective model metadata rejects image input',
      () {
        final contract = presenter.present(
          isLoading: false,
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: null,
          composerDraft: const ChatComposerDraft(),
          effectiveModelSupportsImages: false,
          transcriptFollow: defaultTranscriptFollowContract,
        );

        expect(contract.composer.allowsImageAttachment, isFalse);
      },
    );

    test('uses profile title and live Codex subtitle metadata', () {
      final sessionState = CodexSessionState.initial().copyWith(
        headerMetadata: const CodexSessionHeaderMetadata(
          cwd: r'C:\Users\vince\Projects\InfraServer',
          model: 'gpt-5.4',
          reasoningEffort: 'high',
        ),
      );

      final contract = presenter.present(
        isLoading: false,
        profile: configuredProfile().copyWith(
          workspaceDir: '/workspace/fallback_project',
          model: 'gpt-5.4-mini',
          reasoningEffort: CodexReasoningEffort.low,
        ),
        secrets: const ConnectionSecrets(password: 'secret'),
        sessionState: sessionState,
        conversationRecoveryState: null,
        composerDraft: const ChatComposerDraft(),
        transcriptFollow: defaultTranscriptFollowContract,
      );

      expect(contract.header.title, 'Dev Box');
      expect(contract.header.subtitle, 'devbox.local · gpt-5.4 · high effort');
    });

    test(
      'keeps send enabled and surfaces turn status when the session is busy',
      () {
        final activeTurn = CodexActiveTurnState(
          turnId: 'turn_1',
          timer: CodexSessionTurnTimer(
            turnId: 'turn_1',
            startedAt: DateTime(2026, 3, 15, 12),
          ),
        );
        final sessionState = CodexSessionState.initial()
            .copyWith(connectionStatus: CodexRuntimeSessionState.running)
            .copyWithProjectedTranscript(activeTurn: activeTurn);

        final contract = presenter.present(
          isLoading: false,
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: sessionState,
          conversationRecoveryState: null,
          composerDraft: const ChatComposerDraft(text: 'Keep draft'),
          transcriptFollow: defaultTranscriptFollowContract,
        );

        expect(contract.composer.draftText, 'Keep draft');
        expect(contract.composer.isSendActionEnabled, isTrue);
        expect(contract.turnIndicator?.timer, same(activeTurn.timer));
      },
    );

    test('disables conversation reset actions while the session is busy', () {
      final activeTurn = CodexActiveTurnState(
        turnId: 'turn_1',
        timer: CodexSessionTurnTimer(
          turnId: 'turn_1',
          startedAt: DateTime(2026, 3, 15, 12),
        ),
      );
      final sessionState = CodexSessionState.initial()
          .copyWith(connectionStatus: CodexRuntimeSessionState.running)
          .copyWithProjectedTranscript(activeTurn: activeTurn);

      final contract = presenter.present(
        isLoading: false,
        profile: configuredProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        sessionState: sessionState,
        conversationRecoveryState: null,
        composerDraft: const ChatComposerDraft(text: 'Keep draft'),
        transcriptFollow: defaultTranscriptFollowContract,
      );

      final actionsById = <ChatScreenActionId, ChatScreenActionContract>{
        for (final action in contract.menuActions) action.id: action,
      };
      expect(actionsById[ChatScreenActionId.newThread]?.isEnabled, isFalse);
      expect(
        actionsById[ChatScreenActionId.branchConversation]?.isEnabled,
        isFalse,
      );
      expect(
        actionsById[ChatScreenActionId.clearTranscript]?.isEnabled,
        isFalse,
      );
    });

    test(
      'disables send and exposes recovery actions when conversation recovery is active',
      () {
        final contract = presenter.present(
          isLoading: false,
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: const ChatConversationRecoveryState(
            reason: ChatConversationRecoveryReason.missingRemoteConversation,
          ),
          composerDraft: const ChatComposerDraft(text: 'Keep draft'),
          transcriptFollow: defaultTranscriptFollowContract,
        );

        expect(contract.composer.draftText, 'Keep draft');
        expect(contract.composer.isSendActionEnabled, isFalse);
        expect(
          contract.conversationRecoveryNotice?.title,
          "This conversation can't continue.",
        );
        expect(
          contract.conversationRecoveryNotice?.actions.map(
            (action) => action.id,
          ),
          <ChatConversationRecoveryActionId>[
            ChatConversationRecoveryActionId.startFreshConversation,
          ],
        );
      },
    );

    test(
      'renders explicit thread ids when the remote session changes conversation identity',
      () {
        final contract = presenter.present(
          isLoading: false,
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: const ChatConversationRecoveryState(
            reason: ChatConversationRecoveryReason.unexpectedRemoteConversation,
            expectedThreadId: 'thread_old',
            actualThreadId: 'thread_new',
          ),
          composerDraft: const ChatComposerDraft(text: 'Keep draft'),
          transcriptFollow: defaultTranscriptFollowContract,
        );

        expect(
          contract.conversationRecoveryNotice?.title,
          'Conversation identity changed.',
        );
        expect(
          contract.conversationRecoveryNotice?.message,
          'Pocket Relay expected thread "thread_old", but the remote session returned "thread_new". Sending is blocked because that would attach your draft to a different conversation.',
        );
        expect(contract.composer.isSendActionEnabled, isFalse);
      },
    );

    test(
      'disables send and exposes retry actions when historical transcript restore is unavailable',
      () {
        final contract = presenter.present(
          isLoading: false,
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: null,
          historicalConversationRestoreState:
              const ChatHistoricalConversationRestoreState(
                threadId: 'thread_saved',
                phase: ChatHistoricalConversationRestorePhase.unavailable,
              ),
          composerDraft: const ChatComposerDraft(text: 'Keep draft'),
          transcriptFollow: defaultTranscriptFollowContract,
        );

        expect(contract.composer.draftText, 'Keep draft');
        expect(contract.composer.isSendActionEnabled, isFalse);
        expect(
          contract.historicalConversationRestoreNotice?.title,
          'Transcript history unavailable',
        );
        expect(
          contract.historicalConversationRestoreNotice?.actions.map(
            (action) => action.id,
          ),
          <ChatHistoricalConversationRestoreActionId>[
            ChatHistoricalConversationRestoreActionId.retryRestore,
            ChatHistoricalConversationRestoreActionId.startFreshConversation,
          ],
        );
      },
    );

    test('projects ordered timeline summaries for workspace mode', () {
      final sessionState = CodexSessionState.initial().copyWith(
        rootThreadId: 'thread_root',
        selectedThreadId: 'thread_child',
        timelinesByThreadId: <String, CodexTimelineState>{
          'thread_root': const CodexTimelineState(
            threadId: 'thread_root',
            lifecycleState: CodexAgentLifecycleState.idle,
          ),
          'thread_child': const CodexTimelineState(
            threadId: 'thread_child',
            lifecycleState: CodexAgentLifecycleState.blockedOnApproval,
            hasUnreadActivity: true,
          ),
        },
        threadRegistry: const <String, CodexThreadRegistryEntry>{
          'thread_root': CodexThreadRegistryEntry(
            threadId: 'thread_root',
            displayOrder: 0,
            isPrimary: true,
          ),
          'thread_child': CodexThreadRegistryEntry(
            threadId: 'thread_child',
            displayOrder: 1,
            agentNickname: 'Reviewer',
          ),
        },
      );

      final contract = presenter.present(
        isLoading: false,
        profile: configuredProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        sessionState: sessionState,
        conversationRecoveryState: null,
        composerDraft: const ChatComposerDraft(),
        transcriptFollow: defaultTranscriptFollowContract,
      );

      expect(contract.timelineSummaries, hasLength(2));
      expect(
        contract.timelineSummaries.map((summary) => summary.label),
        <String>['Main', 'Reviewer'],
      );
      expect(contract.timelineSummaries[0].isSelected, isFalse);
      expect(contract.timelineSummaries[1].isSelected, isTrue);
      expect(
        contract.timelineSummaries[1].status,
        CodexAgentLifecycleState.blockedOnApproval,
      );
      expect(contract.timelineSummaries[1].hasUnreadActivity, isTrue);
    });

    test(
      'uses a preferred empty-state connection mode without treating the profile as configured',
      () {
        final profile = ConnectionProfile.defaults();

        final contract = presenter.present(
          isLoading: false,
          profile: profile,
          secrets: const ConnectionSecrets(),
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: null,
          composerDraft: const ChatComposerDraft(),
          transcriptFollow: defaultTranscriptFollowContract,
          preferredConnectionMode: ConnectionMode.local,
        );

        expect(
          contract.transcriptSurface.emptyState?.connectionMode,
          ConnectionMode.local,
        );
        expect(
          contract.connectionSettings.initialProfile.connectionMode,
          ConnectionMode.local,
        );
        expect(contract.transcriptSurface.isConfigured, isFalse);
        expect(contract.composer.isSendActionEnabled, isFalse);
      },
    );
  });
}
