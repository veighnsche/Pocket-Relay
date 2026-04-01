import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

sealed class ChatTranscriptItemContract {
  const ChatTranscriptItemContract();

  String get id;
}

final class ChatUserMessageItemContract extends ChatTranscriptItemContract {
  const ChatUserMessageItemContract({
    required this.block,
    this.canContinueFromHere = false,
  });

  final TranscriptUserMessageBlock block;
  final bool canContinueFromHere;

  @override
  String get id => block.id;
}

final class ChatReasoningItemContract extends ChatTranscriptItemContract {
  const ChatReasoningItemContract({required this.block});

  final TranscriptTextBlock block;

  @override
  String get id => block.id;
}

final class ChatAssistantMessageItemContract
    extends ChatTranscriptItemContract {
  const ChatAssistantMessageItemContract({required this.block});

  final TranscriptTextBlock block;

  @override
  String get id => block.id;
}

final class ChatPlanUpdateItemContract extends ChatTranscriptItemContract {
  const ChatPlanUpdateItemContract({required this.block});

  final TranscriptPlanUpdateBlock block;

  @override
  String get id => block.id;
}

final class ChatProposedPlanItemContract extends ChatTranscriptItemContract {
  const ChatProposedPlanItemContract({required this.block});

  final TranscriptProposedPlanBlock block;

  @override
  String get id => block.id;
}

final class ChatWorkLogGroupItemContract extends ChatTranscriptItemContract {
  const ChatWorkLogGroupItemContract({required this.id, required this.entries});

  @override
  final String id;

  final List<ChatWorkLogEntryContract> entries;

  bool get hasOnlyKnownEntries => entries.every(
    (entry) => entry.entryKind != TranscriptWorkLogEntryKind.unknown,
  );
}

final class ChatExecCommandItemContract extends ChatTranscriptItemContract {
  const ChatExecCommandItemContract({required this.entry});

  final ChatCommandExecutionWorkLogEntryContract entry;

  @override
  String get id => entry.id;
}

final class ChatExecWaitItemContract extends ChatTranscriptItemContract {
  const ChatExecWaitItemContract({required this.entry});

  final ChatCommandWaitWorkLogEntryContract entry;

  @override
  String get id => entry.id;
}

final class ChatWebSearchItemContract extends ChatTranscriptItemContract {
  const ChatWebSearchItemContract({required this.entry});

  final ChatWebSearchWorkLogEntryContract entry;

  @override
  String get id => entry.id;
}

final class ChatChangedFilesItemContract extends ChatTranscriptItemContract {
  const ChatChangedFilesItemContract({
    required this.id,
    required this.title,
    required this.isRunning,
    required this.headerStats,
    required this.rows,
  });

  @override
  final String id;

  final String title;
  final bool isRunning;
  final ChatChangedFileStatsContract headerStats;
  final List<ChatChangedFileRowContract> rows;

  int get fileCount => rows.length;
  bool get hasHeaderStats => headerStats.hasChanges;
}

final class ChatApprovalRequestItemContract extends ChatTranscriptItemContract {
  const ChatApprovalRequestItemContract({required this.request});

  final ChatApprovalRequestContract request;

  @override
  String get id => request.id;
}

final class ChatUserInputRequestItemContract
    extends ChatTranscriptItemContract {
  const ChatUserInputRequestItemContract({required this.request});

  final ChatUserInputRequestContract request;

  @override
  String get id => request.id;
}

final class ChatSshItemContract extends ChatTranscriptItemContract {
  const ChatSshItemContract({required this.block});

  final TranscriptSshTranscriptBlock block;

  @override
  String get id => block.id;
}

final class ChatReviewStatusItemContract extends ChatTranscriptItemContract {
  const ChatReviewStatusItemContract({required this.block});

  final TranscriptStatusBlock block;

  @override
  String get id => block.id;
}

final class ChatContextCompactedItemContract
    extends ChatTranscriptItemContract {
  const ChatContextCompactedItemContract({required this.block});

  final TranscriptStatusBlock block;

  @override
  String get id => block.id;
}

final class ChatSessionInfoItemContract extends ChatTranscriptItemContract {
  const ChatSessionInfoItemContract({required this.block});

  final TranscriptStatusBlock block;

  @override
  String get id => block.id;
}

final class ChatWarningItemContract extends ChatTranscriptItemContract {
  const ChatWarningItemContract({required this.block});

  final TranscriptStatusBlock block;

  @override
  String get id => block.id;
}

final class ChatDeprecationNoticeItemContract
    extends ChatTranscriptItemContract {
  const ChatDeprecationNoticeItemContract({required this.block});

  final TranscriptStatusBlock block;

  @override
  String get id => block.id;
}

final class ChatStatusItemContract extends ChatTranscriptItemContract {
  const ChatStatusItemContract({required this.block});

  final TranscriptStatusBlock block;

  @override
  String get id => block.id;
}

final class ChatPatchApplyFailureItemContract
    extends ChatTranscriptItemContract {
  const ChatPatchApplyFailureItemContract({required this.block});

  final TranscriptErrorBlock block;

  @override
  String get id => block.id;
}

final class ChatErrorItemContract extends ChatTranscriptItemContract {
  const ChatErrorItemContract({required this.block});

  final TranscriptErrorBlock block;

  @override
  String get id => block.id;
}

final class ChatUsageItemContract extends ChatTranscriptItemContract {
  const ChatUsageItemContract({required this.block});

  final TranscriptUsageBlock block;

  @override
  String get id => block.id;
}

final class ChatTurnBoundaryItemContract extends ChatTranscriptItemContract {
  const ChatTurnBoundaryItemContract({required this.block});

  final TranscriptTurnBoundaryBlock block;

  @override
  String get id => block.id;
}
