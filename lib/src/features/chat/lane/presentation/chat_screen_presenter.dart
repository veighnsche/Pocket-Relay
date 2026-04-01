import 'package:pocket_relay/src/agent_adapters/agent_adapter_capabilities.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_conversation_recovery_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/chat_historical_conversation_restore_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/lane_header/presentation/chat_lane_header_projector.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_surface_projector.dart';

class ChatScreenPresenter {
  const ChatScreenPresenter({
    ChatTranscriptSurfaceProjector transcriptSurfaceProjector =
        const ChatTranscriptSurfaceProjector(),
    ChatLaneHeaderProjector headerProjector = const ChatLaneHeaderProjector(),
  }) : _transcriptSurfaceProjector = transcriptSurfaceProjector,
       _headerProjector = headerProjector;

  final ChatTranscriptSurfaceProjector _transcriptSurfaceProjector;
  final ChatLaneHeaderProjector _headerProjector;

  ChatScreenSessionContract presentSession({
    required bool isLoading,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required CodexSessionState sessionState,
    required ChatConversationRecoveryState? conversationRecoveryState,
    ChatHistoricalConversationRestoreState? historicalConversationRestoreState,
    bool effectiveModelSupportsImages = true,
    AgentAdapterCapabilities? agentAdapterCapabilities,
    ConnectionMode? preferredConnectionMode,
  }) {
    final resolvedAgentAdapterCapabilities =
        agentAdapterCapabilities ??
        agentAdapterCapabilitiesFor(profile.agentAdapter);
    final isConfigured = profile.isReady;
    final hasWorkspaceScope = profile.workspaceDir.trim().isNotEmpty;
    final timelineSummaries = _timelineSummaries(sessionState);
    final conversationRecoveryNotice = _conversationRecoveryNotice(
      conversationRecoveryState,
      timelineSummaries: timelineSummaries,
    );
    final historicalConversationRestoreNotice =
        _historicalConversationRestoreNotice(
          historicalConversationRestoreState,
        );
    final canBranchConversation =
        resolvedAgentAdapterCapabilities.supportsConversationForking &&
        hasWorkspaceScope &&
        !isLoading &&
        sessionState.currentThreadId?.trim().isNotEmpty == true &&
        !sessionState.isBusy &&
        conversationRecoveryNotice == null &&
        historicalConversationRestoreNotice == null;
    final canResetConversation =
        hasWorkspaceScope &&
        !sessionState.isBusy &&
        conversationRecoveryNotice == null &&
        historicalConversationRestoreNotice == null;
    final canSend =
        isConfigured &&
        !isLoading &&
        conversationRecoveryNotice == null &&
        historicalConversationRestoreNotice == null;
    final header = _headerProjector.project(
      profile: profile,
      metadata: sessionState.headerMetadata,
      isConfigured: isConfigured,
    );
    final displayConnectionMode =
        preferredConnectionMode ?? profile.connectionMode;
    final connectionSettingsProfile =
        displayConnectionMode == profile.connectionMode
        ? profile
        : profile.copyWith(connectionMode: displayConnectionMode);

    return ChatScreenSessionContract(
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
          isEnabled: canResetConversation,
        ),
        ChatScreenActionContract(
          id: ChatScreenActionId.branchConversation,
          label: 'Branch conversation',
          placement: ChatScreenActionPlacement.menu,
          isEnabled: canBranchConversation,
        ),
        ChatScreenActionContract(
          id: ChatScreenActionId.clearTranscript,
          label: 'Clear transcript',
          placement: ChatScreenActionPlacement.menu,
          isEnabled: canResetConversation,
        ),
      ],
      timelineSummaries: timelineSummaries,
      transcriptSurface: _transcriptSurfaceProjector.project(
        profile: profile,
        sessionState: sessionState,
        allowsContinueFromHere:
            resolvedAgentAdapterCapabilities.supportsConversationRollback,
        emptyStateConnectionMode: displayConnectionMode,
      ),
      connectionSettings: ChatConnectionSettingsLaunchContract(
        initialProfile: connectionSettingsProfile,
        initialSecrets: secrets,
      ),
      isComposerSendEnabled: canSend,
      allowsImageAttachment:
          isConfigured &&
          resolvedAgentAdapterCapabilities.supportsImageInput &&
          effectiveModelSupportsImages,
      composerPlaceholder: 'Message Codex',
      conversationRecoveryNotice: conversationRecoveryNotice,
      historicalConversationRestoreNotice: historicalConversationRestoreNotice,
      turnIndicator: switch (sessionState.activeTurn?.timer) {
        final timer? when timer.isRunning => ChatTurnIndicatorContract(
          timer: timer,
        ),
        _ => null,
      },
    );
  }

  ChatScreenContract present({
    required bool isLoading,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required CodexSessionState sessionState,
    required ChatConversationRecoveryState? conversationRecoveryState,
    ChatHistoricalConversationRestoreState? historicalConversationRestoreState,
    required ChatComposerDraft composerDraft,
    bool effectiveModelSupportsImages = true,
    AgentAdapterCapabilities? agentAdapterCapabilities,
    required ChatTranscriptFollowContract transcriptFollow,
    ConnectionMode? preferredConnectionMode,
  }) {
    final session = presentSession(
      isLoading: isLoading,
      profile: profile,
      secrets: secrets,
      sessionState: sessionState,
      conversationRecoveryState: conversationRecoveryState,
      historicalConversationRestoreState: historicalConversationRestoreState,
      effectiveModelSupportsImages: effectiveModelSupportsImages,
      agentAdapterCapabilities: agentAdapterCapabilities,
      preferredConnectionMode: preferredConnectionMode,
    );
    return session.compose(
      transcriptFollow: transcriptFollow,
      composerDraft: composerDraft,
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

  ChatHistoricalConversationRestoreNoticeContract?
  _historicalConversationRestoreNotice(
    ChatHistoricalConversationRestoreState? restoreState,
  ) {
    if (restoreState == null) {
      return null;
    }

    return switch (restoreState.phase) {
      ChatHistoricalConversationRestorePhase.loading =>
        const ChatHistoricalConversationRestoreNoticeContract(
          title: 'Loading conversation',
          message:
              'Pocket Relay is restoring this transcript from Codex before the lane can continue.',
          isLoading: true,
        ),
      ChatHistoricalConversationRestorePhase.unavailable =>
        const ChatHistoricalConversationRestoreNoticeContract(
          title: 'Transcript history unavailable',
          message:
              'Codex returned this conversation identity, but not enough transcript content to show what the conversation was about here.',
          isLoading: false,
          actions: <ChatHistoricalConversationRestoreActionContract>[
            ChatHistoricalConversationRestoreActionContract(
              id: ChatHistoricalConversationRestoreActionId.retryRestore,
              label: 'Retry load',
              isPrimary: true,
            ),
            ChatHistoricalConversationRestoreActionContract(
              id: ChatHistoricalConversationRestoreActionId
                  .startFreshConversation,
              label: 'Start new conversation',
            ),
          ],
        ),
      ChatHistoricalConversationRestorePhase.failed =>
        const ChatHistoricalConversationRestoreNoticeContract(
          title: 'Could not restore this conversation',
          message:
              'Pocket Relay could not load the saved transcript from Codex. Retry the load or start a fresh conversation instead.',
          isLoading: false,
          actions: <ChatHistoricalConversationRestoreActionContract>[
            ChatHistoricalConversationRestoreActionContract(
              id: ChatHistoricalConversationRestoreActionId.retryRestore,
              label: 'Retry load',
              isPrimary: true,
            ),
            ChatHistoricalConversationRestoreActionContract(
              id: ChatHistoricalConversationRestoreActionId
                  .startFreshConversation,
              label: 'Start new conversation',
            ),
          ],
        ),
    };
  }
}
