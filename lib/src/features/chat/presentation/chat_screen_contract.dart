import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';

enum ChatScreenActionId { openSettings, newThread, clearTranscript }

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
    this.emptyState,
  });

  final bool isConfigured;
  final List<ChatTranscriptItemContract> mainItems;
  final List<ChatTranscriptItemContract> pinnedItems;
  final ChatPendingRequestPlacementContract pendingRequestPlacement;
  final Set<String> activePendingUserInputRequestIds;
  final ChatEmptyStateContract? emptyState;

  bool get showsEmptyState => emptyState != null;
}

class ChatComposerContract {
  const ChatComposerContract({
    required this.draftText,
    required this.isSendActionEnabled,
    required this.placeholder,
  });

  final String draftText;
  final bool isSendActionEnabled;
  final String placeholder;
}

class ChatTurnIndicatorContract {
  const ChatTurnIndicatorContract({required this.timer});

  final CodexSessionTurnTimer timer;
}

class ChatConnectionSettingsLaunchContract {
  const ChatConnectionSettingsLaunchContract({
    required this.initialProfile,
    required this.initialSecrets,
  });

  final ConnectionProfile initialProfile;
  final ConnectionSecrets initialSecrets;
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
