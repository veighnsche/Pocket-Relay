import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_projector.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
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
  }) {
    final mainItems = sessionState.transcriptBlocks
        .map(_itemProjector.project)
        .toList(growable: false);
    final pendingRequestPlacement = _pendingRequestPlacementProjector.project(
      pendingApprovalRequests: sessionState.pendingApprovalRequests,
      pendingUserInputRequests: sessionState.pendingUserInputRequests,
    );
    final pinnedItems = pendingRequestPlacement.orderedVisibleRequests
        .map(_itemProjector.projectRequest)
        .toList(growable: false);
    final hasVisibleConversation =
        mainItems.isNotEmpty || pendingRequestPlacement.hasVisibleRequests;

    return ChatTranscriptSurfaceContract(
      isConfigured: profile.isReady,
      mainItems: mainItems,
      pinnedItems: pinnedItems,
      pendingRequestPlacement: pendingRequestPlacement,
      emptyState: hasVisibleConversation
          ? null
          : ChatEmptyStateContract(isConfigured: profile.isReady),
    );
  }
}
