import 'dart:async';

import 'package:flutter/material.dart';
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
    final canShowContinueAction =
        canContinueFromHere && onContinueFromHere != null;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('user_message_card_${block.id}'),
            borderRadius: BorderRadius.circular(20),
            onLongPress: canShowContinueAction
                ? () => onContinueFromHere!(block.id)
                : null,
            onSecondaryTapDown: canShowContinueAction && showsDesktopContextMenu
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
                    if (canShowContinueAction) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: ValueKey<String>(
                            'continue_from_here_action_${block.id}',
                          ),
                          onPressed: () => onContinueFromHere!(block.id),
                          icon: const Icon(Icons.history, size: 16),
                          label: const Text('Continue From Here'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: cards.textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            backgroundColor: cards.accentBorder(
                              accent,
                              lightAlpha: 0.12,
                              darkAlpha: 0.20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                    ],
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
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selection = await showMenu<_UserMessageCardAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay.size.width - globalPosition.dx,
        overlay.size.height - globalPosition.dy,
      ),
      items: const [
        PopupMenuItem<_UserMessageCardAction>(
          value: _UserMessageCardAction.continueFromHere,
          child: Text('Continue From Here'),
        ),
      ],
    );
    if (selection != _UserMessageCardAction.continueFromHere) {
      return;
    }

    await onContinueFromHere?.call(block.id);
  }
}

enum _UserMessageCardAction { continueFromHere }
