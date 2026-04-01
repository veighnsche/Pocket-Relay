import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class WarningEventSurface extends StatelessWidget {
  const WarningEventSurface({super.key, required this.block});

  final TranscriptStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final accent = amberAccent(Theme.of(context).brightness);

    return _AlertAnnotation(
      title: block.title,
      body: block.body,
      accent: accent,
      icon: Icons.warning_amber_rounded,
    );
  }
}

class DeprecationNoticeSurface extends StatelessWidget {
  const DeprecationNoticeSurface({super.key, required this.block});

  final TranscriptStatusBlock block;

  @override
  Widget build(BuildContext context) {
    final accent = redAccent(Theme.of(context).brightness);

    return _AlertAnnotation(
      title: block.title,
      body: block.body,
      accent: accent,
      icon: Icons.warning_amber_rounded,
    );
  }
}

class PatchApplyFailureSurface extends StatelessWidget {
  const PatchApplyFailureSurface({super.key, required this.block});

  final TranscriptErrorBlock block;

  @override
  Widget build(BuildContext context) {
    final accent = pinkAccent(Theme.of(context).brightness);

    return _AlertAnnotation(
      title: block.title,
      body: block.body,
      accent: accent,
      icon: Icons.rule_folder_outlined,
    );
  }
}

class _AlertAnnotation extends StatelessWidget {
  const _AlertAnnotation({
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
    final palette = TranscriptPalette.of(context);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: icon,
        label: title,
        accent: accent,
      ),
      child: SelectableText(
        body,
        style: TextStyle(
          color: palette.textSecondary,
          fontSize: 12.5,
          height: 1.35,
        ),
      ),
    );
  }
}
