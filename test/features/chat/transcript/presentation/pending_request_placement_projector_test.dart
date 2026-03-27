import '../../support/screen_presentation_test_support.dart';

void main() {
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
          profile: configuredProfile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          sessionState: CodexSessionState.initial(),
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
}
