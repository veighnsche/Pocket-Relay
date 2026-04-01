import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ReviewStatusSurface extends StatelessWidget {
  const ReviewStatusSurface({super.key, required this.block});

  final TranscriptStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = tealAccent(brightness);
    final cards = TranscriptPalette.of(context);

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

class ContextCompactedSurface extends StatelessWidget {
  const ContextCompactedSurface({super.key, required this.block});

  final TranscriptStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = blueAccent(brightness);
    final cards = TranscriptPalette.of(context);

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

class SessionInfoSurface extends StatelessWidget {
  const SessionInfoSurface({super.key, required this.block});

  final TranscriptStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = tealAccent(brightness);
    final palette = TranscriptPalette.of(context);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.info_outline,
        label: block.title,
        accent: accent,
      ),
      child: SelectableText(
        block.body,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 12.5,
          height: 1.35,
        ),
      ),
    );
  }
}
