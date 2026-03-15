import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';

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
