import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_projector.dart';

class ChatPendingRequestPlacementProjector {
  const ChatPendingRequestPlacementProjector({
    ChatRequestProjector requestProjector = const ChatRequestProjector(),
  }) : _requestProjector = requestProjector;

  final ChatRequestProjector _requestProjector;

  ChatPendingRequestPlacementContract project({
    required Map<String, TranscriptSessionPendingRequest>
    pendingApprovalRequests,
    required Map<String, TranscriptSessionPendingUserInputRequest>
    pendingUserInputRequests,
  }) {
    final visibleApprovalRequest = _oldestPendingApprovalRequest(
      pendingApprovalRequests.values,
    );
    final visibleUserInputRequest = _oldestPendingUserInputRequest(
      pendingUserInputRequests.values,
    );

    return ChatPendingRequestPlacementContract(
      visibleApprovalRequest: visibleApprovalRequest == null
          ? null
          : _requestProjector.projectPendingApprovalRequest(
              visibleApprovalRequest,
            ),
      visibleUserInputRequest: visibleUserInputRequest == null
          ? null
          : _requestProjector.projectPendingUserInputRequest(
              visibleUserInputRequest,
            ),
    );
  }

  TranscriptSessionPendingRequest? _oldestPendingApprovalRequest(
    Iterable<TranscriptSessionPendingRequest> requests,
  ) {
    return _oldestPendingRequest(requests, (request) => request.createdAt);
  }

  TranscriptSessionPendingUserInputRequest? _oldestPendingUserInputRequest(
    Iterable<TranscriptSessionPendingUserInputRequest> requests,
  ) {
    return _oldestPendingRequest(requests, (request) => request.createdAt);
  }

  T? _oldestPendingRequest<T>(
    Iterable<T> requests,
    DateTime Function(T request) createdAtOf,
  ) {
    T? oldestRequest;
    DateTime? oldestCreatedAt;

    for (final request in requests) {
      final createdAt = createdAtOf(request);
      if (oldestRequest == null || createdAt.isBefore(oldestCreatedAt!)) {
        oldestRequest = request;
        oldestCreatedAt = createdAt;
      }
    }

    return oldestRequest;
  }
}
