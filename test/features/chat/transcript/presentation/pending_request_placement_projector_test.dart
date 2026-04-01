import '../../support/screen_presentation_test_support.dart';

void main() {
  group('ChatPendingRequestPlacementProjector', () {
    const projector = ChatPendingRequestPlacementProjector();

    test('selects the oldest pending approval request as visible', () {
      final placement = projector.project(
        pendingApprovalRequests: <String, TranscriptSessionPendingRequest>{
          'request_newer': TranscriptSessionPendingRequest(
            requestId: 'request_newer',
            requestType: TranscriptCanonicalRequestType.fileChangeApproval,
            createdAt: DateTime(2026, 3, 15, 12, 0, 2),
            detail: 'Newer approval',
          ),
          'request_older': TranscriptSessionPendingRequest(
            requestId: 'request_older',
            requestType: TranscriptCanonicalRequestType.fileChangeApproval,
            createdAt: DateTime(2026, 3, 15, 12, 0, 1),
            detail: 'Older approval',
          ),
        },
        pendingUserInputRequests:
            const <String, TranscriptSessionPendingUserInputRequest>{},
      );

      expect(placement.visibleApprovalRequest?.requestId, 'request_older');
      expect(placement.visibleApprovalRequest?.title, 'File change approval');
      expect(placement.visibleUserInputRequest, isNull);
      expect(placement.orderedVisibleRequests, hasLength(1));
    });

    test('selects the oldest pending user-input request as visible', () {
      final placement = projector.project(
        pendingApprovalRequests:
            const <String, TranscriptSessionPendingRequest>{},
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
                requestType:
                    TranscriptCanonicalRequestType.mcpServerElicitation,
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
        pendingApprovalRequests: <String, TranscriptSessionPendingRequest>{
          'approval_request': TranscriptSessionPendingRequest(
            requestId: 'approval_request',
            requestType: TranscriptCanonicalRequestType.execCommandApproval,
            createdAt: DateTime(2026, 3, 15, 12, 0, 5),
            detail: 'Approval request',
          ),
        },
        pendingUserInputRequests:
            <String, TranscriptSessionPendingUserInputRequest>{
              'input_request_newer': TranscriptSessionPendingUserInputRequest(
                requestId: 'input_request_newer',
                requestType: TranscriptCanonicalRequestType.toolUserInput,
                createdAt: DateTime(2026, 3, 15, 12, 0, 6),
                detail: 'Newer input request',
              ),
              'input_request_older': TranscriptSessionPendingUserInputRequest(
                requestId: 'input_request_older',
                requestType: TranscriptCanonicalRequestType.toolUserInput,
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
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: TranscriptSessionState.initial(),
          conversationRecoveryState: null,
          composerDraft: const ChatComposerDraft(),
          transcriptFollow: defaultTranscriptFollowContract,
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
          pendingApprovalRequests: <String, TranscriptSessionPendingRequest>{
            'request_first': TranscriptSessionPendingRequest(
              requestId: 'request_first',
              requestType: TranscriptCanonicalRequestType.fileChangeApproval,
              createdAt: createdAt,
              detail: 'First approval',
            ),
            'request_second': TranscriptSessionPendingRequest(
              requestId: 'request_second',
              requestType: TranscriptCanonicalRequestType.fileChangeApproval,
              createdAt: createdAt,
              detail: 'Second approval',
            ),
          },
          pendingUserInputRequests:
              const <String, TranscriptSessionPendingUserInputRequest>{},
        );

        expect(placement.visibleApprovalRequest?.requestId, 'request_first');
      },
    );
  });
}
