import 'dart:async';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/application/chat_session_controller.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';

import 'chat_composer_draft_host.dart';
import 'chat_screen_effect.dart';
import 'chat_screen_effect_mapper.dart';
import 'chat_transcript_follow_host.dart';

class ConnectionLaneBinding {
  ConnectionLaneBinding({
    required this.connectionId,
    required CodexProfileStore profileStore,
    this.conversationStateStore = const DiscardingCodexConversationStateStore(),
    required this.appServerClient,
    SavedProfile? initialSavedProfile,
    SavedConnectionConversationState initialConversationState =
        const SavedConnectionConversationState(),
    ChatScreenEffectMapper effectMapper = const ChatScreenEffectMapper(),
    bool? supportsLocalConnectionMode,
    bool ownsAppServerClient = false,
  }) : _ownsAppServerClient = ownsAppServerClient,
       sessionController = ChatSessionController(
         profileStore: profileStore,
         conversationStateStore: conversationStateStore,
         appServerClient: appServerClient,
         initialSavedProfile: initialSavedProfile,
         initialConversationState: initialConversationState,
         supportsLocalConnectionMode: supportsLocalConnectionMode,
       ) {
    _screenEffectSubscription = sessionController.snackBarMessages
        .map(effectMapper.mapSnackBarMessage)
        .listen(_screenEffectsController.add);
    unawaited(sessionController.initialize());
  }

  final String connectionId;
  final CodexConversationStateStore conversationStateStore;
  final CodexAppServerClient appServerClient;
  final ChatSessionController sessionController;
  final ChatComposerDraftHost composerDraftHost = ChatComposerDraftHost();
  final ChatTranscriptFollowHost transcriptFollowHost =
      ChatTranscriptFollowHost();
  final bool _ownsAppServerClient;
  final StreamController<ChatScreenEffect> _screenEffectsController =
      StreamController<ChatScreenEffect>.broadcast();
  StreamSubscription<ChatScreenEffect>? _screenEffectSubscription;
  bool _isDisposed = false;

  Stream<ChatScreenEffect> get screenEffects => _screenEffectsController.stream;

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    unawaited(_screenEffectSubscription?.cancel() ?? Future<void>.value());
    sessionController.dispose();
    transcriptFollowHost.dispose();
    composerDraftHost.dispose();
    unawaited(_screenEffectsController.close());
    if (_ownsAppServerClient) {
      unawaited(appServerClient.dispose());
    }
  }
}
