import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_transcript_frame.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/markdown_style_factory.dart';

class ReasoningCard extends StatelessWidget {
  const ReasoningCard({super.key, required this.block});

  final CodexTextBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);
    final palette = paletteFor(block.kind, theme.brightness);
    final markdownStyle = buildConversationMarkdownStyle(
      theme: theme,
      cards: cards,
      accent: palette.accent,
      isAssistant: false,
    );

    return PocketTranscriptFrame(
      maxWidth: 660,
      shadowColor: cards.shadow,
      shadowOpacity: cards.isDark ? 0.2 : 0.06,
      backgroundColor: cards.surface,
      borderColor: palette.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(palette.icon, size: 16, color: palette.accent),
              const SizedBox(width: 7),
              Text(
                block.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.accent,
                  letterSpacing: 0.2,
                ),
              ),
              if (block.isRunning) ...[
                const SizedBox(width: 8),
                const InlinePulseChip(label: 'running'),
              ],
            ],
          ),
          if (block.isRunning) ...[
            const SizedBox(height: PocketSpacing.sm),
            LinearProgressIndicator(
              minHeight: 2,
              color: palette.accent,
              backgroundColor: palette.accent.withValues(alpha: 0.08),
            ),
          ],
          const SizedBox(height: PocketSpacing.xs),
          MarkdownBody(
            data: block.body.trim().isEmpty
                ? '_Waiting for content…_'
                : block.body,
            selectable: true,
            styleSheet: markdownStyle,
          ),
        ],
      ),
    );
  }
}
