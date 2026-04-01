import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/markdown_style_factory.dart';

class AssistantMessageSurface extends StatelessWidget {
  const AssistantMessageSurface({super.key, required this.block});

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
      isAssistant: true,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (block.isRunning) ...[
                LinearProgressIndicator(
                  minHeight: 2,
                  color: palette.accent,
                  backgroundColor: palette.accent.withValues(alpha: 0.08),
                ),
                const SizedBox(height: 10),
              ],
              MarkdownBody(
                data: block.body.trim().isEmpty
                    ? '_Waiting for content…_'
                    : block.body,
                selectable: true,
                styleSheet: markdownStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
