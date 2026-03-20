class CodexWorkspaceConversationSummary {
  const CodexWorkspaceConversationSummary({
    required this.sessionId,
    required this.preview,
    required this.cwd,
    required this.messageCount,
    required this.firstPromptAt,
    required this.lastActivityAt,
  });

  final String sessionId;
  final String preview;
  final String cwd;
  final int messageCount;
  final DateTime? firstPromptAt;
  final DateTime? lastActivityAt;

  String get trimmedPreview => preview.trim();
}
