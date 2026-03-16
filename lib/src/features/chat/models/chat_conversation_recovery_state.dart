enum ChatConversationRecoveryReason {
  missingRemoteConversation,
  detachedTranscript,
}

class ChatConversationRecoveryState {
  const ChatConversationRecoveryState({
    required this.reason,
    this.alternateThreadId,
  });

  final ChatConversationRecoveryReason reason;
  final String? alternateThreadId;
}
