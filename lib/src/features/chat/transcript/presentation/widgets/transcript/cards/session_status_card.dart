import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ReviewStatusCard extends StatelessWidget {
  const ReviewStatusCard({super.key, required this.block});

  final CodexStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = tealAccent(brightness);
    final cards = ConversationCardPalette.of(context);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.rate_review_outlined,
        label: block.title,
        accent: accent,
      ),
      child: SelectableText(
        block.body,
        style: TextStyle(
          color: cards.textSecondary,
          fontSize: 12.5,
          height: 1.3,
        ),
      ),
    );
  }
}

class ContextCompactedCard extends StatelessWidget {
  const ContextCompactedCard({super.key, required this.block});

  final CodexStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = blueAccent(brightness);
    final cards = ConversationCardPalette.of(context);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.compress_outlined,
        label: block.title,
        accent: accent,
      ),
      child: SelectableText(
        block.body,
        style: TextStyle(
          color: cards.textSecondary,
          fontSize: 12.5,
          height: 1.3,
        ),
      ),
    );
  }
}

class SessionInfoCard extends StatelessWidget {
  const SessionInfoCard({super.key, required this.block});

  final CodexStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = tealAccent(brightness);

    return _SessionStatusBlocker(
      block: block,
      accent: accent,
      icon: Icons.info_outline,
    );
  }
}

class _SessionStatusBlocker extends StatelessWidget {
  const _SessionStatusBlocker({
    required this.block,
    required this.accent,
    required this.icon,
  });

  final CodexStatusBlock block;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return TranscriptBlocker(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranscriptAnnotationHeader(
            icon: icon,
            label: block.title,
            accent: accent,
          ),
          const SizedBox(height: 10),
          SelectableText(
            block.body,
            style: TextStyle(
              color: cards.textSecondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
