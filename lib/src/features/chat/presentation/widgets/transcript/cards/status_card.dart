import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.block});

  final CodexStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(
      Theme.of(context).brightness,
      block.statusKind,
    );
    final cards = ConversationCardPalette.of(context);

    return TranscriptAnnotation(
      accent: presentation.$1,
      header: TranscriptAnnotationHeader(
        icon: presentation.$2,
        label: block.title,
        accent: presentation.$1,
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

  (Color, IconData) _presentationFor(
    Brightness brightness,
    CodexStatusBlockKind kind,
  ) {
    return switch (kind) {
      CodexStatusBlockKind.warning => (
        amberAccent(brightness),
        Icons.warning_amber_rounded,
      ),
      CodexStatusBlockKind.review => (
        purpleAccent(brightness),
        Icons.rate_review_outlined,
      ),
      CodexStatusBlockKind.compaction => (
        blueAccent(brightness),
        Icons.compress_outlined,
      ),
      CodexStatusBlockKind.auth => (
        pinkAccent(brightness),
        Icons.lock_reset_outlined,
      ),
      CodexStatusBlockKind.info => (tealAccent(brightness), Icons.info_outline),
    };
  }
}
