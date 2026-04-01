import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_item_projector.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_projector.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_item_projector.dart';

class ChatTranscriptItemProjector {
  const ChatTranscriptItemProjector({
    ChatChangedFilesItemProjector changedFilesItemProjector =
        const ChatChangedFilesItemProjector(),
    ChatRequestProjector requestProjector = const ChatRequestProjector(),
    ChatWorkLogItemProjector workLogItemProjector =
        const ChatWorkLogItemProjector(),
  }) : _changedFilesItemProjector = changedFilesItemProjector,
       _requestProjector = requestProjector,
       _workLogItemProjector = workLogItemProjector;

  final ChatChangedFilesItemProjector _changedFilesItemProjector;
  final ChatRequestProjector _requestProjector;
  final ChatWorkLogItemProjector _workLogItemProjector;

  ChatTranscriptItemContract project(
    TranscriptUiBlock block, {
    bool canContinueFromHere = false,
  }) {
    return switch (block) {
      final TranscriptUserMessageBlock userBlock => ChatUserMessageItemContract(
        block: userBlock,
        canContinueFromHere:
            canContinueFromHere &&
            userBlock.deliveryState == TranscriptUserMessageDeliveryState.sent,
      ),
      final TranscriptTextBlock textBlock
          when textBlock.kind == TranscriptUiBlockKind.reasoning =>
        ChatReasoningItemContract(block: textBlock),
      final TranscriptTextBlock textBlock => ChatAssistantMessageItemContract(
        block: textBlock,
      ),
      final TranscriptPlanUpdateBlock planUpdateBlock =>
        ChatPlanUpdateItemContract(block: planUpdateBlock),
      final TranscriptProposedPlanBlock proposedPlanBlock =>
        ChatProposedPlanItemContract(block: proposedPlanBlock),
      final TranscriptWorkLogGroupBlock workLogGroupBlock =>
        _workLogItemProjector.projectTranscriptItem(workLogGroupBlock),
      final TranscriptChangedFilesBlock changedFilesBlock =>
        _changedFilesItemProjector.project(changedFilesBlock),
      final TranscriptApprovalRequestBlock approvalBlock =>
        ChatApprovalRequestItemContract(
          request: _requestProjector.projectApprovalBlock(approvalBlock),
        ),
      final TranscriptUserInputRequestBlock userInputBlock =>
        ChatUserInputRequestItemContract(
          request: _requestProjector.projectUserInputBlock(userInputBlock),
        ),
      final TranscriptSshTranscriptBlock sshBlock => ChatSshItemContract(
        block: sshBlock,
      ),
      final TranscriptStatusBlock statusBlock => _projectStatusItem(
        statusBlock,
      ),
      final TranscriptErrorBlock errorBlock => _projectErrorItem(errorBlock),
      final TranscriptUsageBlock usageBlock => ChatUsageItemContract(
        block: usageBlock,
      ),
      final TranscriptTurnBoundaryBlock boundaryBlock =>
        ChatTurnBoundaryItemContract(block: boundaryBlock),
    };
  }

  ChatTranscriptItemContract projectRequest(ChatRequestContract request) {
    return switch (request) {
      final ChatApprovalRequestContract approvalRequest =>
        ChatApprovalRequestItemContract(request: approvalRequest),
      final ChatUserInputRequestContract userInputRequest =>
        ChatUserInputRequestItemContract(request: userInputRequest),
    };
  }

  ChatTranscriptItemContract _projectStatusItem(TranscriptStatusBlock block) {
    return switch (block.statusKind) {
      TranscriptStatusBlockKind.review => ChatReviewStatusItemContract(
        block: block,
      ),
      TranscriptStatusBlockKind.compaction => ChatContextCompactedItemContract(
        block: block,
      ),
      TranscriptStatusBlockKind.info => ChatSessionInfoItemContract(
        block: block,
      ),
      TranscriptStatusBlockKind.warning =>
        _isDeprecationNotice(block)
            ? ChatDeprecationNoticeItemContract(block: block)
            : ChatWarningItemContract(block: block),
      TranscriptStatusBlockKind.auth => ChatStatusItemContract(block: block),
    };
  }

  ChatTranscriptItemContract _projectErrorItem(TranscriptErrorBlock block) {
    if (_isPatchApplyFailure(block)) {
      return ChatPatchApplyFailureItemContract(block: block);
    }
    return ChatErrorItemContract(block: block);
  }

  bool _isDeprecationNotice(TranscriptStatusBlock block) =>
      block.title.trim().toLowerCase() == 'deprecation notice';

  bool _isPatchApplyFailure(TranscriptErrorBlock block) =>
      block.title.trim().toLowerCase() == 'patch apply failed';
}
