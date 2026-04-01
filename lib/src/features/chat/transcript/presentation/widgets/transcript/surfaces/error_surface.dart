import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ErrorSurface extends StatelessWidget {
  const ErrorSurface({super.key, required this.block});

  final TranscriptErrorBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);
    final accent = redAccent(Theme.of(context).brightness);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.warning_amber_rounded,
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
