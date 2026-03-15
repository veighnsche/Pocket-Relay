import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/utils/duration_utils.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/usage_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class TurnBoundaryCard extends StatelessWidget {
  const TurnBoundaryCard({super.key, required this.block});

  static const separatorRowKey = ValueKey<String>(
    'turn_boundary_separator_row',
  );

  final CodexTurnBoundaryBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final label = block.elapsed == null
        ? block.label
        : '${block.label} · ${formatElapsedDuration(block.elapsed!)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.usage != null) ...[
            UsageCard(block: block.usage!),
            const SizedBox(height: 2),
          ],
          Row(
            key: separatorRowKey,
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: cards.neutralBorder.withValues(alpha: 0.55),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    color: cards.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.45,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: cards.neutralBorder.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
