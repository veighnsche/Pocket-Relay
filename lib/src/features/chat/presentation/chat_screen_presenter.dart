import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/chat_conversation_recovery_state.dart';
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
    required ChatConversationRecoveryState? conversationRecoveryState,
    required ChatComposerDraft composerDraft,
    required ChatTranscriptFollowContract transcriptFollow,
    ConnectionMode? preferredConnectionMode,
  }) {
    final isConfigured = profile.isReady;
    final hasWorkspaceScope = profile.workspaceDir.trim().isNotEmpty;
    final isBusy = sessionState.isBusy;
    final timelineSummaries = _timelineSummaries(sessionState);
    final conversationRecoveryNotice = _conversationRecoveryNotice(
      conversationRecoveryState,
      timelineSummaries: timelineSummaries,
    );
    final canSend =
        isConfigured &&
        !isLoading &&
        !isBusy &&
        conversationRecoveryNotice == null;
    final header = _header(
      profile: profile,
      sessionState: sessionState,
      isConfigured: isConfigured,
    );
    final displayConnectionMode =
        preferredConnectionMode ?? profile.connectionMode;
    final connectionSettingsProfile =
        displayConnectionMode == profile.connectionMode
        ? profile
        : profile.copyWith(connectionMode: displayConnectionMode);

    return ChatScreenContract(
      isLoading: isLoading,
      header: header,
      actions: <ChatScreenActionContract>[
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
          isEnabled: hasWorkspaceScope,
        ),
        ChatScreenActionContract(
          id: ChatScreenActionId.clearTranscript,
          label: 'Clear transcript',
          placement: ChatScreenActionPlacement.menu,
          isEnabled: hasWorkspaceScope,
        ),
      ],
      timelineSummaries: timelineSummaries,
      transcriptSurface: _transcriptSurfaceProjector.project(
        profile: profile,
        sessionState: sessionState,
        emptyStateConnectionMode: displayConnectionMode,
      ),
      transcriptFollow: transcriptFollow,
      composer: ChatComposerContract(
        draftText: composerDraft.text,
        isSendActionEnabled: canSend,
        placeholder: 'Message Codex',
      ),
      connectionSettings: ChatConnectionSettingsLaunchContract(
        initialProfile: connectionSettingsProfile,
        initialSecrets: secrets,
      ),
      conversationRecoveryNotice: conversationRecoveryNotice,
      turnIndicator: switch (sessionState.activeTurn?.timer) {
        final timer? when timer.isRunning => ChatTurnIndicatorContract(
          timer: timer,
        ),
        _ => null,
      },
    );
  }

  ChatHeaderContract _header({
    required ConnectionProfile profile,
    required CodexSessionState sessionState,
    required bool isConfigured,
  }) {
    final title = _workspaceProjectTitle(
      sessionState.headerMetadata.cwd,
      fallbackPath: profile.workspaceDir,
    );
    final subtitle = _sessionSubtitle(
      sessionState: sessionState,
      isConfigured: isConfigured,
    );
    return ChatHeaderContract(title: title, subtitle: subtitle);
  }

  String _workspaceProjectTitle(
    String? liveCwd, {
    required String fallbackPath,
  }) {
    final projectName =
        _projectNameFromPath(liveCwd) ?? _projectNameFromPath(fallbackPath);
    if (projectName != null) {
      return projectName;
    }
    return 'Codex';
  }

  String _sessionSubtitle({
    required CodexSessionState sessionState,
    required bool isConfigured,
  }) {
    final model = sessionState.headerMetadata.model?.trim();
    final effort = sessionState.headerMetadata.reasoningEffort?.trim();
    if (model != null && model.isNotEmpty) {
      final normalizedEffort = _formatReasoningEffort(effort);
      if (normalizedEffort == null) {
        return model;
      }
      return '$model · $normalizedEffort';
    }
    if (!isConfigured) {
      return 'Configure Codex';
    }
    return 'Waiting for Codex session';
  }

  String? _projectNameFromPath(String? path) {
    final normalized = path?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final trimmed = normalized.replaceAll(RegExp(r'[\\/]+$'), '');
    if (trimmed.isEmpty) {
      return null;
    }
    final parts = trimmed.split(RegExp(r'[\\/]'));
    final candidate = parts.isEmpty ? trimmed : parts.last.trim();
    return candidate.isEmpty ? null : candidate;
  }

  String? _formatReasoningEffort(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return switch (normalized) {
      'none' => 'no effort',
      'minimal' => 'minimal effort',
      'low' => 'low effort',
      'medium' => 'medium effort',
      'high' => 'high effort',
      'xhigh' => 'xhigh effort',
      _ => normalized,
    };
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
            isSelected: sessionState.currentThreadId == entry.threadId,
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

  ChatConversationRecoveryNoticeContract? _conversationRecoveryNotice(
    ChatConversationRecoveryState? recoveryState, {
    required List<ChatTimelineSummaryContract> timelineSummaries,
  }) {
    if (recoveryState == null) {
      return null;
    }

    final actions = <ChatConversationRecoveryActionContract>[
      const ChatConversationRecoveryActionContract(
        id: ChatConversationRecoveryActionId.startFreshConversation,
        label: 'Start new conversation',
        isPrimary: true,
      ),
    ];
    final alternateThreadId = recoveryState.alternateThreadId;
    if (alternateThreadId != null &&
        timelineSummaries.any(
          (summary) => summary.threadId == alternateThreadId,
        )) {
      actions.add(
        const ChatConversationRecoveryActionContract(
          id: ChatConversationRecoveryActionId.openAlternateSession,
          label: 'Open active session',
        ),
      );
    }

    return switch (recoveryState.reason) {
      ChatConversationRecoveryReason.missingRemoteConversation =>
        ChatConversationRecoveryNoticeContract(
          title: "This conversation can't continue.",
          message:
              'The transcript is still here, but the remote conversation is no longer available. Your draft is preserved below.',
          actions: actions,
        ),
      ChatConversationRecoveryReason.detachedTranscript =>
        ChatConversationRecoveryNoticeContract(
          title: 'Choose how to continue.',
          message:
              'This transcript is no longer linked to the active remote conversation. Sending now would switch context without the earlier history. Your draft is preserved below.',
          actions: actions,
        ),
      ChatConversationRecoveryReason.unexpectedRemoteConversation =>
        ChatConversationRecoveryNoticeContract(
          title: 'Conversation identity changed.',
          message:
              'Pocket Relay expected thread "${recoveryState.expectedThreadId ?? 'unknown'}", '
              'but the remote session returned "${recoveryState.actualThreadId ?? 'unknown'}". '
              'Sending is blocked because that would attach your draft to a different conversation.',
          actions: actions,
        ),
    };
  }
}
