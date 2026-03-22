import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft_host.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_projector.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_projector.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_effect.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_effect_mapper.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_presenter.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_host.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_projector.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_surface_projector.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

const _defaultTranscriptFollowContract = ChatTranscriptFollowContract(
  isAutoFollowEnabled: true,
  resumeDistance: ChatTranscriptFollowHost.defaultResumeDistance,
);

void main() {
  group('ChatScreenPresenter', () {
    const presenter = ChatScreenPresenter();

    test(
      'derives header, actions, composer, and settings payload from raw top-level state',
      () {
        final profile = _configuredProfile();
        final secrets = const ConnectionSecrets(password: 'secret');

        final contract = presenter.present(
          isLoading: false,
          profile: profile,
          secrets: secrets,
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: null,
          composerDraft: const ChatComposerDraft(),
          transcriptFollow: _defaultTranscriptFollowContract,
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
        expect(contract.connectionSettings.initialProfile, same(profile));
        expect(contract.connectionSettings.initialSecrets, same(secrets));
        expect(
          contract.transcriptFollow,
          same(_defaultTranscriptFollowContract),
        );
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
        profile: _configuredProfile().copyWith(
          workspaceDir: '/workspace/fallback_project',
          model: 'gpt-5.4-mini',
          reasoningEffort: CodexReasoningEffort.low,
        ),
        secrets: const ConnectionSecrets(password: 'secret'),
        sessionState: sessionState,
        conversationRecoveryState: null,
        composerDraft: const ChatComposerDraft(),
        transcriptFollow: _defaultTranscriptFollowContract,
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
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: sessionState,
          conversationRecoveryState: null,
          composerDraft: const ChatComposerDraft(text: 'Keep draft'),
          transcriptFollow: _defaultTranscriptFollowContract,
        );

        expect(contract.composer.draftText, 'Keep draft');
        expect(contract.composer.isSendActionEnabled, isTrue);
        expect(contract.turnIndicator?.timer, same(activeTurn.timer));
      },
    );

    test(
      'disables send and exposes recovery actions when conversation recovery is active',
      () {
        final contract = presenter.present(
          isLoading: false,
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: const ChatConversationRecoveryState(
            reason: ChatConversationRecoveryReason.missingRemoteConversation,
          ),
          composerDraft: const ChatComposerDraft(text: 'Keep draft'),
          transcriptFollow: _defaultTranscriptFollowContract,
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
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: const ChatConversationRecoveryState(
            reason: ChatConversationRecoveryReason.unexpectedRemoteConversation,
            expectedThreadId: 'thread_old',
            actualThreadId: 'thread_new',
          ),
          composerDraft: const ChatComposerDraft(text: 'Keep draft'),
          transcriptFollow: _defaultTranscriptFollowContract,
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
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: null,
          historicalConversationRestoreState:
              const ChatHistoricalConversationRestoreState(
                threadId: 'thread_saved',
                phase: ChatHistoricalConversationRestorePhase.unavailable,
              ),
          composerDraft: const ChatComposerDraft(text: 'Keep draft'),
          transcriptFollow: _defaultTranscriptFollowContract,
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
        profile: _configuredProfile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        sessionState: sessionState,
        conversationRecoveryState: null,
        composerDraft: const ChatComposerDraft(),
        transcriptFollow: _defaultTranscriptFollowContract,
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
          transcriptFollow: _defaultTranscriptFollowContract,
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

  group('ChatTranscriptSurfaceProjector', () {
    const projector = ChatTranscriptSurfaceProjector();

    test(
      'projects transcript blocks into the main region and pending requests into the pinned region',
      () {
        final transcriptBlock = CodexTextBlock(
          id: 'assistant_1',
          kind: CodexUiBlockKind.assistantMessage,
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Codex',
          body: 'Hello',
        );
        final activeTurn = CodexActiveTurnState(
          turnId: 'turn_1',
          timer: CodexSessionTurnTimer(
            turnId: 'turn_1',
            startedAt: DateTime(2026, 3, 15, 12),
          ),
          pendingApprovalRequests: <String, CodexSessionPendingRequest>{
            'request_1': CodexSessionPendingRequest(
              requestId: 'request_1',
              requestType: CodexCanonicalRequestType.fileChangeApproval,
              createdAt: DateTime(2026, 3, 15, 12, 0, 1),
              detail: 'Approve file change',
            ),
          },
          pendingUserInputRequests:
              <String, CodexSessionPendingUserInputRequest>{
                'request_2': CodexSessionPendingUserInputRequest(
                  requestId: 'request_2',
                  requestType: CodexCanonicalRequestType.toolUserInput,
                  createdAt: DateTime(2026, 3, 15, 12, 0, 2),
                  detail: 'Need extra info',
                ),
              },
        );
        final sessionState = CodexSessionState.initial()
            .copyWithProjectedTranscript(
              activeTurn: activeTurn,
              blocks: <CodexUiBlock>[transcriptBlock],
            );

        final surface = projector.project(
          profile: _configuredProfile(),
          sessionState: sessionState,
        );

        expect(surface.emptyState, isNull);
        expect(
          surface.mainItems.single,
          isA<ChatAssistantMessageItemContract>(),
        );
        expect(
          (surface.mainItems.single as ChatAssistantMessageItemContract).block,
          same(transcriptBlock),
        );
        expect(surface.pinnedItems.length, 2);
        expect(
          surface.pinnedItems.first,
          isA<ChatApprovalRequestItemContract>(),
        );
        expect(
          (surface.pinnedItems.first as ChatApprovalRequestItemContract)
              .request
              .title,
          'File change approval',
        );
        expect(
          surface.pinnedItems.last,
          isA<ChatUserInputRequestItemContract>(),
        );
        expect(
          (surface.pinnedItems.last as ChatUserInputRequestItemContract)
              .request
              .body,
          'Need extra info',
        );
        expect(
          surface.pendingRequestPlacement.visibleApprovalRequest?.requestId,
          'request_1',
        );
        expect(
          surface.pendingRequestPlacement.visibleUserInputRequest?.requestId,
          'request_2',
        );
        expect(surface.activePendingUserInputRequestIds, <String>{'request_2'});
      },
    );

    test('limits the main transcript projection to the newest window', () {
      final projector = ChatTranscriptSurfaceProjector(
        mainTranscriptItemLimit: 3,
      );
      final transcriptBlocks = List<CodexUiBlock>.generate(
        5,
        (index) => CodexTextBlock(
          id: 'assistant_$index',
          kind: CodexUiBlockKind.assistantMessage,
          createdAt: DateTime(2026, 3, 15, 12, 0, index),
          title: 'Codex',
          body: 'Assistant message $index',
        ),
      );
      final sessionState = CodexSessionState.initial()
          .copyWithProjectedTranscript(blocks: transcriptBlocks);

      final surface = projector.project(
        profile: _configuredProfile(),
        sessionState: sessionState,
      );

      expect(surface.totalMainItemCount, 5);
      expect(surface.visibleMainItemCount, 3);
      expect(surface.hiddenOlderMainItemCount, 2);
      expect(
        surface.mainItems
            .map((item) => (item as ChatAssistantMessageItemContract).block.id)
            .toList(growable: false),
        <String>['assistant_2', 'assistant_3', 'assistant_4'],
      );
    });

    test(
      'keeps active pending user-input ids limited to the visible request when multiple pending inputs exist',
      () {
        final activeTurn = CodexActiveTurnState(
          turnId: 'turn_1',
          timer: CodexSessionTurnTimer(
            turnId: 'turn_1',
            startedAt: DateTime(2026, 3, 15, 12),
          ),
          pendingUserInputRequests:
              <String, CodexSessionPendingUserInputRequest>{
                'request_newer': CodexSessionPendingUserInputRequest(
                  requestId: 'request_newer',
                  requestType: CodexCanonicalRequestType.toolUserInput,
                  createdAt: DateTime(2026, 3, 15, 12, 0, 2),
                  detail: 'Newer input',
                ),
                'request_older': CodexSessionPendingUserInputRequest(
                  requestId: 'request_older',
                  requestType: CodexCanonicalRequestType.toolUserInput,
                  createdAt: DateTime(2026, 3, 15, 12, 0, 1),
                  detail: 'Older input',
                ),
              },
        );
        final sessionState = CodexSessionState.initial()
            .copyWithProjectedTranscript(activeTurn: activeTurn);

        final surface = projector.project(
          profile: _configuredProfile(),
          sessionState: sessionState,
        );

        expect(surface.pinnedItems, hasLength(1));
        expect(
          (surface.pinnedItems.single as ChatUserInputRequestItemContract)
              .request
              .requestId,
          'request_older',
        );
        expect(surface.activePendingUserInputRequestIds, <String>{
          'request_older',
        });
      },
    );

    test(
      'projects an empty state when no transcript or pending items are visible',
      () {
        final surface = projector.project(
          profile: ConnectionProfile.defaults(),
          sessionState: CodexSessionState.initial(),
        );

        expect(surface.showsEmptyState, isTrue);
        expect(surface.emptyState?.isConfigured, isFalse);
        expect(surface.mainItems, isEmpty);
        expect(surface.pinnedItems, isEmpty);
        expect(surface.totalMainItemCount, 0);
        expect(surface.hiddenOlderMainItemCount, 0);
        expect(surface.pendingRequestPlacement.hasVisibleRequests, isFalse);
        expect(surface.activePendingUserInputRequestIds, isEmpty);
      },
    );

    test(
      'uses the injected placement projector instead of runtime convenience getters',
      () {
        final projector = ChatTranscriptSurfaceProjector(
          pendingRequestPlacementProjector:
              _FakePendingRequestPlacementProjector(
                placement: ChatPendingRequestPlacementContract(
                  visibleApprovalRequest: ChatApprovalRequestContract(
                    id: 'request_override_approval',
                    createdAt: DateTime(2026, 3, 15, 12, 0, 9),
                    requestId: 'request_override_approval',
                    requestType:
                        CodexCanonicalRequestType.commandExecutionApproval,
                    title: 'Injected approval',
                    body: 'Injected approval body',
                    isResolved: false,
                  ),
                  visibleUserInputRequest: ChatUserInputRequestContract(
                    id: 'request_override_input',
                    createdAt: DateTime(2026, 3, 15, 12, 0, 10),
                    requestId: 'request_override_input',
                    requestType: CodexCanonicalRequestType.toolUserInput,
                    title: 'Injected input',
                    body: 'Injected input body',
                    isResolved: false,
                  ),
                ),
              ),
        );
        final sessionState = CodexSessionState.initial()
            .copyWithProjectedTranscript(
              activeTurn: CodexActiveTurnState(
                turnId: 'turn_1',
                timer: CodexSessionTurnTimer(
                  turnId: 'turn_1',
                  startedAt: DateTime(2026, 3, 15, 12),
                ),
                pendingApprovalRequests: <String, CodexSessionPendingRequest>{
                  'runtime_approval': CodexSessionPendingRequest(
                    requestId: 'runtime_approval',
                    requestType: CodexCanonicalRequestType.fileChangeApproval,
                    createdAt: DateTime(2026, 3, 15, 12, 0, 1),
                    detail: 'Runtime approval body',
                  ),
                },
                pendingUserInputRequests:
                    <String, CodexSessionPendingUserInputRequest>{
                      'runtime_input': CodexSessionPendingUserInputRequest(
                        requestId: 'runtime_input',
                        requestType: CodexCanonicalRequestType.toolUserInput,
                        createdAt: DateTime(2026, 3, 15, 12, 0, 2),
                        detail: 'Runtime input body',
                      ),
                    },
              ),
            );

        final surface = projector.project(
          profile: _configuredProfile(),
          sessionState: sessionState,
        );

        expect(surface.pinnedItems, hasLength(2));
        expect(
          (surface.pinnedItems.first as ChatApprovalRequestItemContract)
              .request
              .title,
          'Injected approval',
        );
        expect(
          (surface.pinnedItems.last as ChatUserInputRequestItemContract)
              .request
              .title,
          'Injected input',
        );
        expect(
          surface.pendingRequestPlacement.visibleApprovalRequest?.requestId,
          'request_override_approval',
        );
        expect(
          surface.pendingRequestPlacement.visibleUserInputRequest?.requestId,
          'request_override_input',
        );
        expect(surface.activePendingUserInputRequestIds, <String>{
          'request_override_input',
        });
      },
    );

    test(
      'marks sent root-thread user messages as rewindable when the session is idle',
      () {
        final userBlock = CodexUserMessageBlock(
          id: 'user_1',
          createdAt: DateTime(2026, 3, 15, 12),
          text: 'Restore this',
          deliveryState: CodexUserMessageDeliveryState.sent,
        );
        final sessionState = CodexSessionState.initial().copyWith(
          rootThreadId: 'thread_root',
          sessionThreadId: 'thread_root',
          sessionBlocks: <CodexUiBlock>[userBlock],
        );

        final surface = projector.project(
          profile: _configuredProfile(),
          sessionState: sessionState,
        );

        final userItem =
            surface.mainItems.single as ChatUserMessageItemContract;
        expect(userItem.block, same(userBlock));
        expect(userItem.canContinueFromHere, isTrue);
      },
    );

    test(
      'does not mark user messages as rewindable while the session is busy, on child timelines, or for local echo prompts',
      () {
        final userBlock = CodexUserMessageBlock(
          id: 'user_1',
          createdAt: DateTime(2026, 3, 15, 12),
          text: 'Restore this',
          deliveryState: CodexUserMessageDeliveryState.sent,
        );
        final childUserBlock = userBlock.copyWith();
        final localEchoBlock = userBlock.copyWith(
          deliveryState: CodexUserMessageDeliveryState.localEcho,
        );

        final busySurface = projector.project(
          profile: _configuredProfile(),
          sessionState: CodexSessionState.initial().copyWith(
            connectionStatus: CodexRuntimeSessionState.running,
            rootThreadId: 'thread_root',
            sessionThreadId: 'thread_root',
            sessionBlocks: <CodexUiBlock>[userBlock],
          ),
        );
        final childTimelineSurface = projector.project(
          profile: _configuredProfile(),
          sessionState: CodexSessionState.initial().copyWith(
            rootThreadId: 'thread_root',
            selectedThreadId: 'thread_child',
            timelinesByThreadId: <String, CodexTimelineState>{
              'thread_root': const CodexTimelineState(threadId: 'thread_root'),
              'thread_child': CodexTimelineState(
                threadId: 'thread_child',
                blocks: <CodexUiBlock>[childUserBlock],
              ),
            },
          ),
        );
        final localEchoSurface = projector.project(
          profile: _configuredProfile(),
          sessionState: CodexSessionState.initial().copyWith(
            rootThreadId: 'thread_root',
            sessionThreadId: 'thread_root',
            sessionBlocks: <CodexUiBlock>[localEchoBlock],
          ),
        );

        expect(
          (busySurface.mainItems.single as ChatUserMessageItemContract)
              .canContinueFromHere,
          isFalse,
        );
        expect(
          (childTimelineSurface.mainItems.single as ChatUserMessageItemContract)
              .canContinueFromHere,
          isFalse,
        );
        expect(
          (localEchoSurface.mainItems.single as ChatUserMessageItemContract)
              .canContinueFromHere,
          isFalse,
        );
      },
    );
  });

  group('ChatRequestProjector', () {
    const projector = ChatRequestProjector();

    test('projects pending approval requests into presentation contracts', () {
      final request = CodexSessionPendingRequest(
        requestId: 'request_approval',
        requestType: CodexCanonicalRequestType.execCommandApproval,
        createdAt: DateTime(2026, 3, 15, 12, 0, 1),
      );

      final contract = projector.projectPendingApprovalRequest(request);

      expect(contract.id, 'request_request_approval');
      expect(contract.requestId, request.requestId);
      expect(contract.title, 'Command approval');
      expect(contract.body, 'Codex needs a decision before it can continue.');
      expect(contract.isResolved, isFalse);
    });

    test(
      'projects pending user-input requests into presentation contracts',
      () {
        final request = CodexSessionPendingUserInputRequest(
          requestId: 'request_input',
          requestType: CodexCanonicalRequestType.toolUserInput,
          createdAt: DateTime(2026, 3, 15, 12, 0, 2),
          questions: const <CodexRuntimeUserInputQuestion>[
            CodexRuntimeUserInputQuestion(
              id: 'project',
              header: 'Project',
              question: 'Which project should I use?',
            ),
          ],
        );

        final contract = projector.projectPendingUserInputRequest(request);

        expect(contract.id, 'request_request_input');
        expect(contract.requestId, request.requestId);
        expect(contract.title, 'Input required');
        expect(contract.body, 'Project: Which project should I use?');
        expect(contract.questions, request.questions);
        expect(contract.isResolved, isFalse);
      },
    );
  });

  group('ChatPendingRequestPlacementProjector', () {
    const projector = ChatPendingRequestPlacementProjector();

    test('selects the oldest pending approval request as visible', () {
      final placement = projector.project(
        pendingApprovalRequests: <String, CodexSessionPendingRequest>{
          'request_newer': CodexSessionPendingRequest(
            requestId: 'request_newer',
            requestType: CodexCanonicalRequestType.fileChangeApproval,
            createdAt: DateTime(2026, 3, 15, 12, 0, 2),
            detail: 'Newer approval',
          ),
          'request_older': CodexSessionPendingRequest(
            requestId: 'request_older',
            requestType: CodexCanonicalRequestType.fileChangeApproval,
            createdAt: DateTime(2026, 3, 15, 12, 0, 1),
            detail: 'Older approval',
          ),
        },
        pendingUserInputRequests:
            const <String, CodexSessionPendingUserInputRequest>{},
      );

      expect(placement.visibleApprovalRequest?.requestId, 'request_older');
      expect(placement.visibleApprovalRequest?.title, 'File change approval');
      expect(placement.visibleUserInputRequest, isNull);
      expect(placement.orderedVisibleRequests, hasLength(1));
    });

    test('selects the oldest pending user-input request as visible', () {
      final placement = projector.project(
        pendingApprovalRequests: const <String, CodexSessionPendingRequest>{},
        pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
          'request_newer': CodexSessionPendingUserInputRequest(
            requestId: 'request_newer',
            requestType: CodexCanonicalRequestType.toolUserInput,
            createdAt: DateTime(2026, 3, 15, 12, 0, 2),
            detail: 'Newer input',
          ),
          'request_older': CodexSessionPendingUserInputRequest(
            requestId: 'request_older',
            requestType: CodexCanonicalRequestType.mcpServerElicitation,
            createdAt: DateTime(2026, 3, 15, 12, 0, 1),
            detail: 'Older input',
          ),
        },
      );

      expect(placement.visibleApprovalRequest, isNull);
      expect(placement.visibleUserInputRequest?.requestId, 'request_older');
      expect(placement.visibleUserInputRequest?.title, 'MCP input required');
      expect(placement.orderedVisibleRequests, hasLength(1));
    });

    test('orders visible requests as approval first then user-input', () {
      final placement = projector.project(
        pendingApprovalRequests: <String, CodexSessionPendingRequest>{
          'approval_request': CodexSessionPendingRequest(
            requestId: 'approval_request',
            requestType: CodexCanonicalRequestType.execCommandApproval,
            createdAt: DateTime(2026, 3, 15, 12, 0, 5),
            detail: 'Approval request',
          ),
        },
        pendingUserInputRequests: <String, CodexSessionPendingUserInputRequest>{
          'input_request_newer': CodexSessionPendingUserInputRequest(
            requestId: 'input_request_newer',
            requestType: CodexCanonicalRequestType.toolUserInput,
            createdAt: DateTime(2026, 3, 15, 12, 0, 6),
            detail: 'Newer input request',
          ),
          'input_request_older': CodexSessionPendingUserInputRequest(
            requestId: 'input_request_older',
            requestType: CodexCanonicalRequestType.toolUserInput,
            createdAt: DateTime(2026, 3, 15, 12, 0, 1),
            detail: 'Older input request',
          ),
        },
      );

      expect(placement.orderedVisibleRequests, hasLength(2));
      expect(
        placement.orderedVisibleRequests.first.requestId,
        'approval_request',
      );
      expect(
        placement.orderedVisibleRequests.first,
        isA<ChatApprovalRequestContract>(),
      );
      expect(
        placement.orderedVisibleRequests.last.requestId,
        'input_request_older',
      );
      expect(
        placement.orderedVisibleRequests.last,
        isA<ChatUserInputRequestContract>(),
      );
    });

    test(
      'disables branch conversation when no current thread is available',
      () {
        const presenter = ChatScreenPresenter();
        final contract = presenter.present(
          isLoading: false,
          profile: _configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: CodexSessionState.initial(),
          conversationRecoveryState: null,
          composerDraft: const ChatComposerDraft(),
          transcriptFollow: _defaultTranscriptFollowContract,
        );

        final branchAction = contract.menuActions.firstWhere(
          (action) => action.id == ChatScreenActionId.branchConversation,
        );
        expect(branchAction.isEnabled, isFalse);
      },
    );

    test(
      'keeps insertion order when requests share the same createdAt timestamp',
      () {
        final createdAt = DateTime(2026, 3, 15, 12, 0, 1);
        final placement = projector.project(
          pendingApprovalRequests: <String, CodexSessionPendingRequest>{
            'request_first': CodexSessionPendingRequest(
              requestId: 'request_first',
              requestType: CodexCanonicalRequestType.fileChangeApproval,
              createdAt: createdAt,
              detail: 'First approval',
            ),
            'request_second': CodexSessionPendingRequest(
              requestId: 'request_second',
              requestType: CodexCanonicalRequestType.fileChangeApproval,
              createdAt: createdAt,
              detail: 'Second approval',
            ),
          },
          pendingUserInputRequests:
              const <String, CodexSessionPendingUserInputRequest>{},
        );

        expect(placement.visibleApprovalRequest?.requestId, 'request_first');
      },
    );
  });

  group('ChatTranscriptItemProjector', () {
    const projector = ChatTranscriptItemProjector();

    test('projects work-log groups into work-log group item contracts', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_1',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_1',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'Read docs',
            turnId: 'turn_1',
            preview: 'Found the CLI docs',
            isRunning: true,
            exitCode: 0,
          ),
        ],
      );

      final item = projector.project(groupBlock);

      expect(item, isA<ChatWorkLogGroupItemContract>());
      final groupItem = item as ChatWorkLogGroupItemContract;
      expect(groupItem.id, groupBlock.id);
      expect(groupItem.entries, hasLength(1));
      expect(groupItem.entries.single, isA<ChatGenericWorkLogEntryContract>());
      final entry = groupItem.entries.single as ChatGenericWorkLogEntryContract;
      expect(entry.title, 'Read docs');
      expect(entry.turnId, 'turn_1');
      expect(entry.preview, 'Found the CLI docs');
      expect(entry.isRunning, isTrue);
      expect(entry.exitCode, 0);
    });

    test('projects simple sed read commands into read work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_sed',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_sed',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: "sed -n '1,120p' lib/src/app/pocket_relay_app.dart",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatSedReadWorkLogEntryContract;

      expect(entry.lineStart, 1);
      expect(entry.lineEnd, 120);
      expect(entry.fileName, 'pocket_relay_app.dart');
      expect(entry.filePath, 'lib/src/app/pocket_relay_app.dart');
      expect(entry.summaryLabel, 'Reading lines 1 to 120');
    });

    test('projects web-search items into dedicated web-search entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_web_search',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_web_search',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.webSearch,
            title: 'Search docs',
            preview: 'Found CLI reference and API notes',
            snapshot: const <String, Object?>{'query': 'Pocket Relay CLI'},
          ),
        ],
      );

      final item = projector.project(groupBlock) as ChatWebSearchItemContract;
      final entry = item.entry;

      expect(entry.queryText, 'Pocket Relay CLI');
      expect(entry.resultSummary, 'Found CLI reference and API notes');
      expect(entry.activityLabel, 'Searched');
    });

    test(
      'projects plain command executions into dedicated command entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_command',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_command',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: 'pwd',
              preview: '/repo',
              isRunning: true,
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatExecCommandItemContract;
        final entry = item.entry;

        expect(entry.commandText, 'pwd');
        expect(entry.outputPreview, '/repo');
        expect(entry.activityLabel, 'Running command');
      },
    );
    test(
      'projects empty-stdin terminal interactions into command wait entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_command_wait',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_command_wait',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: 'sleep 5',
              preview: 'still running',
              isRunning: true,
              snapshot: const <String, Object?>{
                'processId': 'proc_1',
                'stdin': '',
              },
            ),
          ],
        );

        final item = projector.project(groupBlock) as ChatExecWaitItemContract;
        final entry = item.entry;

        expect(entry.commandText, 'sleep 5');
        expect(entry.outputPreview, 'still running');
        expect(entry.processId, 'proc_1');
        expect(entry.activityLabel, 'Waiting for background terminal');
      },
    );

    test(
      'keeps resumed background-terminal commands in the command execution family',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_command_wait_resumed',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_command_wait_resumed',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: 'sleep 5',
              preview: 'ready',
              isRunning: true,
              snapshot: const <String, Object?>{
                'command': 'sleep 5',
                'processId': 'proc_1',
              },
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatExecCommandItemContract;
        final entry = item.entry;

        expect(entry.commandText, 'sleep 5');
        expect(entry.outputPreview, 'ready');
        expect(entry.activityLabel, 'Running command');
      },
    );

    test('projects review status blocks into dedicated review items', () {
      final item = projector.project(
        CodexStatusBlock(
          id: 'status_review',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Review started',
          body: 'Checking the patch set',
          statusKind: CodexStatusBlockKind.review,
        ),
      );

      expect(item, isA<ChatReviewStatusItemContract>());
    });

    test(
      'projects compaction status blocks into dedicated context-compacted items',
      () {
        final item = projector.project(
          CodexStatusBlock(
            id: 'status_compaction',
            createdAt: DateTime(2026, 3, 15, 12),
            title: 'Context compacted',
            body: 'Codex compacted the current thread context.',
            statusKind: CodexStatusBlockKind.compaction,
          ),
        );

        expect(item, isA<ChatContextCompactedItemContract>());
      },
    );

    test('projects info status blocks into dedicated session-info items', () {
      final item = projector.project(
        CodexStatusBlock(
          id: 'status_info',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'New thread',
          body: 'Resume the previous task.',
          statusKind: CodexStatusBlockKind.info,
          isTranscriptSignal: true,
        ),
      );

      expect(item, isA<ChatSessionInfoItemContract>());
    });

    test('projects warning status blocks into dedicated warning items', () {
      final item = projector.project(
        CodexStatusBlock(
          id: 'status_warning',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Warning',
          body: 'The command exceeded the preferred timeout.',
          statusKind: CodexStatusBlockKind.warning,
        ),
      );

      expect(item, isA<ChatWarningItemContract>());
    });

    test('projects deprecation notices into dedicated warning items', () {
      final item = projector.project(
        CodexStatusBlock(
          id: 'status_deprecation',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Deprecation notice',
          body: 'This event family will be removed soon.',
          statusKind: CodexStatusBlockKind.warning,
        ),
      );

      expect(item, isA<ChatDeprecationNoticeItemContract>());
    });

    test('projects patch-apply failures into dedicated error items', () {
      final item = projector.project(
        CodexErrorBlock(
          id: 'error_patch_apply',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Patch apply failed',
          body: 'The patch could not be applied cleanly.',
        ),
      );

      expect(item, isA<ChatPatchApplyFailureItemContract>());
    });

    test('projects sed -ne read commands into read work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_sed_ne',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_sed_ne',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: "sed -ne '5,25p' lib/src/app/pocket_relay_app.dart",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatSedReadWorkLogEntryContract;

      expect(entry.lineStart, 5);
      expect(entry.lineEnd, 25);
      expect(entry.summaryLabel, 'Reading lines 5 to 25');
    });

    test('keeps chained sed commands as generic work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_sed_chain',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_sed_chain',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title:
                "sed -n '1,120p' lib/src/app/pocket_relay_app.dart && rg Pocket Relay",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;

      expect(item.entries.single, isA<ChatGenericWorkLogEntryContract>());
    });

    test('keeps reversed sed ranges as generic work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_sed_reversed',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_sed_reversed',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: "sed -n '40,1p' lib/src/app/pocket_relay_app.dart",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;

      expect(item.entries.single, isA<ChatGenericWorkLogEntryContract>());
    });

    test('projects cat reads into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_cat',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_cat',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'cat README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatCatReadWorkLogEntryContract;

      expect(entry.fileName, 'README.md');
      expect(entry.filePath, 'README.md');
      expect(entry.summaryLabel, 'Reading full file');
    });

    test('projects head reads into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_head',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_head',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'head -n 40 docs/021_codebase-handoff.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatHeadReadWorkLogEntryContract;

      expect(entry.lineCount, 40);
      expect(entry.fileName, '021_codebase-handoff.md');
      expect(entry.summaryLabel, 'Reading first 40 lines');
    });

    test(
      'projects compact head -n40 reads into command-specific work-log entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_head_compact',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_head_compact',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: 'head -n40 docs/021_codebase-handoff.md',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry = item.entries.single as ChatHeadReadWorkLogEntryContract;

        expect(entry.lineCount, 40);
        expect(entry.summaryLabel, 'Reading first 40 lines');
      },
    );

    test('projects tail reads into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_tail',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_tail',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'tail -20 logs/output.txt',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatTailReadWorkLogEntryContract;

      expect(entry.lineCount, 20);
      expect(entry.fileName, 'output.txt');
      expect(entry.summaryLabel, 'Reading last 20 lines');
    });

    test(
      'projects Get-Content reads into command-specific work-log entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_get_content',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_get_content',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: r'Get-Content -Path C:\repo\README.md -TotalCount 25',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatGetContentReadWorkLogEntryContract;

        expect(entry.mode, ChatGetContentReadMode.firstLines);
        expect(entry.lineCount, 25);
        expect(entry.fileName, 'README.md');
        expect(entry.filePath, r'C:\repo\README.md');
        expect(entry.summaryLabel, 'Reading first 25 lines');
      },
    );

    test('projects rg searches into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_rg',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_rg',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'rg -n "Pocket Relay" lib test',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry =
          item.entries.single as ChatRipgrepSearchWorkLogEntryContract;

      expect(entry.queryText, 'Pocket Relay');
      expect(entry.scopeTargets, <String>['lib', 'test']);
      expect(entry.scopeLabel, 'In lib, test');
      expect(entry.summaryLabel, 'Searching for');
    });

    test('projects grep searches into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_grep',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_grep',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'grep -R -n "Pocket Relay" README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGrepSearchWorkLogEntryContract;

      expect(entry.queryText, 'Pocket Relay');
      expect(entry.scopeTargets, <String>['README.md']);
      expect(entry.scopeLabel, 'In README.md');
    });

    test(
      'projects Select-String searches into command-specific work-log entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_select_string',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_select_string',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title:
                  r'Select-String -Path C:\repo\README.md -Pattern "Pocket Relay"',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatSelectStringSearchWorkLogEntryContract;

        expect(entry.queryText, 'Pocket Relay');
        expect(entry.scopeTargets, <String>[r'C:\repo\README.md']);
        expect(entry.scopeLabel, r'In C:\repo\README.md');
      },
    );

    test(
      'projects findstr searches into command-specific work-log entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_findstr',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_findstr',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: r'findstr /n /s /c:"Pocket Relay" *.md',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatFindStrSearchWorkLogEntryContract;

        expect(entry.queryText, 'Pocket Relay');
        expect(entry.scopeTargets, <String>['*.md']);
        expect(entry.scopeLabel, 'In *.md');
      },
    );

    test(
      'splits simple top-level alternation queries into structured display segments',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_rg_alt',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_rg_alt',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title:
                  r'rg -n "pwsh|powershell|Get-Content|head -|tail -|/usr/bin/sed|/usr/bin/cat|/usr/bin/head|/usr/bin/tail|sed -n" lib test',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatRipgrepSearchWorkLogEntryContract;

        expect(entry.querySegments, <String>[
          'pwsh',
          'powershell',
          'Get-Content',
          'head -',
          'tail -',
          '/usr/bin/sed',
          '/usr/bin/cat',
          '/usr/bin/head',
          '/usr/bin/tail',
          'sed -n',
        ]);
        expect(
          entry.displayQueryText,
          'pwsh | powershell | Get-Content | head - | tail - | /usr/bin/sed | /usr/bin/cat | /usr/bin/head | /usr/bin/tail | sed -n',
        );
      },
    );

    test('keeps chained rg commands as generic work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_rg_chain',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_rg_chain',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title:
                'rg -n "Pocket Relay" lib && grep -n "Pocket Relay" README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;

      expect(item.entries.single, isA<ChatGenericWorkLogEntryContract>());
    });

    test('projects git status commands into git work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_git_status',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_git_status',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'git status',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGitWorkLogEntryContract;

      expect(entry.summaryLabel, 'Checking worktree status');
      expect(entry.primaryLabel, 'Current repository');
      expect(entry.secondaryLabel, isNull);
    });

    test('projects git diff commands into git work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_git_diff',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_git_diff',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'git diff --staged README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGitWorkLogEntryContract;

      expect(entry.summaryLabel, 'Inspecting diff');
      expect(entry.primaryLabel, 'Staged changes');
      expect(entry.secondaryLabel, 'README.md');
    });

    test('projects git show commands into git work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_git_show',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_git_show',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'git show HEAD~1:README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGitWorkLogEntryContract;

      expect(entry.summaryLabel, 'Inspecting git object');
      expect(entry.primaryLabel, 'HEAD~1:README.md');
    });

    test('projects git grep commands into git work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_git_grep',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_git_grep',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'git grep -n "Pocket Relay" lib test',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGitWorkLogEntryContract;

      expect(entry.summaryLabel, 'Searching tracked files');
      expect(entry.primaryLabel, 'Pocket Relay');
      expect(entry.secondaryLabel, 'In lib, test');
    });

    test('keeps unknown git subcommands in the git work-log family', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_git_generic',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_git_generic',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'git sparse-checkout list',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGitWorkLogEntryContract;

      expect(entry.summaryLabel, 'Running git sparse-checkout');
      expect(entry.primaryLabel, 'list');
    });

    test('keeps completed MCP tool calls inside grouped work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_mcp_completed',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_mcp_completed',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.mcpToolCall,
            title: 'MCP tool call',
            snapshot: const <String, Object?>{
              'server': 'filesystem',
              'tool': 'read_file',
              'status': 'completed',
              'arguments': <String, Object?>{'path': 'README.md'},
              'result': <String, Object?>{
                'content': <Object?>[
                  <String, Object?>{
                    'type': 'text',
                    'text': 'README first lines\nMore output',
                  },
                ],
              },
              'durationMs': 42,
            },
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatMcpToolCallWorkLogEntryContract;

      expect(entry.status, ChatMcpToolCallStatus.completed);
      expect(entry.toolName, 'read_file');
      expect(entry.serverName, 'filesystem');
      expect(entry.identityLabel, 'filesystem.read_file');
      expect(entry.argumentsSummary, 'path: README.md');
      expect(entry.resultSummary, 'README first lines');
      expect(entry.argumentsLabel, 'args: path: README.md');
      expect(entry.outcomeLabel, 'completed · README first lines · 42 ms');
    });

    test('keeps failed MCP tool calls inside grouped work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_mcp_failed',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_mcp_failed',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.mcpToolCall,
            title: 'MCP tool call',
            snapshot: const <String, Object?>{
              'server': 'filesystem',
              'tool': 'write_file',
              'status': 'failed',
              'arguments': <String, Object?>{'path': 'README.md'},
              'error': <String, Object?>{'message': 'Permission denied'},
              'durationMs': 142,
            },
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatMcpToolCallWorkLogEntryContract;

      expect(entry.status, ChatMcpToolCallStatus.failed);
      expect(entry.identityLabel, 'filesystem.write_file');
      expect(entry.argumentsSummary, 'path: README.md');
      expect(entry.errorSummary, 'Permission denied');
      expect(entry.argumentsLabel, 'args: path: README.md');
      expect(entry.outcomeLabel, 'failed · Permission denied · 142 ms');
    });

    test(
      'projects changed-files blocks into structured changed-files item contracts',
      () {
        final block = CodexChangedFilesBlock(
          id: 'changed_files_1',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Changed files',
          files: const <CodexChangedFile>[
            CodexChangedFile(path: 'lib/app.dart', additions: 1),
          ],
          unifiedDiff:
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -1 +1 @@\n'
              '-old\n'
              '+new\n',
        );

        final item = projector.project(block);

        expect(item, isA<ChatChangedFilesItemContract>());
        final changedFilesItem = item as ChatChangedFilesItemContract;
        expect(changedFilesItem.id, block.id);
        expect(changedFilesItem.title, block.title);
        expect(changedFilesItem.fileCount, 1);
        expect(changedFilesItem.headerStats.additions, 1);
        expect(changedFilesItem.headerStats.deletions, 1);
        expect(changedFilesItem.rows.single.displayPathLabel, 'lib/app.dart');
        expect(changedFilesItem.rows.single.fileName, 'app.dart');
        expect(changedFilesItem.rows.single.languageLabel, 'Dart');
        expect(changedFilesItem.rows.single.stats.deletions, 1);
        expect(changedFilesItem.rows.single.diff, isNotNull);
        expect(changedFilesItem.rows.single.diff?.syntaxLanguage, 'dart');
        expect(
          changedFilesItem.rows.single.diff?.lines.first.text,
          'diff --git a/lib/app.dart b/lib/app.dart',
        );
        expect(changedFilesItem.rows.single.diff?.lines[4].oldLineNumber, 1);
        expect(changedFilesItem.rows.single.diff?.lines[5].newLineNumber, 1);
      },
    );

    test(
      'projects renamed files with current-path metadata and rename state',
      () {
        final block = CodexChangedFilesBlock(
          id: 'changed_files_rename_1',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Changed files',
          files: const <CodexChangedFile>[
            CodexChangedFile(path: 'lib/new.dart'),
          ],
          unifiedDiff:
              'diff --git a/lib/old.dart b/lib/new.dart\n'
              'similarity index 88%\n'
              'rename from lib/old.dart\n'
              'rename to lib/new.dart\n'
              '--- a/lib/old.dart\n'
              '+++ b/lib/new.dart\n'
              '@@ -1 +1 @@\n'
              '-oldName();\n'
              '+newName();\n',
        );

        final item = projector.project(block) as ChatChangedFilesItemContract;
        final row = item.rows.single;

        expect(row.operationKind, ChatChangedFileOperationKind.renamed);
        expect(row.previousPath, 'lib/old.dart');
        expect(row.currentPath, 'lib/new.dart');
        expect(row.languageLabel, 'Dart');
        expect(row.diff?.operationKind, ChatChangedFileOperationKind.renamed);
        expect(row.diff?.syntaxLanguage, 'dart');
        expect(row.diff?.lines.last.text, '+newName();');
      },
    );

    test(
      'keeps hunk lines that look like diff headers as real additions and deletions',
      () {
        final block = CodexChangedFilesBlock(
          id: 'changed_files_header_like_lines_1',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Changed files',
          files: const <CodexChangedFile>[
            CodexChangedFile(path: 'lib/app.dart'),
          ],
          unifiedDiff:
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -1,2 +1,2 @@\n'
              '--- old flag\n'
              '-keep old branch\n'
              '+++ new flag\n'
              '+keep new branch\n',
        );

        final item = projector.project(block) as ChatChangedFilesItemContract;
        final diff = item.rows.single.diff!;

        expect(diff.stats.additions, 2);
        expect(diff.stats.deletions, 2);
        expect(diff.lines[4].kind, ChatChangedFileDiffLineKind.deletion);
        expect(diff.lines[4].oldLineNumber, 1);
        expect(diff.lines[6].kind, ChatChangedFileDiffLineKind.addition);
        expect(diff.lines[6].newLineNumber, 1);
      },
    );

    test('projects binary diffs as binary review items', () {
      final block = CodexChangedFilesBlock(
        id: 'changed_files_binary_1',
        createdAt: DateTime(2026, 3, 15, 12),
        title: 'Changed files',
        files: const <CodexChangedFile>[
          CodexChangedFile(path: 'assets/logo.png'),
        ],
        unifiedDiff:
            'diff --git a/assets/logo.png b/assets/logo.png\n'
            'Binary files a/assets/logo.png and b/assets/logo.png differ\n',
      );

      final item = projector.project(block) as ChatChangedFilesItemContract;
      final row = item.rows.single;

      expect(row.languageLabel, 'Binary');
      expect(row.isBinary, isTrue);
      expect(row.diff, isNotNull);
      expect(row.diff?.syntaxLanguage, isNull);
      expect(row.diff?.isBinary, isTrue);
      expect(row.diff?.lines.last.kind, ChatChangedFileDiffLineKind.meta);
    });

    test('projects SSH transcript blocks into SSH item contracts', () {
      final block = CodexSshConnectFailedBlock(
        id: 'ssh_connect_failed_1',
        createdAt: DateTime(2026, 3, 15, 12),
        host: 'example.com',
        port: 22,
        message: 'Connection refused',
      );

      final item = projector.project(block);

      expect(item, isA<ChatSshItemContract>());
      final sshItem = item as ChatSshItemContract;
      expect(sshItem.block, same(block));
    });

    test(
      'derives changed-files header totals from resolved row stats when file payloads are partial',
      () {
        final block = CodexChangedFilesBlock(
          id: 'changed_files_mixed_1',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Changed files',
          files: const <CodexChangedFile>[
            CodexChangedFile(path: 'README.md', additions: 1),
            CodexChangedFile(path: 'lib/app.dart'),
          ],
          unifiedDiff:
              'diff --git a/README.md b/README.md\n'
              '--- a/README.md\n'
              '+++ b/README.md\n'
              '@@ -1 +1 @@\n'
              '-old readme\n'
              '+new readme\n'
              'diff --git a/lib/app.dart b/lib/app.dart\n'
              '--- a/lib/app.dart\n'
              '+++ b/lib/app.dart\n'
              '@@ -1 +1,2 @@\n'
              '-old app\n'
              '+new app\n'
              '+second line\n',
        );

        final item = projector.project(block) as ChatChangedFilesItemContract;

        expect(item.headerStats.additions, 3);
        expect(item.headerStats.deletions, 2);
        expect(item.rows[1].stats.additions, 2);
        expect(item.rows[1].stats.deletions, 1);
      },
    );
  });

  group('ChatTranscriptFollowHost', () {
    test(
      'models follow requests and viewport eligibility above the widget',
      () {
        final host = ChatTranscriptFollowHost();

        expect(host.contract.isAutoFollowEnabled, isTrue);
        expect(host.contract.request, isNull);

        host.updateAutoFollowEligibility(isNearBottom: false);

        expect(host.contract.isAutoFollowEnabled, isFalse);
        expect(host.contract.request, isNull);

        host.requestFollow(
          source: ChatTranscriptFollowRequestSource.clearTranscript,
        );

        final firstRequest = host.contract.request;
        expect(host.contract.isAutoFollowEnabled, isTrue);
        expect(
          firstRequest?.source,
          ChatTranscriptFollowRequestSource.clearTranscript,
        );

        host.requestFollow(source: ChatTranscriptFollowRequestSource.newThread);

        expect(host.contract.request?.id, greaterThan(firstRequest!.id));
        expect(
          host.contract.request?.source,
          ChatTranscriptFollowRequestSource.newThread,
        );
      },
    );

    test('reset restores default follow state', () {
      final host = ChatTranscriptFollowHost();

      host.updateAutoFollowEligibility(isNearBottom: false);
      host.requestFollow(
        source: ChatTranscriptFollowRequestSource.clearTranscript,
      );

      host.reset();

      expect(host.contract.isAutoFollowEnabled, isTrue);
      expect(host.contract.request, isNull);
    });
  });

  group('ChatComposerDraftHost', () {
    test('models draft updates and clear behavior above the renderer', () {
      final host = ChatComposerDraftHost();

      expect(host.draft.text, isEmpty);

      host.updateText('  draft text  ');
      expect(host.draft.text, '  draft text  ');

      host.clear();
      expect(host.draft.text, isEmpty);
    });

    test('reset clears draft state above the renderer', () {
      final host = ChatComposerDraftHost();

      host.updateText('draft to reset');
      host.reset();

      expect(host.draft.text, isEmpty);
    });
  });

  test('maps snackbar messages into screen effects', () {
    const mapper = ChatScreenEffectMapper();

    final effect = mapper.mapSnackBarMessage('Input failed');

    expect(effect, isA<ChatShowSnackBarEffect>());
    expect((effect as ChatShowSnackBarEffect).message, 'Input failed');
  });

  test('maps the settings action into a connection settings effect', () {
    const presenter = ChatScreenPresenter();
    const mapper = ChatScreenEffectMapper();
    final profile = _configuredProfile();
    final secrets = const ConnectionSecrets(password: 'secret');
    final contract = presenter.present(
      isLoading: false,
      profile: profile,
      secrets: secrets,
      sessionState: CodexSessionState.initial(),
      conversationRecoveryState: null,
      composerDraft: const ChatComposerDraft(),
      transcriptFollow: _defaultTranscriptFollowContract,
    );

    final effect = mapper.mapAction(
      action: ChatScreenActionId.openSettings,
      screen: contract,
    );

    expect(effect, isA<ChatOpenConnectionSettingsEffect>());
    expect(
      (effect as ChatOpenConnectionSettingsEffect).payload.initialProfile,
      same(profile),
    );
    expect(effect.payload.initialSecrets, same(secrets));
  });
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
  );
}

class _FakePendingRequestPlacementProjector
    extends ChatPendingRequestPlacementProjector {
  const _FakePendingRequestPlacementProjector({required this.placement});

  final ChatPendingRequestPlacementContract placement;

  @override
  ChatPendingRequestPlacementContract project({
    required Map<String, CodexSessionPendingRequest> pendingApprovalRequests,
    required Map<String, CodexSessionPendingUserInputRequest>
    pendingUserInputRequests,
  }) {
    return placement;
  }
}
