import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_item_projector.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_request_projector.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';

class ChatTranscriptItemProjector {
  const ChatTranscriptItemProjector({
    ChatChangedFilesItemProjector changedFilesItemProjector =
        const ChatChangedFilesItemProjector(),
    ChatRequestProjector requestProjector = const ChatRequestProjector(),
  }) : _changedFilesItemProjector = changedFilesItemProjector,
       _requestProjector = requestProjector;

  final ChatChangedFilesItemProjector _changedFilesItemProjector;
  final ChatRequestProjector _requestProjector;

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
        _changedFilesItemProjector.project(changedFilesBlock),
      final CodexApprovalRequestBlock approvalBlock =>
        ChatApprovalRequestItemContract(
          request: _requestProjector.projectApprovalBlock(approvalBlock),
        ),
      final CodexUserInputRequestBlock userInputBlock =>
        ChatUserInputRequestItemContract(
          request: _requestProjector.projectUserInputBlock(userInputBlock),
        ),
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

  ChatTranscriptItemContract projectRequest(ChatRequestContract request) {
    return switch (request) {
      final ChatApprovalRequestContract approvalRequest =>
        ChatApprovalRequestItemContract(request: approvalRequest),
      final ChatUserInputRequestContract userInputRequest =>
        ChatUserInputRequestItemContract(request: userInputRequest),
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
