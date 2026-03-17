enum ChatConversationRecoveryReason {
  missingRemoteConversation,
  detachedTranscript,
  unexpectedRemoteConversation,
}

class ChatConversationRecoveryState {
  const ChatConversationRecoveryState({
    required this.reason,
    this.alternateThreadId,
    this.expectedThreadId,
    this.actualThreadId,
  });

  final ChatConversationRecoveryReason reason;
  final String? alternateThreadId;
  final String? expectedThreadId;
  final String? actualThreadId;
}
