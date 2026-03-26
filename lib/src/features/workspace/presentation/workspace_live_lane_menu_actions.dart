import 'package:flutter/widgets.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';

List<ChatChromeMenuAction> buildWorkspaceLiveLaneMenuActions({
  required bool hasWorkspaceHistoryScope,
  required bool isLaneBusy,
  required VoidCallback onShowConversationHistory,
  required VoidCallback onShowSavedConnections,
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
      onSelected: onShowSavedConnections,
    ),
    ChatChromeMenuAction(
      label: ConnectionWorkspaceCopy.closeLaneAction,
      onSelected: onCloseLane,
      isDestructive: true,
      isEnabled: !isLaneBusy,
    ),
  ];
}
