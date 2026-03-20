import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/models/codex_workspace_conversation_summary.dart';

class FakeCodexWorkspaceConversationHistoryRepository
    implements CodexWorkspaceConversationHistoryRepository {
  const FakeCodexWorkspaceConversationHistoryRepository({
    this.conversationsByHost =
        const <String, List<CodexWorkspaceConversationSummary>>{},
    this.fallbackConversations = const <CodexWorkspaceConversationSummary>[],
  });

  final Map<String, List<CodexWorkspaceConversationSummary>>
  conversationsByHost;
  final List<CodexWorkspaceConversationSummary> fallbackConversations;

  @override
  Future<List<CodexWorkspaceConversationSummary>> loadWorkspaceConversations({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    final host = profile.host.trim();
    final conversations = conversationsByHost[host] ?? fallbackConversations;
    return List<CodexWorkspaceConversationSummary>.from(conversations);
  }
}
