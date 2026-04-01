import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';

String codexRequestTitle(TranscriptCanonicalRequestType requestType) {
  return switch (requestType) {
    TranscriptCanonicalRequestType.commandExecutionApproval =>
      'Command approval',
    TranscriptCanonicalRequestType.fileChangeApproval => 'File change approval',
    TranscriptCanonicalRequestType.applyPatchApproval => 'Patch approval',
    TranscriptCanonicalRequestType.execCommandApproval => 'Command approval',
    TranscriptCanonicalRequestType.permissionsRequestApproval =>
      'Permissions request',
    TranscriptCanonicalRequestType.toolUserInput => 'Input required',
    TranscriptCanonicalRequestType.mcpServerElicitation => 'MCP input required',
    TranscriptCanonicalRequestType.unknown => 'Request',
  };
}

String codexQuestionsSummary(
  List<TranscriptRuntimeUserInputQuestion> questions,
) {
  return questions
      .map((question) => '${question.header}: ${question.question}')
      .join('\n\n');
}

String codexAnswersSummary(Map<String, List<String>> answers) {
  if (answers.isEmpty) {
    return 'The requested input was submitted.';
  }

  return answers.entries
      .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
      .join('\n');
}

String codexAnswersSummaryFromQuestions({
  required List<TranscriptRuntimeUserInputQuestion> questions,
  required Map<String, List<String>> answers,
}) {
  if (answers.isEmpty) {
    return 'The requested input was submitted.';
  }

  final labelsById = <String, String>{
    for (final question in questions)
      question.id: question.header.trim().isNotEmpty
          ? question.header
          : question.question,
  };

  return answers.entries
      .map((entry) {
        final label = labelsById[entry.key] ?? entry.key;
        return '$label: ${entry.value.join(', ')}';
      })
      .join('\n');
}
