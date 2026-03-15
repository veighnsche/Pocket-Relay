import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';

class ChatTranscriptItemProjector {
  const ChatTranscriptItemProjector();

  ChatTranscriptItemContract project(CodexUiBlock block) {
    return switch (block) {
      final CodexUserMessageBlock userBlock => ChatUserMessageItemContract(
        block: userBlock,
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
      final CodexCommandExecutionBlock commandBlock =>
        ChatCommandExecutionItemContract(block: commandBlock),
      final CodexWorkLogEntryBlock workLogEntryBlock =>
        ChatWorkLogGroupItemContract(
          block: _workLogGroupBlockForEntry(workLogEntryBlock),
        ),
      final CodexWorkLogGroupBlock workLogGroupBlock =>
        ChatWorkLogGroupItemContract(block: workLogGroupBlock),
      final CodexChangedFilesBlock changedFilesBlock =>
        ChatChangedFilesItemContract(block: changedFilesBlock),
      final CodexApprovalRequestBlock approvalBlock =>
        ChatApprovalRequestItemContract(block: approvalBlock),
      final CodexUserInputRequestBlock userInputBlock =>
        ChatUserInputRequestItemContract(block: userInputBlock),
      final CodexStatusBlock statusBlock => ChatStatusItemContract(
        block: statusBlock,
      ),
      final CodexErrorBlock errorBlock => ChatErrorItemContract(
        block: errorBlock,
      ),
      final CodexUsageBlock usageBlock => ChatUsageItemContract(
        block: usageBlock,
      ),
      final CodexTurnBoundaryBlock boundaryBlock =>
        ChatTurnBoundaryItemContract(block: boundaryBlock),
    };
  }

  CodexWorkLogGroupBlock _workLogGroupBlockForEntry(
    CodexWorkLogEntryBlock block,
  ) {
    return CodexWorkLogGroupBlock(
      id: block.id,
      createdAt: block.createdAt,
      entries: <CodexWorkLogEntry>[
        CodexWorkLogEntry(
          id: block.id,
          createdAt: block.createdAt,
          entryKind: block.entryKind,
          title: block.title,
          turnId: block.turnId,
          preview: block.preview,
          isRunning: block.isRunning,
          exitCode: block.exitCode,
        ),
      ],
    );
  }
}
