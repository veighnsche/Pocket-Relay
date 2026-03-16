import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_surface_projector.dart';

class ChatScreenPresenter {
  const ChatScreenPresenter({
    ChatTranscriptSurfaceProjector transcriptSurfaceProjector =
        const ChatTranscriptSurfaceProjector(),
  }) : _transcriptSurfaceProjector = transcriptSurfaceProjector;

  final ChatTranscriptSurfaceProjector _transcriptSurfaceProjector;

  ChatScreenContract present({
    required bool isLoading,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required CodexSessionState sessionState,
    required ChatComposerDraft composerDraft,
    required ChatTranscriptFollowContract transcriptFollow,
    ConnectionMode? preferredConnectionMode,
  }) {
    final isConfigured = profile.isReady;
    final isBusy = sessionState.isBusy;
    final canSend = isConfigured && !isLoading && !isBusy;
    final displayConnectionMode =
        preferredConnectionMode ?? profile.connectionMode;
    final connectionSettingsProfile =
        displayConnectionMode == profile.connectionMode
        ? profile
        : profile.copyWith(connectionMode: displayConnectionMode);

    return ChatScreenContract(
      isLoading: isLoading,
      header: ChatHeaderContract(
        title: 'Pocket Relay',
        subtitle: isConfigured
            ? switch (profile.connectionMode) {
                ConnectionMode.remote => '${profile.label} · ${profile.host}',
                ConnectionMode.local => '${profile.label} · local Codex',
              }
            : 'Configure Codex',
      ),
      actions: const <ChatScreenActionContract>[
        ChatScreenActionContract(
          id: ChatScreenActionId.openSettings,
          label: 'Connection settings',
          placement: ChatScreenActionPlacement.toolbar,
          tooltip: 'Connection settings',
          icon: ChatScreenActionIcon.settings,
        ),
        ChatScreenActionContract(
          id: ChatScreenActionId.newThread,
          label: 'New thread',
          placement: ChatScreenActionPlacement.menu,
        ),
        ChatScreenActionContract(
          id: ChatScreenActionId.clearTranscript,
          label: 'Clear transcript',
          placement: ChatScreenActionPlacement.menu,
        ),
      ],
      transcriptSurface: _transcriptSurfaceProjector.project(
        profile: profile,
        sessionState: sessionState,
        emptyStateConnectionMode: displayConnectionMode,
      ),
      transcriptFollow: transcriptFollow,
      composer: ChatComposerContract(
        draftText: composerDraft.text,
        isTextInputEnabled: isConfigured && !isLoading && !isBusy,
        isPrimaryActionEnabled: isBusy || canSend,
        isBusy: isBusy,
        placeholder: 'Message Codex',
        primaryAction: isBusy
            ? ChatComposerPrimaryAction.stop
            : ChatComposerPrimaryAction.send,
      ),
      connectionSettings: ChatConnectionSettingsLaunchContract(
        initialProfile: connectionSettingsProfile,
        initialSecrets: secrets,
      ),
      turnIndicator: switch (sessionState.activeTurn?.timer) {
        final timer? when timer.isRunning => ChatTurnIndicatorContract(
          timer: timer,
        ),
        _ => null,
      },
    );
  }
}
