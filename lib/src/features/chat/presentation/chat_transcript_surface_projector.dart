import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_projector.dart';

class ChatTranscriptSurfaceProjector {
  const ChatTranscriptSurfaceProjector({
    ChatTranscriptItemProjector itemProjector =
        const ChatTranscriptItemProjector(),
  }) : _itemProjector = itemProjector;

  final ChatTranscriptItemProjector _itemProjector;

  ChatTranscriptSurfaceContract project({
    required ConnectionProfile profile,
    required CodexSessionState sessionState,
  }) {
    final mainItems = sessionState.transcriptBlocks
        .map(_itemProjector.project)
        .toList(growable: false);
    final pinnedItems = <ChatTranscriptItemContract>[
      if (sessionState.primaryPendingApprovalBlock case final block?)
        _itemProjector.project(block),
      if (sessionState.primaryPendingUserInputBlock case final block?)
        _itemProjector.project(block),
    ];
    final hasVisibleConversation =
        mainItems.isNotEmpty || pinnedItems.isNotEmpty;

    return ChatTranscriptSurfaceContract(
      isConfigured: profile.isReady,
      mainItems: mainItems,
      pinnedItems: pinnedItems,
      emptyState: hasVisibleConversation
          ? null
          : ChatEmptyStateContract(isConfigured: profile.isReady),
    );
  }
}
