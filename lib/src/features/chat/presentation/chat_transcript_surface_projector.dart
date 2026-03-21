import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_projector.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_projector.dart';

class ChatTranscriptSurfaceProjector {
  const ChatTranscriptSurfaceProjector({
    ChatTranscriptItemProjector itemProjector =
        const ChatTranscriptItemProjector(),
    ChatPendingRequestPlacementProjector pendingRequestPlacementProjector =
        const ChatPendingRequestPlacementProjector(),
  }) : _itemProjector = itemProjector,
       _pendingRequestPlacementProjector = pendingRequestPlacementProjector;

  final ChatTranscriptItemProjector _itemProjector;
  final ChatPendingRequestPlacementProjector _pendingRequestPlacementProjector;

  ChatTranscriptSurfaceContract project({
    required ConnectionProfile profile,
    required CodexSessionState sessionState,
    ConnectionMode? emptyStateConnectionMode,
  }) {
    final canContinueFromHere =
        sessionState.rootThreadId != null &&
        sessionState.currentThreadId == sessionState.rootThreadId &&
        !sessionState.isBusy;
    final mainItems = sessionState.transcriptBlocks
        .map(
          (block) => _itemProjector.project(
            block,
            canContinueFromHere: canContinueFromHere,
          ),
        )
        .toList(growable: false);
    final pendingRequestPlacement = _pendingRequestPlacementProjector.project(
      pendingApprovalRequests: sessionState.pendingApprovalRequests,
      pendingUserInputRequests: sessionState.pendingUserInputRequests,
    );
    final pinnedItems = pendingRequestPlacement.orderedVisibleRequests
        .map(_itemProjector.projectRequest)
        .toList(growable: false);
    final activePendingUserInputRequestIds = _activePendingUserInputRequestIds(
      mainItems: mainItems,
      pendingRequestPlacement: pendingRequestPlacement,
    );
    final hasVisibleConversation =
        mainItems.isNotEmpty || pendingRequestPlacement.hasVisibleRequests;

    return ChatTranscriptSurfaceContract(
      isConfigured: profile.isReady,
      mainItems: mainItems,
      pinnedItems: pinnedItems,
      pendingRequestPlacement: pendingRequestPlacement,
      activePendingUserInputRequestIds: activePendingUserInputRequestIds,
      emptyState: hasVisibleConversation
          ? null
          : ChatEmptyStateContract(
              isConfigured: profile.isReady,
              connectionMode:
                  emptyStateConnectionMode ?? profile.connectionMode,
            ),
    );
  }

  Set<String> _activePendingUserInputRequestIds({
    required List<ChatTranscriptItemContract> mainItems,
    required ChatPendingRequestPlacementContract pendingRequestPlacement,
  }) {
    final activeRequestIds = <String>{};

    for (final item in mainItems) {
      if (item case final ChatUserInputRequestItemContract userInputItem
          when !userInputItem.request.isResolved) {
        activeRequestIds.add(userInputItem.request.requestId);
      }
    }

    final visibleUserInputRequest =
        pendingRequestPlacement.visibleUserInputRequest;
    if (visibleUserInputRequest != null &&
        !visibleUserInputRequest.isResolved) {
      activeRequestIds.add(visibleUserInputRequest.requestId);
    }

    return activeRequestIds;
  }
}
