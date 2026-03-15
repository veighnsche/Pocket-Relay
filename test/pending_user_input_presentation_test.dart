import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_draft.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_presenter.dart';

void main() {
  group('PendingUserInputPresenter', () {
    const presenter = PendingUserInputPresenter();

    test('maps questions, options, and draft answers into field contracts', () {
      final block = CodexUserInputRequestBlock(
        id: 'input_1',
        createdAt: DateTime(2026, 3, 15, 12),
        requestId: 'input_1',
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'Codex needs clarification.',
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
      final formState = PendingUserInputFormState.initial(block: block)
          .copyWith(
            draft: PendingUserInputDraft.fromBlock(
              block,
            ).copyWithField('q1', 'Pocket Relay'),
          );

      final contract = presenter.present(block: block, formState: formState);
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
      final block = CodexUserInputRequestBlock(
        id: 'input_2',
        createdAt: DateTime(2026, 3, 15, 12),
        requestId: 'input_2',
        requestType: CodexCanonicalRequestType.mcpServerElicitation,
        title: 'MCP input required',
        body: 'Choose a directory.',
      );
      final formState = PendingUserInputFormState.initial(block: block)
          .copyWith(
            draft: PendingUserInputDraft.fromBlock(block).copyWithField(
              pendingUserInputFallbackFieldId,
              ' /workspace/mobile ',
            ),
          );

      final contract = presenter.present(block: block, formState: formState);
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
      final block = CodexUserInputRequestBlock(
        id: 'input_3',
        createdAt: DateTime(2026, 3, 15, 12),
        requestId: 'input_3',
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'Need both answers.',
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

      final contract = presenter.present(block: block, formState: formState);

      expect(contract.fields[1].inputLabel, 'Custom answer');
      expect(contract.fields[1].maxLines, 4);
      expect(contract.submitPayload, <String, List<String>>{
        'q1': <String>['/workspace/mobile'],
      });
    });

    test('derives resolved read-only state from the block', () {
      final block = CodexUserInputRequestBlock(
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
      final formState = PendingUserInputFormState.initial(block: block);

      final contract = presenter.present(block: block, formState: formState);
      final field = contract.fields.single;

      expect(contract.isResolved, isTrue);
      expect(contract.statusBadgeLabel, 'submitted');
      expect(contract.isSubmitEnabled, isFalse);
      expect(field.isReadOnly, isTrue);
      expect(field.isSecret, isTrue);
      expect(field.value, 'Vince');
    });

    test('disables submit while the request is submitting', () {
      final block = CodexUserInputRequestBlock(
        id: 'input_5',
        createdAt: DateTime(2026, 3, 15, 12),
        requestId: 'input_5',
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'Need clarification.',
        questions: const <CodexRuntimeUserInputQuestion>[
          CodexRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Project',
            question: 'Which project?',
          ),
        ],
      );
      final formState = PendingUserInputFormState.initial(block: block)
          .copyWith(
            draft: PendingUserInputDraft.fromBlock(
              block,
            ).copyWithField('q1', 'Pocket Relay'),
            submissionState: PendingUserInputSubmissionState.submitting,
          );

      final contract = presenter.present(block: block, formState: formState);

      expect(contract.isSubmitting, isTrue);
      expect(contract.isSubmitEnabled, isFalse);
      expect(contract.submitPayload, <String, List<String>>{
        'q1': <String>['Pocket Relay'],
      });
    });
  });
}
