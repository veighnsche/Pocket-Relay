import 'package:flutter/material.dart';

import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class PocketTintBadge extends StatelessWidget {
  const PocketTintBadge({
    super.key,
    required this.label,
    required this.color,
    this.backgroundOpacity = 0.12,
    this.fontSize = 10.5,
    this.horizontalPadding = PocketSpacing.xs,
    this.verticalPadding = PocketSpacing.xxs,
  });

  final String label;
  final Color color;
  final double backgroundOpacity;
  final double fontSize;
  final double horizontalPadding;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: backgroundOpacity),
        borderRadius: PocketRadii.circular(PocketRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PocketSolidBadge extends StatelessWidget {
  const PocketSolidBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PocketSpacing.xs,
        vertical: PocketSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: PocketRadii.circular(PocketRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class TranscriptBadge extends StatelessWidget {
  const TranscriptBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PocketTintBadge(label: label, color: color);
  }
}

class InlinePulseChip extends StatelessWidget {
  const InlinePulseChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = tealAccent(Theme.of(context).brightness);
    return PocketTintBadge(label: label, color: accent);
  }
}

class StateChip extends StatelessWidget {
  const StateChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PocketSolidBadge(label: label, color: color);
  }
}
