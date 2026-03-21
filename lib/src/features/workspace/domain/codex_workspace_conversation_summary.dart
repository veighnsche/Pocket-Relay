class CodexWorkspaceConversationSummary {
  const CodexWorkspaceConversationSummary({
    required this.threadId,
    required this.preview,
    required this.cwd,
    required this.promptCount,
    required this.firstPromptAt,
    required this.lastActivityAt,
  });

  final String threadId;
  final String preview;
  final String cwd;
  final int promptCount;
  final DateTime? firstPromptAt;
  final DateTime? lastActivityAt;

  String get normalizedThreadId => threadId.trim();
  String get trimmedPreview => preview.trim();
}
