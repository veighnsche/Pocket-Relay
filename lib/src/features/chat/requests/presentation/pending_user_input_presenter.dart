import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_draft.dart';

class PendingUserInputPresenter {
  const PendingUserInputPresenter();

  PendingUserInputContract present({
    required ChatUserInputRequestContract request,
    required PendingUserInputFormState formState,
  }) {
    final fields = _buildFields(request: request, draft: formState.draft);

    return PendingUserInputContract(
      requestId: request.requestId,
      title: request.title,
      body: request.body,
      fields: fields,
      isResolved: request.isResolved,
      isSubmitting: formState.isSubmitting,
      isSubmitEnabled: !request.isResolved && !formState.isSubmitting,
      submitPayload: _buildSubmitPayload(fields: fields),
      statusBadgeLabel: request.isResolved ? 'submitted' : null,
    );
  }

  List<PendingUserInputFieldContract> _buildFields({
    required ChatUserInputRequestContract request,
    required PendingUserInputDraft draft,
  }) {
    if (request.isResolved) {
      return const <PendingUserInputFieldContract>[];
    }

    if (request.questions.isEmpty) {
      return <PendingUserInputFieldContract>[
        PendingUserInputFieldContract(
          id: pendingUserInputFallbackFieldId,
          inputLabel: 'Response',
          value: draft.valueForField(pendingUserInputFallbackFieldId),
          isReadOnly: request.isResolved,
          minLines: 2,
          maxLines: 3,
        ),
      ];
    }

    return request.questions
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
            isReadOnly: request.isResolved,
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
