import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/composer/presentation/chat_composer_draft.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';

enum ChatScreenActionId {
  openSettings,
  newThread,
  branchConversation,
  clearTranscript,
}

enum ChatScreenActionPlacement { toolbar, menu }

enum ChatScreenActionIcon { settings }

enum ChatConversationRecoveryActionId {
  startFreshConversation,
  openAlternateSession,
}

enum ChatHistoricalConversationRestoreActionId {
  retryRestore,
  startFreshConversation,
}

class ChatConversationRecoveryActionContract {
  const ChatConversationRecoveryActionContract({
    required this.id,
    required this.label,
    this.isPrimary = false,
  });

  final ChatConversationRecoveryActionId id;
  final String label;
  final bool isPrimary;
}

class ChatConversationRecoveryNoticeContract {
  const ChatConversationRecoveryNoticeContract({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String message;
  final List<ChatConversationRecoveryActionContract> actions;
}

class ChatHistoricalConversationRestoreActionContract {
  const ChatHistoricalConversationRestoreActionContract({
    required this.id,
    required this.label,
    this.isPrimary = false,
  });

  final ChatHistoricalConversationRestoreActionId id;
  final String label;
  final bool isPrimary;
}

class ChatHistoricalConversationRestoreNoticeContract {
  const ChatHistoricalConversationRestoreNoticeContract({
    required this.title,
    required this.message,
    required this.isLoading,
    this.actions = const <ChatHistoricalConversationRestoreActionContract>[],
  });

  final String title;
  final String message;
  final bool isLoading;
  final List<ChatHistoricalConversationRestoreActionContract> actions;
}

class ChatScreenActionContract {
  const ChatScreenActionContract({
    required this.id,
    required this.label,
    required this.placement,
    this.tooltip,
    this.icon,
    this.isEnabled = true,
  });

  final ChatScreenActionId id;
  final String label;
  final ChatScreenActionPlacement placement;
  final String? tooltip;
  final ChatScreenActionIcon? icon;
  final bool isEnabled;
}

class ChatHeaderContract {
  const ChatHeaderContract({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class ChatEmptyStateContract {
  const ChatEmptyStateContract({
    required this.isConfigured,
    this.connectionMode = ConnectionMode.remote,
  });

  final bool isConfigured;
  final ConnectionMode connectionMode;
}

class ChatTimelineSummaryContract {
  const ChatTimelineSummaryContract({
    required this.threadId,
    required this.label,
    required this.status,
    required this.isPrimary,
    required this.isSelected,
    required this.isClosed,
    required this.hasUnreadActivity,
    required this.hasPendingRequests,
  });

  final String threadId;
  final String label;
  final CodexAgentLifecycleState status;
  final bool isPrimary;
  final bool isSelected;
  final bool isClosed;
  final bool hasUnreadActivity;
  final bool hasPendingRequests;
}

class ChatTranscriptSurfaceContract {
  const ChatTranscriptSurfaceContract({
    required this.isConfigured,
    required this.mainItems,
    required this.pinnedItems,
    required this.pendingRequestPlacement,
    required this.activePendingUserInputRequestIds,
    int? totalMainItemCount,
    this.emptyState,
  }) : totalMainItemCount = totalMainItemCount ?? mainItems.length,
       assert((totalMainItemCount ?? mainItems.length) >= mainItems.length);

  final bool isConfigured;
  final List<ChatTranscriptItemContract> mainItems;
  final List<ChatTranscriptItemContract> pinnedItems;
  final ChatPendingRequestPlacementContract pendingRequestPlacement;
  final Set<String> activePendingUserInputRequestIds;
  final int totalMainItemCount;
  final ChatEmptyStateContract? emptyState;

  bool get showsEmptyState => emptyState != null;
  int get visibleMainItemCount => mainItems.length;
  int get hiddenOlderMainItemCount => totalMainItemCount - mainItems.length;
  bool get hasHiddenOlderMainItems => hiddenOlderMainItemCount > 0;
}

class ChatComposerContract {
  const ChatComposerContract({
    this.draft = const ChatComposerDraft(),
    required this.isSendActionEnabled,
    this.allowsImageAttachment = false,
    required this.placeholder,
  });

  final ChatComposerDraft draft;
  final bool isSendActionEnabled;
  final bool allowsImageAttachment;
  final String placeholder;

  String get draftText => draft.text;
  bool get hasStructuredDraft => draft.hasStructuredDraft;
}

class ChatTurnIndicatorContract {
  const ChatTurnIndicatorContract({required this.timer});

  final CodexSessionTurnTimer timer;
}

class ChatLaneRestartActionContract {
  const ChatLaneRestartActionContract({
    required this.badgeLabel,
    required this.label,
    this.isInProgress = false,
  });

  final String badgeLabel;
  final String label;
  final bool isInProgress;
}

class ChatConnectionSettingsLaunchContract {
  const ChatConnectionSettingsLaunchContract({
    required this.initialProfile,
    required this.initialSecrets,
  });

  final ConnectionProfile initialProfile;
  final ConnectionSecrets initialSecrets;
}

class ChatScreenSessionContract {
  const ChatScreenSessionContract({
    required this.isLoading,
    required this.header,
    required this.actions,
    this.timelineSummaries = const <ChatTimelineSummaryContract>[],
    required this.transcriptSurface,
    required this.connectionSettings,
    required this.isComposerSendEnabled,
    this.allowsImageAttachment = false,
    required this.composerPlaceholder,
    this.conversationRecoveryNotice,
    this.historicalConversationRestoreNotice,
    this.turnIndicator,
  });

  final bool isLoading;
  final ChatHeaderContract header;
  final List<ChatScreenActionContract> actions;
  final List<ChatTimelineSummaryContract> timelineSummaries;
  final ChatTranscriptSurfaceContract transcriptSurface;
  final ChatConnectionSettingsLaunchContract connectionSettings;
  final bool isComposerSendEnabled;
  final bool allowsImageAttachment;
  final String composerPlaceholder;
  final ChatConversationRecoveryNoticeContract? conversationRecoveryNotice;
  final ChatHistoricalConversationRestoreNoticeContract?
  historicalConversationRestoreNotice;
  final ChatTurnIndicatorContract? turnIndicator;

  List<ChatScreenActionContract> get toolbarActions => actions
      .where((action) => action.placement == ChatScreenActionPlacement.toolbar)
      .toList(growable: false);

  List<ChatScreenActionContract> get menuActions => actions
      .where((action) => action.placement == ChatScreenActionPlacement.menu)
      .toList(growable: false);

  ChatComposerContract composerForDraft(ChatComposerDraft composerDraft) {
    return ChatComposerContract(
      draft: composerDraft,
      isSendActionEnabled: isComposerSendEnabled,
      allowsImageAttachment: allowsImageAttachment,
      placeholder: composerPlaceholder,
    );
  }

  ChatScreenContract compose({
    required ChatTranscriptFollowContract transcriptFollow,
    required ChatComposerDraft composerDraft,
  }) {
    return ChatScreenContract(
      isLoading: isLoading,
      header: header,
      actions: actions,
      timelineSummaries: timelineSummaries,
      transcriptSurface: transcriptSurface,
      transcriptFollow: transcriptFollow,
      composer: composerForDraft(composerDraft),
      connectionSettings: connectionSettings,
      conversationRecoveryNotice: conversationRecoveryNotice,
      historicalConversationRestoreNotice: historicalConversationRestoreNotice,
      turnIndicator: turnIndicator,
    );
  }
}

class ChatScreenContract {
  const ChatScreenContract({
    required this.isLoading,
    required this.header,
    required this.actions,
    this.timelineSummaries = const <ChatTimelineSummaryContract>[],
    required this.transcriptSurface,
    required this.transcriptFollow,
    required this.composer,
    required this.connectionSettings,
    this.conversationRecoveryNotice,
    this.historicalConversationRestoreNotice,
    this.turnIndicator,
  });

  final bool isLoading;
  final ChatHeaderContract header;
  final List<ChatScreenActionContract> actions;
  final List<ChatTimelineSummaryContract> timelineSummaries;
  final ChatTranscriptSurfaceContract transcriptSurface;
  final ChatTranscriptFollowContract transcriptFollow;
  final ChatComposerContract composer;
  final ChatConnectionSettingsLaunchContract connectionSettings;
  final ChatConversationRecoveryNoticeContract? conversationRecoveryNotice;
  final ChatHistoricalConversationRestoreNoticeContract?
  historicalConversationRestoreNotice;
  final ChatTurnIndicatorContract? turnIndicator;

  List<ChatScreenActionContract> get toolbarActions => actions
      .where((action) => action.placement == ChatScreenActionPlacement.toolbar)
      .toList(growable: false);

  List<ChatScreenActionContract> get menuActions => actions
      .where((action) => action.placement == ChatScreenActionPlacement.menu)
      .toList(growable: false);
}
