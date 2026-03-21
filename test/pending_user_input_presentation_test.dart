import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_draft.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_form_scope.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_presenter.dart';

void main() {
  group('PendingUserInputPresenter', () {
    const presenter = PendingUserInputPresenter();

    test('maps questions, options, and draft answers into field contracts', () {
      final request = ChatUserInputRequestContract(
        id: 'input_1',
        createdAt: DateTime(2026, 3, 15, 12),
        requestId: 'input_1',
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'Codex needs clarification.',
        isResolved: false,
        questions: const <CodexRuntimeUserInputQuestion>[
          CodexRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Project',
            question: 'Which project should I use?',
            options: <CodexRuntimeUserInputOption>[
              CodexRuntimeUserInputOption(
                label: 'Pocket Relay',
                description: 'Use the mobile app project.',
              ),
            ],
          ),
        ],
      );
      final formState = PendingUserInputFormState.initial(request: request)
          .copyWith(
            draft: PendingUserInputDraft.fromRequest(
              request,
            ).copyWithField('q1', 'Pocket Relay'),
          );

      final contract = presenter.present(
        request: request,
        formState: formState,
      );
      final field = contract.fields.single;

      expect(contract.requestId, 'input_1');
      expect(contract.title, 'Input required');
      expect(contract.body, 'Codex needs clarification.');
      expect(field.id, 'q1');
      expect(field.header, 'Project');
      expect(field.prompt, 'Which project should I use?');
      expect(field.inputLabel, 'Answer');
      expect(field.value, 'Pocket Relay');
      expect(field.options.single.label, 'Pocket Relay');
      expect(field.options.single.description, 'Use the mobile app project.');
      expect(contract.isSubmitEnabled, isTrue);
      expect(contract.submitPayload, <String, List<String>>{
        'q1': <String>['Pocket Relay'],
      });
    });

    test('derives a fallback response field when no questions exist', () {
      final request = ChatUserInputRequestContract(
        id: 'input_2',
        createdAt: DateTime(2026, 3, 15, 12),
        requestId: 'input_2',
        requestType: CodexCanonicalRequestType.mcpServerElicitation,
        title: 'MCP input required',
        body: 'Choose a directory.',
        isResolved: false,
      );
      final formState = PendingUserInputFormState.initial(request: request)
          .copyWith(
            draft: PendingUserInputDraft.fromRequest(request).copyWithField(
              pendingUserInputFallbackFieldId,
              ' /workspace/mobile ',
            ),
          );

      final contract = presenter.present(
        request: request,
        formState: formState,
      );
      final field = contract.fields.single;

      expect(field.id, pendingUserInputFallbackFieldId);
      expect(field.header, isNull);
      expect(field.prompt, isNull);
      expect(field.inputLabel, 'Response');
      expect(field.minLines, 2);
      expect(field.maxLines, 3);
      expect(contract.submitPayload, <String, List<String>>{
        pendingUserInputFallbackFieldId: <String>['/workspace/mobile'],
      });
    });

    test('normalizes empty answers out of the submit payload', () {
      final request = ChatUserInputRequestContract(
        id: 'input_3',
        createdAt: DateTime(2026, 3, 15, 12),
        requestId: 'input_3',
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'Need both answers.',
        isResolved: false,
        questions: const <CodexRuntimeUserInputQuestion>[
          CodexRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Workspace',
            question: 'Which workspace should I use?',
          ),
          CodexRuntimeUserInputQuestion(
            id: 'q2',
            header: 'Notes',
            question: 'Anything else?',
            isOther: true,
          ),
        ],
      );
      final formState = PendingUserInputFormState(
        draft: const PendingUserInputDraft()
            .copyWithField('q1', ' /workspace/mobile ')
            .copyWithField('q2', '   '),
      );

      final contract = presenter.present(
        request: request,
        formState: formState,
      );

      expect(contract.fields[1].inputLabel, 'Custom answer');
      expect(contract.fields[1].maxLines, 4);
      expect(contract.submitPayload, <String, List<String>>{
        'q1': <String>['/workspace/mobile'],
      });
    });

    test('derives compact resolved state from the request contract', () {
      final request = ChatUserInputRequestContract(
        id: 'input_4',
        createdAt: DateTime(2026, 3, 15, 12),
        requestId: 'input_4',
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input submitted',
        body: 'q1: Vince',
        questions: const <CodexRuntimeUserInputQuestion>[
          CodexRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Name',
            question: 'What is your name?',
            isSecret: true,
          ),
        ],
        isResolved: true,
        answers: <String, List<String>>{
          'q1': <String>['Vince'],
        },
      );
      final formState = PendingUserInputFormState.initial(request: request);

      final contract = presenter.present(
        request: request,
        formState: formState,
      );

      expect(contract.isResolved, isTrue);
      expect(contract.statusBadgeLabel, 'submitted');
      expect(contract.isSubmitEnabled, isFalse);
      expect(contract.fields, isEmpty);
    });

    test('disables submit while the request is submitting', () {
      final request = ChatUserInputRequestContract(
        id: 'input_5',
        createdAt: DateTime(2026, 3, 15, 12),
        requestId: 'input_5',
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'Need clarification.',
        isResolved: false,
        questions: const <CodexRuntimeUserInputQuestion>[
          CodexRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Project',
            question: 'Which project?',
          ),
        ],
      );
      final formState = PendingUserInputFormState.initial(request: request)
          .copyWith(
            draft: PendingUserInputDraft.fromRequest(
              request,
            ).copyWithField('q1', 'Pocket Relay'),
            submissionState: PendingUserInputSubmissionState.submitting,
          );

      final contract = presenter.present(
        request: request,
        formState: formState,
      );

      expect(contract.isSubmitting, isTrue);
      expect(contract.isSubmitEnabled, isFalse);
      expect(contract.submitPayload, <String, List<String>>{
        'q1': <String>['Pocket Relay'],
      });
    });
  });

  group('PendingUserInputFormStore', () {
    test(
      'does not recreate pruned state when submission cleanup runs after a request stops being active',
      () {
        final store = PendingUserInputFormStore();
        final request = ChatUserInputRequestContract(
          id: 'input_store_1',
          createdAt: DateTime(2026, 3, 15, 12),
          requestId: 'input_store_1',
          requestType: CodexCanonicalRequestType.toolUserInput,
          title: 'Input required',
          body: 'Need clarification.',
          isResolved: false,
          questions: const <CodexRuntimeUserInputQuestion>[
            CodexRuntimeUserInputQuestion(
              id: 'q1',
              header: 'Project',
              question: 'Which project?',
            ),
          ],
        );

        store.setSubmissionState(
          request,
          PendingUserInputSubmissionState.submitting,
        );
        expect(store.hasStateFor(request.requestId), isTrue);

        store.pruneActiveRequestIds(const <String>{});
        expect(store.hasStateFor(request.requestId), isFalse);

        store.setSubmissionState(
          request,
          PendingUserInputSubmissionState.idle,
          createIfMissing: false,
        );
        expect(store.hasStateFor(request.requestId), isFalse);
      },
    );
  });
}
