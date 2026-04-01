import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/markdown_style_factory.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ReasoningSurface extends StatelessWidget {
  const ReasoningSurface({super.key, required this.block});

  final TranscriptTextBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = TranscriptPalette.of(context);
    final palette = paletteFor(block.kind, theme.brightness);
    final markdownStyle = buildConversationMarkdownStyle(
      theme: theme,
      cards: cards,
      accent: palette.accent,
      isAssistant: false,
    );

    return TranscriptAnnotation(
      maxWidth: 660,
      accent: palette.accent,
      header: TranscriptAnnotationHeader(
        icon: palette.icon,
        label: block.title,
        accent: palette.accent,
        trailing: block.isRunning
            ? const InlinePulseChip(label: 'running')
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.isRunning) ...[
            const SizedBox(height: 2),
            LinearProgressIndicator(
              minHeight: 2,
              color: palette.accent,
              backgroundColor: palette.accent.withValues(alpha: 0.08),
            ),
          ],
          if (block.isRunning) const SizedBox(height: PocketSpacing.xs),
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
