import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/alert_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/approval_decision_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/approval_request_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/assistant_message_card.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/changed_files_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/error_card.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/exec_command_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/pending_user_input_request_host.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/plan_update_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/proposed_plan_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/reasoning_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/session_status_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/ssh/ssh_card_host.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/status_card.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/tool_activity_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/turn_boundary_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/usage_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/user_input_result_card.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/cards/user_message_card.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/work_log_group_card.dart';

class ConversationEntryCard extends StatelessWidget {
  const ConversationEntryCard({
    super.key,
    required this.item,
    this.showsDesktopContextMenu = false,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onOpenChangedFileDiff,
    this.onSubmitUserInput,
    this.onSaveHostFingerprint,
    this.onConfigure,
    this.onContinueFromUserMessage,
  });

  final ChatTranscriptItemContract item;
  final bool showsDesktopContextMenu;
  final Future<void> Function(String requestId)? onApproveRequest;
  final Future<void> Function(String requestId)? onDenyRequest;
  final void Function(ChatChangedFileDiffContract diff)? onOpenChangedFileDiff;
  final Future<void> Function(
    String requestId,
    Map<String, List<String>> answers,
  )?
  onSubmitUserInput;
  final Future<void> Function(String blockId)? onSaveHostFingerprint;
  final VoidCallback? onConfigure;
  final Future<void> Function(String blockId)? onContinueFromUserMessage;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      final ChatUserMessageItemContract userItem => UserMessageCard(
        block: userItem.block,
        canContinueFromHere: userItem.canContinueFromHere,
        showsDesktopContextMenu: showsDesktopContextMenu,
        onContinueFromHere: onContinueFromUserMessage,
      ),
      final ChatReasoningItemContract reasoningItem => ReasoningCard(
        block: reasoningItem.block,
      ),
      final ChatAssistantMessageItemContract assistantItem =>
        AssistantMessageCard(block: assistantItem.block),
      final ChatPlanUpdateItemContract planUpdateItem => PlanUpdateCard(
        block: planUpdateItem.block,
      ),
      final ChatProposedPlanItemContract proposedPlanItem => ProposedPlanCard(
        block: proposedPlanItem.block,
      ),
      final ChatWorkLogGroupItemContract workLogGroupItem => WorkLogGroupCard(
        item: workLogGroupItem,
      ),
      final ChatExecCommandItemContract execCommandItem => ExecCommandCard(
        entry: execCommandItem.entry,
      ),
      final ChatExecWaitItemContract execWaitItem => ExecWaitCard(
        entry: execWaitItem.entry,
      ),
      final ChatWebSearchItemContract webSearchItem => WebSearchActivityCard(
        entry: webSearchItem.entry,
      ),
      final ChatMcpToolCallItemContract mcpItem => McpToolActivityCard(
        entry: mcpItem.entry,
      ),
      final ChatChangedFilesItemContract changedFilesItem => ChangedFilesCard(
        item: changedFilesItem,
        onOpenDiff: onOpenChangedFileDiff,
      ),
      final ChatApprovalRequestItemContract approvalItem =>
        approvalItem.request.isResolved
            ? ApprovalDecisionCard(request: approvalItem.request)
            : ApprovalRequestCard(
                request: approvalItem.request,
                onApprove: onApproveRequest,
                onDeny: onDenyRequest,
              ),
      final ChatUserInputRequestItemContract userInputItem =>
        userInputItem.request.isResolved
            ? UserInputResultCard(request: userInputItem.request)
            : PendingUserInputRequestHost(
                request: userInputItem.request,
                onSubmit: onSubmitUserInput,
              ),
      final ChatSshItemContract sshItem => SshCardHost(
        block: sshItem.block,
        onSaveFingerprint: onSaveHostFingerprint,
        onOpenConnectionSettings: onConfigure,
      ),
      final ChatReviewStatusItemContract reviewItem => ReviewStatusCard(
        block: reviewItem.block,
      ),
      final ChatContextCompactedItemContract compactionItem =>
        ContextCompactedCard(block: compactionItem.block),
      final ChatSessionInfoItemContract sessionInfoItem => SessionInfoCard(
        block: sessionInfoItem.block,
      ),
      final ChatWarningItemContract warningItem => WarningEventCard(
        block: warningItem.block,
      ),
      final ChatDeprecationNoticeItemContract deprecationItem =>
        DeprecationNoticeCard(block: deprecationItem.block),
      final ChatStatusItemContract statusItem => StatusCard(
        block: statusItem.block,
      ),
      final ChatPatchApplyFailureItemContract patchApplyFailureItem =>
        PatchApplyFailureCard(block: patchApplyFailureItem.block),
      final ChatErrorItemContract errorItem => ErrorCard(
        block: errorItem.block,
      ),
      final ChatUsageItemContract usageItem => UsageCard(
        block: usageItem.block,
      ),
      final ChatTurnBoundaryItemContract boundaryItem => TurnBoundaryCard(
        block: boundaryItem.block,
      ),
    };
  }
}
