import '../../support/screen_presentation_test_support.dart';

void main() {
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
}
