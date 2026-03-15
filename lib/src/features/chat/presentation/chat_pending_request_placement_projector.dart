import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_request_projector.dart';

class ChatPendingRequestPlacementProjector {
  const ChatPendingRequestPlacementProjector({
    ChatRequestProjector requestProjector = const ChatRequestProjector(),
  }) : _requestProjector = requestProjector;

  final ChatRequestProjector _requestProjector;

  ChatPendingRequestPlacementContract project({
    required Map<String, CodexSessionPendingRequest> pendingApprovalRequests,
    required Map<String, CodexSessionPendingUserInputRequest>
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

  CodexSessionPendingRequest? _oldestPendingApprovalRequest(
    Iterable<CodexSessionPendingRequest> requests,
  ) {
    return _oldestPendingRequest(requests, (request) => request.createdAt);
  }

  CodexSessionPendingUserInputRequest? _oldestPendingUserInputRequest(
    Iterable<CodexSessionPendingUserInputRequest> requests,
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
