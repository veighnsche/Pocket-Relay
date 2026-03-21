import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';

String codexRequestTitle(CodexCanonicalRequestType requestType) {
  return switch (requestType) {
    CodexCanonicalRequestType.commandExecutionApproval => 'Command approval',
    CodexCanonicalRequestType.fileChangeApproval => 'File change approval',
    CodexCanonicalRequestType.applyPatchApproval => 'Patch approval',
    CodexCanonicalRequestType.execCommandApproval => 'Command approval',
    CodexCanonicalRequestType.permissionsRequestApproval =>
      'Permissions request',
    CodexCanonicalRequestType.toolUserInput => 'Input required',
    CodexCanonicalRequestType.mcpServerElicitation => 'MCP input required',
    CodexCanonicalRequestType.unknown => 'Request',
  };
}

String codexQuestionsSummary(List<CodexRuntimeUserInputQuestion> questions) {
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
  required List<CodexRuntimeUserInputQuestion> questions,
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
