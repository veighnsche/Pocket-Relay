import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class UserMessageCard extends StatelessWidget {
  const UserMessageCard({super.key, required this.block});

  final CodexUserMessageBlock block;

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

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          margin: const EdgeInsets.only(left: 48),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(20),
            border: border,
          ),
          child: SelectableText(
            block.text,
            style: TextStyle(
              color: cards.textPrimary,
              fontSize: 15,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
