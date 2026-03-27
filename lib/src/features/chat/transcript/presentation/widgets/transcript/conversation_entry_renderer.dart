import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/alert_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/approval_decision_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/approval_request_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/assistant_message_surface.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/changed_files_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/error_surface.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/exec_command_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/pending_user_input_request_host.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/plan_update_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/proposed_plan_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/reasoning_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/session_status_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_surface_host.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/status_surface.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/tool_activity_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/turn_boundary_marker.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/usage_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/user_input_result_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/user_message_surface.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/work_log_group_surface.dart';

class ConversationEntryRenderer extends StatelessWidget {
  const ConversationEntryRenderer({
    super.key,
    required this.item,
    this.showsDesktopContextMenu = false,
    this.onApproveRequest,
    this.onDenyRequest,
    this.onOpenChangedFileDiff,
    this.onOpenWorkLogTerminal,
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
  final void Function(ChatWorkLogTerminalContract terminal)?
  onOpenWorkLogTerminal;
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
      final ChatUserMessageItemContract userItem => UserMessageSurface(
        block: userItem.block,
        canContinueFromHere: userItem.canContinueFromHere,
        showsDesktopContextMenu: showsDesktopContextMenu,
        onContinueFromHere: onContinueFromUserMessage,
      ),
      final ChatReasoningItemContract reasoningItem => ReasoningSurface(
        block: reasoningItem.block,
      ),
      final ChatAssistantMessageItemContract assistantItem =>
        AssistantMessageSurface(block: assistantItem.block),
      final ChatPlanUpdateItemContract planUpdateItem => PlanUpdateSurface(
        block: planUpdateItem.block,
      ),
      final ChatProposedPlanItemContract proposedPlanItem =>
        ProposedPlanSurface(block: proposedPlanItem.block),
      final ChatWorkLogGroupItemContract workLogGroupItem =>
        WorkLogGroupSurface(
          item: workLogGroupItem,
          onOpenTerminal: onOpenWorkLogTerminal,
        ),
      final ChatExecCommandItemContract execCommandItem => ExecCommandSurface(
        entry: execCommandItem.entry,
        onOpenTerminal: onOpenWorkLogTerminal,
      ),
      final ChatExecWaitItemContract execWaitItem => ExecWaitSurface(
        entry: execWaitItem.entry,
        onOpenTerminal: onOpenWorkLogTerminal,
      ),
      final ChatWebSearchItemContract webSearchItem => WebSearchActivitySurface(
        entry: webSearchItem.entry,
      ),
      final ChatChangedFilesItemContract changedFilesItem =>
        ChangedFilesSurface(
          item: changedFilesItem,
          onOpenDiff: onOpenChangedFileDiff,
        ),
      final ChatApprovalRequestItemContract approvalItem =>
        approvalItem.request.isResolved
            ? ApprovalDecisionSurface(request: approvalItem.request)
            : ApprovalRequestSurface(
                request: approvalItem.request,
                onApprove: onApproveRequest,
                onDeny: onDenyRequest,
              ),
      final ChatUserInputRequestItemContract userInputItem =>
        userInputItem.request.isResolved
            ? UserInputResultSurface(request: userInputItem.request)
            : PendingUserInputRequestHost(
                request: userInputItem.request,
                onSubmit: onSubmitUserInput,
              ),
      final ChatSshItemContract sshItem => SshSurfaceHost(
        block: sshItem.block,
        onSaveFingerprint: onSaveHostFingerprint,
        onOpenConnectionSettings: onConfigure,
      ),
      final ChatReviewStatusItemContract reviewItem => ReviewStatusSurface(
        block: reviewItem.block,
      ),
      final ChatContextCompactedItemContract compactionItem =>
        ContextCompactedSurface(block: compactionItem.block),
      final ChatSessionInfoItemContract sessionInfoItem => SessionInfoSurface(
        block: sessionInfoItem.block,
      ),
      final ChatWarningItemContract warningItem => WarningEventSurface(
        block: warningItem.block,
      ),
      final ChatDeprecationNoticeItemContract deprecationItem =>
        DeprecationNoticeSurface(block: deprecationItem.block),
      final ChatStatusItemContract statusItem => StatusSurface(
        block: statusItem.block,
      ),
      final ChatPatchApplyFailureItemContract patchApplyFailureItem =>
        PatchApplyFailureSurface(block: patchApplyFailureItem.block),
      final ChatErrorItemContract errorItem => ErrorSurface(
        block: errorItem.block,
      ),
      final ChatUsageItemContract usageItem => UsageSurface(
        block: usageItem.block,
      ),
      final ChatTurnBoundaryItemContract boundaryItem => TurnBoundaryMarker(
        block: boundaryItem.block,
      ),
    };
  }
}
