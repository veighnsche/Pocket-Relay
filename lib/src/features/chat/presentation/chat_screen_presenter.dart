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
  }) {
    final isConfigured = profile.isReady;
    final isBusy = sessionState.isBusy;
    final canSend = isConfigured && !isLoading && !isBusy;
    final timelineSummaries = _timelineSummaries(sessionState);

    return ChatScreenContract(
      isLoading: isLoading,
      header: ChatHeaderContract(
        title: 'Pocket Relay',
        subtitle: isConfigured
            ? '${profile.label} · ${profile.host}'
            : 'Configure a remote box',
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
      timelineSummaries: timelineSummaries,
      transcriptSurface: _transcriptSurfaceProjector.project(
        profile: profile,
        sessionState: sessionState,
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
        initialProfile: profile,
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

  List<ChatTimelineSummaryContract> _timelineSummaries(
    CodexSessionState sessionState,
  ) {
    final entries = sessionState.threadRegistry.values.toList(growable: false)
      ..sort((left, right) => left.displayOrder.compareTo(right.displayOrder));
    if (entries.isEmpty) {
      return const <ChatTimelineSummaryContract>[];
    }

    return entries
        .map((entry) {
          final timeline = sessionState.timelineForThread(entry.threadId);
          return ChatTimelineSummaryContract(
            threadId: entry.threadId,
            label: _timelineLabel(entry),
            status:
                timeline?.lifecycleState ?? CodexAgentLifecycleState.unknown,
            isPrimary: entry.isPrimary,
            isSelected:
                sessionState.effectiveSelectedThreadId == entry.threadId,
            isClosed: entry.isClosed,
            hasUnreadActivity: timeline?.hasUnreadActivity ?? false,
            hasPendingRequests: timeline?.hasPendingRequests ?? false,
          );
        })
        .toList(growable: false);
  }

  String _timelineLabel(CodexThreadRegistryEntry entry) {
    if (entry.isPrimary) {
      return 'Main';
    }
    final nickname = entry.agentNickname?.trim();
    if (nickname != null && nickname.isNotEmpty) {
      return nickname;
    }
    final threadName = entry.threadName?.trim();
    if (threadName != null && threadName.isNotEmpty) {
      return threadName;
    }
    final role = entry.agentRole?.trim();
    if (role != null && role.isNotEmpty) {
      return role;
    }
    if (entry.displayOrder > 0) {
      return 'Agent ${entry.displayOrder}';
    }
    return 'Agent';
  }
}
