import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class WarningEventCard extends StatelessWidget {
  const WarningEventCard({super.key, required this.block});

  final CodexStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final accent = amberAccent(Theme.of(context).brightness);

    return _AlertBlocker(
      title: block.title,
      body: block.body,
      accent: accent,
      icon: Icons.warning_amber_rounded,
    );
  }
}

class DeprecationNoticeCard extends StatelessWidget {
  const DeprecationNoticeCard({super.key, required this.block});

  final CodexStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final accent = redAccent(Theme.of(context).brightness);

    return _AlertBlocker(
      title: block.title,
      body: block.body,
      accent: accent,
      icon: Icons.warning_amber_rounded,
    );
  }
}

class PatchApplyFailureCard extends StatelessWidget {
  const PatchApplyFailureCard({super.key, required this.block});

  final CodexErrorBlock block;

  @override
  Widget build(BuildContext context) {
    final accent = pinkAccent(Theme.of(context).brightness);

    return _AlertBlocker(
      title: block.title,
      body: block.body,
      accent: accent,
      icon: Icons.rule_folder_outlined,
    );
  }
}

class _AlertBlocker extends StatelessWidget {
  const _AlertBlocker({
    required this.title,
    required this.body,
    required this.accent,
    required this.icon,
  });

  final String title;
  final String body;
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
          TranscriptAnnotationHeader(icon: icon, label: title, accent: accent),
          const SizedBox(height: 10),
          SelectableText(
            body,
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
