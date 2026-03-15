import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_draft.dart';

class PendingUserInputPresenter {
  const PendingUserInputPresenter();

  PendingUserInputContract present({
    required CodexUserInputRequestBlock block,
    required PendingUserInputFormState formState,
  }) {
    final fields = _buildFields(block: block, draft: formState.draft);

    return PendingUserInputContract(
      requestId: block.requestId,
      title: block.title,
      body: block.body,
      fields: fields,
      isResolved: block.isResolved,
      isSubmitting: formState.isSubmitting,
      isSubmitEnabled: !block.isResolved && !formState.isSubmitting,
      submitPayload: _buildSubmitPayload(fields: fields),
      statusBadgeLabel: block.isResolved ? 'submitted' : null,
    );
  }

  List<PendingUserInputFieldContract> _buildFields({
    required CodexUserInputRequestBlock block,
    required PendingUserInputDraft draft,
  }) {
    if (block.questions.isEmpty) {
      if (block.isResolved) {
        return const <PendingUserInputFieldContract>[];
      }

      return <PendingUserInputFieldContract>[
        PendingUserInputFieldContract(
          id: pendingUserInputFallbackFieldId,
          inputLabel: 'Response',
          value: draft.valueForField(pendingUserInputFallbackFieldId),
          isReadOnly: block.isResolved,
          minLines: 2,
          maxLines: 3,
        ),
      ];
    }

    return block.questions
        .map((question) {
          return PendingUserInputFieldContract(
            id: question.id,
            header: question.header,
            prompt: question.question,
            inputLabel: question.isOther ? 'Custom answer' : 'Answer',
            value: draft.valueForField(question.id),
            options: question.options
                .map(
                  (option) => PendingUserInputOptionContract(
                    label: option.label,
                    description: option.description,
                  ),
                )
                .toList(growable: false),
            isSecret: question.isSecret,
            isReadOnly: block.isResolved,
            minLines: 1,
            maxLines: question.isOther ? 4 : 2,
          );
        })
        .toList(growable: false);
  }

  Map<String, List<String>> _buildSubmitPayload({
    required List<PendingUserInputFieldContract> fields,
  }) {
    final payload = <String, List<String>>{};

    for (final field in fields) {
      final normalizedValue = field.value.trim();
      if (normalizedValue.isEmpty) {
        continue;
      }

      payload[field.id] = <String>[normalizedValue];
    }

    return payload;
  }
}
