import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_transcript_frame.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class PlanUpdateCard extends StatelessWidget {
  const PlanUpdateCard({super.key, required this.block});

  final CodexPlanUpdateBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = blueAccent(Theme.of(context).brightness);

    return PocketTranscriptFrame(
      shadowColor: cards.shadow,
      shadowOpacity: cards.isDark ? 0.18 : 0.06,
      backgroundColor: cards.surface,
      borderColor: cards.accentBorder(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rtl, size: 16, color: accent),
              const SizedBox(width: 7),
              Text(
                'Updated Plan',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          if (block.explanation != null &&
              block.explanation!.trim().isNotEmpty) ...[
            const SizedBox(height: PocketSpacing.xs),
            SelectableText(
              block.explanation!,
              style: TextStyle(
                color: cards.textSecondary,
                fontSize: 13,
                height: 1.32,
              ),
            ),
          ],
          if (block.steps.isNotEmpty) ...[
            const SizedBox(height: PocketSpacing.sm),
            ...block.steps.map((step) {
              final status = planStepStatus(step.status, cards);
              return Container(
                margin: const EdgeInsets.only(bottom: PocketSpacing.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: status.background,
                  borderRadius: PocketRadii.circular(16),
                  border: Border.all(color: status.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(status.icon, size: 16, color: status.accent),
                    const SizedBox(width: PocketSpacing.xs),
                    Expanded(
                      child: Text(
                        step.step,
                        style: TextStyle(
                          color: cards.textPrimary,
                          fontSize: 13,
                          height: 1.28,
                        ),
                      ),
                    ),
                    const SizedBox(width: PocketSpacing.xs),
                    TranscriptBadge(label: status.label, color: status.accent),
                  ],
                ),
              );
            }),
          ] else ...[
            const SizedBox(height: PocketSpacing.xs),
            Text(
              'Waiting for plan steps…',
              style: TextStyle(color: cards.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
