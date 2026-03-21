import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class UserMessageCard extends StatelessWidget {
  const UserMessageCard({
    super.key,
    required this.block,
    this.canContinueFromHere = false,
    this.showsDesktopContextMenu = false,
    this.onContinueFromHere,
  });

  final CodexUserMessageBlock block;
  final bool canContinueFromHere;
  final bool showsDesktopContextMenu;
  final Future<void> Function(String blockId)? onContinueFromHere;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final brightness = Theme.of(context).brightness;
    final isLocalEcho =
        block.deliveryState == CodexUserMessageDeliveryState.localEcho;
    final accent = isLocalEcho
        ? neutralAccent(brightness)
        : tealAccent(brightness);
    final background = cards.tintedSurface(
      accent,
      lightAlpha: isLocalEcho ? 0.03 : 0.05,
      darkAlpha: isLocalEcho ? 0.08 : 0.12,
    );
    final border = Border.all(
      color: cards.accentBorder(
        accent,
        lightAlpha: isLocalEcho ? 0.14 : 0.18,
        darkAlpha: isLocalEcho ? 0.20 : 0.28,
      ),
    );
    final canContinueAction = canContinueFromHere && onContinueFromHere != null;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('user_message_card_${block.id}'),
            borderRadius: BorderRadius.circular(20),
            onLongPress: () => unawaited(
              _showTouchContextMenu(
                context,
                canContinueAction: canContinueAction,
              ),
            ),
            onSecondaryTapDown: showsDesktopContextMenu
                ? (details) {
                    unawaited(
                      _showDesktopContextMenu(context, details.globalPosition),
                    );
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Ink(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
                  border: border,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.text,
                      style: TextStyle(
                        color: cards.textPrimary,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDesktopContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final canContinueAction = canContinueFromHere && onContinueFromHere != null;
    final selection = await _showDesktopMenu(
      context,
      globalPosition: globalPosition,
      canContinueAction: canContinueAction,
    );
    if (selection == null) {
      return;
    }

    await _handleSelection(selection);
  }

  Future<void> _showTouchContextMenu(
    BuildContext context, {
    required bool canContinueAction,
  }) async {
    final selection = await _showTouchActionSheet(
      context,
      canContinueAction: canContinueAction,
    );
    if (selection == null) {
      return;
    }

    await _handleSelection(selection);
  }

  Future<void> _handleSelection(_UserMessageCardAction selection) async {
    switch (selection) {
      case _UserMessageCardAction.copyPrompt:
        await Clipboard.setData(ClipboardData(text: block.text));
        return;
      case _UserMessageCardAction.continueFromHere:
        await onContinueFromHere?.call(block.id);
        return;
    }
  }

  Future<_UserMessageCardAction?> _showDesktopMenu(
    BuildContext context, {
    required Offset globalPosition,
    required bool canContinueAction,
  }) async {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    return showMenu<_UserMessageCardAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      items: [
        const PopupMenuItem<_UserMessageCardAction>(
          value: _UserMessageCardAction.copyPrompt,
          child: Text('Copy Prompt'),
        ),
        PopupMenuItem<_UserMessageCardAction>(
          value: _UserMessageCardAction.continueFromHere,
          enabled: canContinueAction,
          child: const Text('Continue From Here'),
        ),
      ],
    );
  }

  Future<_UserMessageCardAction?> _showTouchActionSheet(
    BuildContext context, {
    required bool canContinueAction,
  }) {
    return showModalBottomSheet<_UserMessageCardAction>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_all_outlined),
                title: const Text('Copy Prompt'),
                onTap: () {
                  Navigator.of(context).pop(_UserMessageCardAction.copyPrompt);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Continue From Here'),
                enabled: canContinueAction,
                onTap: canContinueAction
                    ? () {
                        Navigator.of(
                          context,
                        ).pop(_UserMessageCardAction.continueFromHere);
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _UserMessageCardAction { copyPrompt, continueFromHere }
