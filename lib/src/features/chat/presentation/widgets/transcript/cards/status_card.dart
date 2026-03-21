import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_meta_card.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.block});

  final CodexStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(
      Theme.of(context).brightness,
      block.statusKind,
    );
    return PocketMetaCard(
      title: block.title,
      body: block.body,
      accent: presentation.$1,
      icon: presentation.$2,
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
      CodexStatusBlockKind.info => (
        tealAccent(brightness),
        Icons.info_outline,
      ),
    };
  }
}
