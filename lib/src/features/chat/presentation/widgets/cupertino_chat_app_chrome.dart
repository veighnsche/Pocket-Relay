import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_app_chrome.dart';

class CupertinoChatAppChrome extends StatelessWidget
    implements PreferredSizeWidget {
  const CupertinoChatAppChrome({
    super.key,
    required this.screen,
    required this.onScreenAction,
    this.supplementalMenuActions = const <ChatChromeMenuAction>[],
  });

  final ChatScreenContract screen;
  final ValueChanged<ChatScreenActionId> onScreenAction;
  final List<ChatChromeMenuAction> supplementalMenuActions;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final menuActions = buildChatChromeMenuActions(
      screen: screen,
      onScreenAction: onScreenAction,
      supplementalMenuActions: supplementalMenuActions,
    );

    return CupertinoNavigationBar(
      transitionBetweenRoutes: false,
      automaticallyImplyLeading: false,
      automaticBackgroundVisibility: false,
      middle: ChatAppChromeTitle(
        header: screen.header,
        style: ChatAppChromeStyle.cupertino,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...screen.toolbarActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _ToolbarActionButton(
                action: action,
                onPressed: () => onScreenAction(action.id),
              ),
            ),
          ),
          if (menuActions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: screen.toolbarActions.isEmpty ? 0 : 8,
              ),
              child: ChatOverflowMenuButton(
                key: const ValueKey('cupertino_menu_actions'),
                actions: menuActions,
                style: ChatAppChromeStyle.cupertino,
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolbarActionButton extends StatelessWidget {
  const _ToolbarActionButton({required this.action, required this.onPressed});

  final ChatScreenActionContract action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final message = action.tooltip ?? action.label;
    return Tooltip(
      message: message,
      child: CupertinoButton(
        key: ValueKey<String>('cupertino_toolbar_${action.id.name}'),
        minimumSize: const Size(28, 28),
        padding: EdgeInsets.zero,
        onPressed: onPressed,
        child: Icon(
          chatActionIcon(action, style: ChatAppChromeStyle.cupertino),
          size: 22,
        ),
      ),
    );
  }
}
