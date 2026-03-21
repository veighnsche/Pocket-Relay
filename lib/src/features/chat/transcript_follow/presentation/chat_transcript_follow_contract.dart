enum ChatTranscriptFollowRequestSource {
  sendPrompt,
  newThread,
  clearTranscript,
}

class ChatTranscriptFollowRequestContract {
  const ChatTranscriptFollowRequestContract({
    required this.id,
    required this.source,
  });

  final int id;
  final ChatTranscriptFollowRequestSource source;
}

class ChatTranscriptFollowContract {
  const ChatTranscriptFollowContract({
    required this.isAutoFollowEnabled,
    required this.resumeDistance,
    this.request,
  });

  final bool isAutoFollowEnabled;
  final double resumeDistance;
  final ChatTranscriptFollowRequestContract? request;
}
