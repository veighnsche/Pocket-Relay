import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';

enum ChatScreenActionId { openSettings, newThread, clearTranscript }

enum ChatScreenActionPlacement { toolbar, menu }

enum ChatScreenActionIcon { settings }

class ChatScreenActionContract {
  const ChatScreenActionContract({
    required this.id,
    required this.label,
    required this.placement,
    this.tooltip,
    this.icon,
  });

  final ChatScreenActionId id;
  final String label;
  final ChatScreenActionPlacement placement;
  final String? tooltip;
  final ChatScreenActionIcon? icon;
}

class ChatHeaderContract {
  const ChatHeaderContract({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class ChatEmptyStateContract {
  const ChatEmptyStateContract({required this.isConfigured});

  final bool isConfigured;
}

class ChatTranscriptSurfaceContract {
  const ChatTranscriptSurfaceContract({
    required this.isConfigured,
    required this.mainItems,
    required this.pinnedItems,
    this.emptyState,
  });

  final bool isConfigured;
  final List<ChatTranscriptItemContract> mainItems;
  final List<ChatTranscriptItemContract> pinnedItems;
  final ChatEmptyStateContract? emptyState;

  bool get showsEmptyState => emptyState != null;
}

enum ChatComposerPrimaryAction { send, stop }

class ChatComposerContract {
  const ChatComposerContract({
    required this.isTextInputEnabled,
    required this.isPrimaryActionEnabled,
    required this.isBusy,
    required this.placeholder,
    required this.primaryAction,
  });

  final bool isTextInputEnabled;
  final bool isPrimaryActionEnabled;
  final bool isBusy;
  final String placeholder;
  final ChatComposerPrimaryAction primaryAction;
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
    required this.transcriptSurface,
    required this.transcriptFollow,
    required this.composer,
    required this.connectionSettings,
    this.turnIndicator,
  });

  final bool isLoading;
  final ChatHeaderContract header;
  final List<ChatScreenActionContract> actions;
  final ChatTranscriptSurfaceContract transcriptSurface;
  final ChatTranscriptFollowContract transcriptFollow;
  final ChatComposerContract composer;
  final ChatConnectionSettingsLaunchContract connectionSettings;
  final ChatTurnIndicatorContract? turnIndicator;

  List<ChatScreenActionContract> get toolbarActions => actions
      .where((action) => action.placement == ChatScreenActionPlacement.toolbar)
      .toList(growable: false);

  List<ChatScreenActionContract> get menuActions => actions
      .where((action) => action.placement == ChatScreenActionPlacement.menu)
      .toList(growable: false);
}
