import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/utils/duration_utils.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/usage_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';

class TurnBoundaryMarker extends StatelessWidget {
  const TurnBoundaryMarker({super.key, required this.block});

  static const separatorRowKey = ValueKey<String>(
    'turn_boundary_separator_row',
  );

  final TranscriptTurnBoundaryBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);
    final label = block.elapsed == null
        ? block.label
        : '${block.label} · ${formatElapsedDuration(block.elapsed!)}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.usage != null) ...[
            UsageSurface(block: block.usage!),
            const SizedBox(height: 2),
          ],
          Row(
            key: separatorRowKey,
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: cards.neutralBorder.withValues(alpha: 0.55),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  label,
                  style: TextStyle(
                    color: cards.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.45,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: cards.neutralBorder.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
