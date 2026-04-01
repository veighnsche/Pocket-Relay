import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class StatusSurface extends StatelessWidget {
  const StatusSurface({super.key, required this.block});

  final TranscriptStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(
      Theme.of(context).brightness,
      block.statusKind,
    );
    final cards = TranscriptPalette.of(context);

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
    TranscriptStatusBlockKind kind,
  ) {
    return switch (kind) {
      TranscriptStatusBlockKind.warning => (
        amberAccent(brightness),
        Icons.warning_amber_rounded,
      ),
      TranscriptStatusBlockKind.review => (
        purpleAccent(brightness),
        Icons.rate_review_outlined,
      ),
      TranscriptStatusBlockKind.compaction => (
        blueAccent(brightness),
        Icons.compress_outlined,
      ),
      TranscriptStatusBlockKind.auth => (
        pinkAccent(brightness),
        Icons.lock_reset_outlined,
      ),
      TranscriptStatusBlockKind.info => (
        tealAccent(brightness),
        Icons.info_outline,
      ),
    };
  }
}
