import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

sealed class ChatTranscriptItemContract {
  const ChatTranscriptItemContract();

  String get id;
}

final class ChatUserMessageItemContract extends ChatTranscriptItemContract {
  const ChatUserMessageItemContract({required this.block});

  final CodexUserMessageBlock block;

  @override
  String get id => block.id;
}

final class ChatReasoningItemContract extends ChatTranscriptItemContract {
  const ChatReasoningItemContract({required this.block});

  final CodexTextBlock block;

  @override
  String get id => block.id;
}

final class ChatAssistantMessageItemContract
    extends ChatTranscriptItemContract {
  const ChatAssistantMessageItemContract({required this.block});

  final CodexTextBlock block;

  @override
  String get id => block.id;
}

final class ChatPlanUpdateItemContract extends ChatTranscriptItemContract {
  const ChatPlanUpdateItemContract({required this.block});

  final CodexPlanUpdateBlock block;

  @override
  String get id => block.id;
}

final class ChatProposedPlanItemContract extends ChatTranscriptItemContract {
  const ChatProposedPlanItemContract({required this.block});

  final CodexProposedPlanBlock block;

  @override
  String get id => block.id;
}

final class ChatCommandExecutionItemContract
    extends ChatTranscriptItemContract {
  const ChatCommandExecutionItemContract({required this.block});

  final CodexCommandExecutionBlock block;

  @override
  String get id => block.id;
}

final class ChatWorkLogGroupItemContract extends ChatTranscriptItemContract {
  const ChatWorkLogGroupItemContract({required this.block});

  final CodexWorkLogGroupBlock block;

  @override
  String get id => block.id;
}

final class ChatChangedFilesItemContract extends ChatTranscriptItemContract {
  const ChatChangedFilesItemContract({required this.block});

  final CodexChangedFilesBlock block;

  @override
  String get id => block.id;
}

final class ChatApprovalRequestItemContract extends ChatTranscriptItemContract {
  const ChatApprovalRequestItemContract({required this.block});

  final CodexApprovalRequestBlock block;

  @override
  String get id => block.id;
}

final class ChatUserInputRequestItemContract
    extends ChatTranscriptItemContract {
  const ChatUserInputRequestItemContract({required this.block});

  final CodexUserInputRequestBlock block;

  @override
  String get id => block.id;
}

final class ChatStatusItemContract extends ChatTranscriptItemContract {
  const ChatStatusItemContract({required this.block});

  final CodexStatusBlock block;

  @override
  String get id => block.id;
}

final class ChatErrorItemContract extends ChatTranscriptItemContract {
  const ChatErrorItemContract({required this.block});

  final CodexErrorBlock block;

  @override
  String get id => block.id;
}

final class ChatUsageItemContract extends ChatTranscriptItemContract {
  const ChatUsageItemContract({required this.block});

  final CodexUsageBlock block;

  @override
  String get id => block.id;
}

final class ChatTurnBoundaryItemContract extends ChatTranscriptItemContract {
  const ChatTurnBoundaryItemContract({required this.block});

  final CodexTurnBoundaryBlock block;

  @override
  String get id => block.id;
}
