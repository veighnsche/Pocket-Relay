enum ChatHistoricalConversationRestorePhase { loading, unavailable, failed }

class ChatHistoricalConversationRestoreState {
  const ChatHistoricalConversationRestoreState({
    required this.threadId,
    required this.phase,
  });

  final String threadId;
  final ChatHistoricalConversationRestorePhase phase;
}
