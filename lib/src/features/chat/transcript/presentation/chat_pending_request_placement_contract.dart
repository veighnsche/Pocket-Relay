import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';

class ChatPendingRequestPlacementContract {
  ChatPendingRequestPlacementContract({
    required this.visibleApprovalRequest,
    required this.visibleUserInputRequest,
  }) : orderedVisibleRequests = <ChatRequestContract>[
         ?visibleApprovalRequest,
         ?visibleUserInputRequest,
       ];

  final ChatApprovalRequestContract? visibleApprovalRequest;
  final ChatUserInputRequestContract? visibleUserInputRequest;
  final List<ChatRequestContract> orderedVisibleRequests;

  bool get hasVisibleRequests => orderedVisibleRequests.isNotEmpty;
}
