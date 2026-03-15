import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

const String pendingUserInputFallbackFieldId = 'response';

enum PendingUserInputSubmissionState { idle, submitting }

class PendingUserInputDraft {
  const PendingUserInputDraft({
    this.answersByFieldId = const <String, String>{},
  });

  factory PendingUserInputDraft.fromBlock(CodexUserInputRequestBlock block) {
    return PendingUserInputDraft(
      answersByFieldId: block.answers.map<String, String>((fieldId, answers) {
        return MapEntry<String, String>(fieldId, answers.join(', '));
      }),
    );
  }

  final Map<String, String> answersByFieldId;

  String valueForField(String fieldId) {
    return answersByFieldId[fieldId] ?? '';
  }

  PendingUserInputDraft copyWith({Map<String, String>? answersByFieldId}) {
    return PendingUserInputDraft(
      answersByFieldId: answersByFieldId ?? this.answersByFieldId,
    );
  }

  PendingUserInputDraft copyWithField(String fieldId, String value) {
    return PendingUserInputDraft(
      answersByFieldId: <String, String>{...answersByFieldId, fieldId: value},
    );
  }
}

class PendingUserInputFormState {
  const PendingUserInputFormState({
    required this.draft,
    this.submissionState = PendingUserInputSubmissionState.idle,
  });

  factory PendingUserInputFormState.initial({
    required CodexUserInputRequestBlock block,
  }) {
    return PendingUserInputFormState(
      draft: PendingUserInputDraft.fromBlock(block),
    );
  }

  final PendingUserInputDraft draft;
  final PendingUserInputSubmissionState submissionState;

  bool get isSubmitting =>
      submissionState == PendingUserInputSubmissionState.submitting;

  PendingUserInputFormState copyWith({
    PendingUserInputDraft? draft,
    PendingUserInputSubmissionState? submissionState,
  }) {
    return PendingUserInputFormState(
      draft: draft ?? this.draft,
      submissionState: submissionState ?? this.submissionState,
    );
  }
}
