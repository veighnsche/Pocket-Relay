import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';

List<ChatChromeMenuAction> buildWorkspaceLiveLaneMenuActions({
  required bool hasWorkspaceHistoryScope,
  required bool requiresReconnect,
  required bool isLaneBusy,
  required bool isApplyingSavedSettings,
  required VoidCallback onShowConversationHistory,
  required VoidCallback onShowDormantRoster,
  required VoidCallback onReconnect,
  required VoidCallback onCloseLane,
}) {
  return <ChatChromeMenuAction>[
    ChatChromeMenuAction(
      label: ConnectionWorkspaceCopy.conversationHistoryMenuLabel,
      onSelected: onShowConversationHistory,
      isEnabled: hasWorkspaceHistoryScope && !isLaneBusy,
    ),
    ChatChromeMenuAction(
      label: ConnectionWorkspaceCopy.savedConnectionsMenuLabel,
      onSelected: onShowDormantRoster,
    ),
    if (requiresReconnect)
      ChatChromeMenuAction(
        label: isApplyingSavedSettings
            ? ConnectionWorkspaceCopy.reconnectMenuProgress
            : ConnectionWorkspaceCopy.reconnectMenuAction,
        onSelected: onReconnect,
        isEnabled: !isApplyingSavedSettings && !isLaneBusy,
      ),
    ChatChromeMenuAction(
      label: ConnectionWorkspaceCopy.closeLaneAction,
      onSelected: onCloseLane,
      isDestructive: true,
      isEnabled: hasWorkspaceHistoryScope && !isLaneBusy,
    ),
  ];
}
