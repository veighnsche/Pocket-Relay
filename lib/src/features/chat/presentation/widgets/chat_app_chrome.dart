import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';

enum ChatAppChromeStyle { material, cupertino }

class ChatAppChromeTitle extends StatelessWidget {
  const ChatAppChromeTitle({
    super.key,
    required this.header,
    required this.style,
  });

  final ChatHeaderContract header;
  final ChatAppChromeStyle style;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      ChatAppChromeStyle.material => _MaterialChatAppChromeTitle(
        header: header,
      ),
      ChatAppChromeStyle.cupertino => _CupertinoChatAppChromeTitle(
        header: header,
      ),
    };
  }
}

class ChatOverflowMenuButton extends StatelessWidget {
  const ChatOverflowMenuButton({
    super.key,
    required this.actions,
    required this.style,
  });

  final List<ChatChromeMenuAction> actions;
  final ChatAppChromeStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: PopupMenuButton<int>(
        tooltip: 'More actions',
        onSelected: (index) => actions[index].onSelected(),
        padding: EdgeInsets.zero,
        itemBuilder: (context) {
          return actions.indexed
              .map(
                (entry) => PopupMenuItem<int>(
                  value: entry.$1,
                  child: Text(
                    entry.$2.label,
                    style: entry.$2.isDestructive
                        ? TextStyle(color: theme.colorScheme.error)
                        : null,
                  ),
                ),
              )
              .toList(growable: false);
        },
        child: SizedBox(
          width: style == ChatAppChromeStyle.cupertino ? 28 : 40,
          height: style == ChatAppChromeStyle.cupertino ? 28 : 40,
          child: Center(
            child: Icon(
              chatOverflowIcon(style),
              size: style == ChatAppChromeStyle.cupertino ? 22 : 24,
            ),
          ),
        ),
      ),
    );
  }
}

List<ChatChromeMenuAction> buildChatChromeMenuActions({
  required ChatScreenContract screen,
  required ValueChanged<ChatScreenActionId> onScreenAction,
  List<ChatChromeMenuAction> supplementalMenuActions =
      const <ChatChromeMenuAction>[],
}) {
  return <ChatChromeMenuAction>[
    ...screen.menuActions.map(
      (action) => ChatChromeMenuAction(
        label: action.label,
        onSelected: () => onScreenAction(action.id),
        isDestructive: action.id == ChatScreenActionId.clearTranscript,
      ),
    ),
    ...supplementalMenuActions,
  ];
}

IconData chatActionIcon(
  ChatScreenActionContract action, {
  required ChatAppChromeStyle style,
}) {
  return switch ((style, action.icon)) {
    (ChatAppChromeStyle.material, ChatScreenActionIcon.settings) => Icons.tune,
    (ChatAppChromeStyle.cupertino, ChatScreenActionIcon.settings) =>
      CupertinoIcons.slider_horizontal_3,
    (ChatAppChromeStyle.material, null) => Icons.more_horiz,
    (ChatAppChromeStyle.cupertino, null) => CupertinoIcons.circle,
  };
}

IconData chatOverflowIcon(ChatAppChromeStyle style) {
  return switch (style) {
    ChatAppChromeStyle.material => Icons.more_horiz,
    ChatAppChromeStyle.cupertino => CupertinoIcons.ellipsis_circle,
  };
}

class _MaterialChatAppChromeTitle extends StatelessWidget {
  const _MaterialChatAppChromeTitle({required this.header});

  final ChatHeaderContract header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(header.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(
          header.subtitle,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _CupertinoChatAppChromeTitle extends StatelessWidget {
  const _CupertinoChatAppChromeTitle({required this.header});

  final ChatHeaderContract header;

  @override
  Widget build(BuildContext context) {
    final titleTextStyle = CupertinoTheme.of(
      context,
    ).textTheme.navTitleTextStyle;
    final subtitleTextStyle = CupertinoTheme.of(context).textTheme.textStyle
        .copyWith(
          fontSize: 11,
          color: CupertinoDynamicColor.resolve(
            CupertinoColors.secondaryLabel,
            context,
          ),
        );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          header.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: titleTextStyle,
        ),
        Text(
          header.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: subtitleTextStyle,
        ),
      ],
    );
  }
}
