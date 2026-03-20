import 'package:pocket_relay/src/features/workspace/models/codex_workspace_conversation_summary.dart';

enum CodexWorkspaceConversationDetailEntryKind {
  userMessage,
  agentMessage,
  toolCall,
  toolResult,
  lifecycle,
}

class CodexWorkspaceConversationDetail {
  const CodexWorkspaceConversationDetail({
    required this.summary,
    required this.sourcePath,
    required this.startedAt,
    required this.entries,
  });

  final CodexWorkspaceConversationSummary summary;
  final String sourcePath;
  final DateTime? startedAt;
  final List<CodexWorkspaceConversationDetailEntry> entries;
}

class CodexWorkspaceConversationDetailEntry {
  const CodexWorkspaceConversationDetailEntry({
    required this.kind,
    required this.title,
    required this.body,
    required this.timestamp,
  });

  final CodexWorkspaceConversationDetailEntryKind kind;
  final String title;
  final String body;
  final DateTime? timestamp;
}
