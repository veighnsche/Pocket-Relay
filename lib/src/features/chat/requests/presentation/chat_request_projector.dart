import 'package:pocket_relay/src/features/chat/requests/domain/codex_request_display.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';

class ChatRequestProjector {
  const ChatRequestProjector();

  ChatApprovalRequestContract projectApprovalBlock(
    TranscriptApprovalRequestBlock block,
  ) {
    return ChatApprovalRequestContract(
      id: block.id,
      createdAt: block.createdAt,
      requestId: block.requestId,
      requestType: block.requestType,
      title: block.title,
      body: block.body,
      isResolved: block.isResolved,
      resolutionLabel: block.resolutionLabel,
    );
  }

  ChatApprovalRequestContract projectPendingApprovalRequest(
    TranscriptSessionPendingRequest request,
  ) {
    return ChatApprovalRequestContract(
      id: 'request_${request.requestId}',
      createdAt: request.createdAt,
      requestId: request.requestId,
      requestType: request.requestType,
      title: codexRequestTitle(request.requestType),
      body: request.detail ?? 'Codex needs a decision before it can continue.',
      isResolved: false,
    );
  }

  ChatUserInputRequestContract projectUserInputBlock(
    TranscriptUserInputRequestBlock block,
  ) {
    return ChatUserInputRequestContract(
      id: block.id,
      createdAt: block.createdAt,
      requestId: block.requestId,
      requestType: block.requestType,
      title: block.title,
      body: block.body,
      isResolved: block.isResolved,
      questions: block.questions,
      answers: block.answers,
    );
  }

  ChatUserInputRequestContract projectPendingUserInputRequest(
    TranscriptSessionPendingUserInputRequest request,
  ) {
    return ChatUserInputRequestContract(
      id: 'request_${request.requestId}',
      createdAt: request.createdAt,
      requestId: request.requestId,
      requestType: request.requestType,
      title: codexRequestTitle(request.requestType),
      body: request.detail ?? codexQuestionsSummary(request.questions),
      isResolved: false,
      questions: request.questions,
    );
  }
}
