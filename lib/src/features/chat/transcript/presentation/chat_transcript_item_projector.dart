import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
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
    CodexUiBlock block, {
    bool canContinueFromHere = false,
  }) {
    return switch (block) {
      final CodexUserMessageBlock userBlock => ChatUserMessageItemContract(
        block: userBlock,
        canContinueFromHere:
            canContinueFromHere &&
            userBlock.deliveryState == CodexUserMessageDeliveryState.sent,
      ),
      final CodexTextBlock textBlock
          when textBlock.kind == CodexUiBlockKind.reasoning =>
        ChatReasoningItemContract(block: textBlock),
      final CodexTextBlock textBlock => ChatAssistantMessageItemContract(
        block: textBlock,
      ),
      final CodexPlanUpdateBlock planUpdateBlock => ChatPlanUpdateItemContract(
        block: planUpdateBlock,
      ),
      final CodexProposedPlanBlock proposedPlanBlock =>
        ChatProposedPlanItemContract(block: proposedPlanBlock),
      final CodexWorkLogGroupBlock workLogGroupBlock =>
        _workLogItemProjector.projectTranscriptItem(workLogGroupBlock),
      final CodexChangedFilesBlock changedFilesBlock =>
        _changedFilesItemProjector.project(changedFilesBlock),
      final CodexApprovalRequestBlock approvalBlock =>
        ChatApprovalRequestItemContract(
          request: _requestProjector.projectApprovalBlock(approvalBlock),
        ),
      final CodexUserInputRequestBlock userInputBlock =>
        ChatUserInputRequestItemContract(
          request: _requestProjector.projectUserInputBlock(userInputBlock),
        ),
      final CodexSshTranscriptBlock sshBlock => ChatSshItemContract(
        block: sshBlock,
      ),
      final CodexStatusBlock statusBlock => _projectStatusItem(statusBlock),
      final CodexErrorBlock errorBlock => _projectErrorItem(errorBlock),
      final CodexUsageBlock usageBlock => ChatUsageItemContract(
        block: usageBlock,
      ),
      final CodexTurnBoundaryBlock boundaryBlock =>
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

  ChatTranscriptItemContract _projectStatusItem(CodexStatusBlock block) {
    return switch (block.statusKind) {
      CodexStatusBlockKind.review => ChatReviewStatusItemContract(block: block),
      CodexStatusBlockKind.compaction => ChatContextCompactedItemContract(
        block: block,
      ),
      CodexStatusBlockKind.info => ChatSessionInfoItemContract(block: block),
      CodexStatusBlockKind.warning =>
        _isDeprecationNotice(block)
            ? ChatDeprecationNoticeItemContract(block: block)
            : ChatWarningItemContract(block: block),
      CodexStatusBlockKind.auth => ChatStatusItemContract(block: block),
    };
  }

  ChatTranscriptItemContract _projectErrorItem(CodexErrorBlock block) {
    if (_isPatchApplyFailure(block)) {
      return ChatPatchApplyFailureItemContract(block: block);
    }
    return ChatErrorItemContract(block: block);
  }

  bool _isDeprecationNotice(CodexStatusBlock block) =>
      block.title.trim().toLowerCase() == 'deprecation notice';

  bool _isPatchApplyFailure(CodexErrorBlock block) =>
      block.title.trim().toLowerCase() == 'patch apply failed';
}
