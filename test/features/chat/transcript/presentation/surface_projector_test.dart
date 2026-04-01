import '../../support/screen_presentation_test_support.dart';

void main() {
  group('ChatTranscriptSurfaceProjector', () {
    const projector = ChatTranscriptSurfaceProjector();

    test(
      'projects transcript blocks into the main region and pending requests into the pinned region',
      () {
        final transcriptBlock = TranscriptTextBlock(
          id: 'assistant_1',
          kind: TranscriptUiBlockKind.assistantMessage,
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Codex',
          body: 'Hello',
        );
        final activeTurn = TranscriptActiveTurnState(
          turnId: 'turn_1',
          timer: TranscriptSessionTurnTimer(
            turnId: 'turn_1',
            startedAt: DateTime(2026, 3, 15, 12),
          ),
          pendingApprovalRequests: <String, TranscriptSessionPendingRequest>{
            'request_1': TranscriptSessionPendingRequest(
              requestId: 'request_1',
              requestType: TranscriptCanonicalRequestType.fileChangeApproval,
              createdAt: DateTime(2026, 3, 15, 12, 0, 1),
              detail: 'Approve file change',
            ),
          },
          pendingUserInputRequests:
              <String, TranscriptSessionPendingUserInputRequest>{
                'request_2': TranscriptSessionPendingUserInputRequest(
                  requestId: 'request_2',
                  requestType: TranscriptCanonicalRequestType.toolUserInput,
                  createdAt: DateTime(2026, 3, 15, 12, 0, 2),
                  detail: 'Need extra info',
                ),
              },
        );
        final sessionState = TranscriptSessionState.initial()
            .copyWithProjectedTranscript(
              activeTurn: activeTurn,
              blocks: <TranscriptUiBlock>[transcriptBlock],
            );

        final surface = projector.project(
          profile: configuredProfile(),
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
      final transcriptBlocks = List<TranscriptUiBlock>.generate(
        5,
        (index) => TranscriptTextBlock(
          id: 'assistant_$index',
          kind: TranscriptUiBlockKind.assistantMessage,
          createdAt: DateTime(2026, 3, 15, 12, 0, index),
          title: 'Codex',
          body: 'Assistant message $index',
        ),
      );
      final sessionState = TranscriptSessionState.initial()
          .copyWithProjectedTranscript(blocks: transcriptBlocks);

      final surface = projector.project(
        profile: configuredProfile(),
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
        final activeTurn = TranscriptActiveTurnState(
          turnId: 'turn_1',
          timer: TranscriptSessionTurnTimer(
            turnId: 'turn_1',
            startedAt: DateTime(2026, 3, 15, 12),
          ),
          pendingUserInputRequests:
              <String, TranscriptSessionPendingUserInputRequest>{
                'request_newer': TranscriptSessionPendingUserInputRequest(
                  requestId: 'request_newer',
                  requestType: TranscriptCanonicalRequestType.toolUserInput,
                  createdAt: DateTime(2026, 3, 15, 12, 0, 2),
                  detail: 'Newer input',
                ),
                'request_older': TranscriptSessionPendingUserInputRequest(
                  requestId: 'request_older',
                  requestType: TranscriptCanonicalRequestType.toolUserInput,
                  createdAt: DateTime(2026, 3, 15, 12, 0, 1),
                  detail: 'Older input',
                ),
              },
        );
        final sessionState = TranscriptSessionState.initial()
            .copyWithProjectedTranscript(activeTurn: activeTurn);

        final surface = projector.project(
          profile: configuredProfile(),
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
          sessionState: TranscriptSessionState.initial(),
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
              FakePendingRequestPlacementProjector(
                placement: ChatPendingRequestPlacementContract(
                  visibleApprovalRequest: ChatApprovalRequestContract(
                    id: 'request_override_approval',
                    createdAt: DateTime(2026, 3, 15, 12, 0, 9),
                    requestId: 'request_override_approval',
                    requestType:
                        TranscriptCanonicalRequestType.commandExecutionApproval,
                    title: 'Injected approval',
                    body: 'Injected approval body',
                    isResolved: false,
                  ),
                  visibleUserInputRequest: ChatUserInputRequestContract(
                    id: 'request_override_input',
                    createdAt: DateTime(2026, 3, 15, 12, 0, 10),
                    requestId: 'request_override_input',
                    requestType: TranscriptCanonicalRequestType.toolUserInput,
                    title: 'Injected input',
                    body: 'Injected input body',
                    isResolved: false,
                  ),
                ),
              ),
        );
        final sessionState = TranscriptSessionState.initial()
            .copyWithProjectedTranscript(
              activeTurn: TranscriptActiveTurnState(
                turnId: 'turn_1',
                timer: TranscriptSessionTurnTimer(
                  turnId: 'turn_1',
                  startedAt: DateTime(2026, 3, 15, 12),
                ),
                pendingApprovalRequests:
                    <String, TranscriptSessionPendingRequest>{
                      'runtime_approval': TranscriptSessionPendingRequest(
                        requestId: 'runtime_approval',
                        requestType:
                            TranscriptCanonicalRequestType.fileChangeApproval,
                        createdAt: DateTime(2026, 3, 15, 12, 0, 1),
                        detail: 'Runtime approval body',
                      ),
                    },
                pendingUserInputRequests:
                    <String, TranscriptSessionPendingUserInputRequest>{
                      'runtime_input': TranscriptSessionPendingUserInputRequest(
                        requestId: 'runtime_input',
                        requestType:
                            TranscriptCanonicalRequestType.toolUserInput,
                        createdAt: DateTime(2026, 3, 15, 12, 0, 2),
                        detail: 'Runtime input body',
                      ),
                    },
              ),
            );

        final surface = projector.project(
          profile: configuredProfile(),
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
        final userBlock = TranscriptUserMessageBlock(
          id: 'user_1',
          createdAt: DateTime(2026, 3, 15, 12),
          text: 'Restore this',
          deliveryState: TranscriptUserMessageDeliveryState.sent,
        );
        final sessionState = TranscriptSessionState.initial().copyWith(
          rootThreadId: 'thread_root',
          sessionThreadId: 'thread_root',
          sessionBlocks: <TranscriptUiBlock>[userBlock],
        );

        final surface = projector.project(
          profile: configuredProfile(),
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
        final userBlock = TranscriptUserMessageBlock(
          id: 'user_1',
          createdAt: DateTime(2026, 3, 15, 12),
          text: 'Restore this',
          deliveryState: TranscriptUserMessageDeliveryState.sent,
        );
        final childUserBlock = userBlock.copyWith();
        final localEchoBlock = userBlock.copyWith(
          deliveryState: TranscriptUserMessageDeliveryState.localEcho,
        );

        final busySurface = projector.project(
          profile: configuredProfile(),
          sessionState: TranscriptSessionState.initial().copyWith(
            connectionStatus: TranscriptRuntimeSessionState.running,
            rootThreadId: 'thread_root',
            sessionThreadId: 'thread_root',
            sessionBlocks: <TranscriptUiBlock>[userBlock],
          ),
        );
        final childTimelineSurface = projector.project(
          profile: configuredProfile(),
          sessionState: TranscriptSessionState.initial().copyWith(
            rootThreadId: 'thread_root',
            selectedThreadId: 'thread_child',
            timelinesByThreadId: <String, TranscriptTimelineState>{
              'thread_root': const TranscriptTimelineState(
                threadId: 'thread_root',
              ),
              'thread_child': TranscriptTimelineState(
                threadId: 'thread_child',
                blocks: <TranscriptUiBlock>[childUserBlock],
              ),
            },
          ),
        );
        final localEchoSurface = projector.project(
          profile: configuredProfile(),
          sessionState: TranscriptSessionState.initial().copyWith(
            rootThreadId: 'thread_root',
            sessionThreadId: 'thread_root',
            sessionBlocks: <TranscriptUiBlock>[localEchoBlock],
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
}
