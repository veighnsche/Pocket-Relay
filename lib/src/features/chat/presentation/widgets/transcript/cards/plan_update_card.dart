import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class PlanUpdateCard extends StatelessWidget {
  const PlanUpdateCard({super.key, required this.block});

  final CodexPlanUpdateBlock block;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = blueAccent(Theme.of(context).brightness);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.checklist_rtl,
        label: 'Updated Plan',
        accent: accent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.explanation != null &&
              block.explanation!.trim().isNotEmpty) ...[
            SelectableText(
              block.explanation!,
              style: TextStyle(
                color: cards.textSecondary,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: PocketSpacing.sm),
          ],
          if (block.steps.isNotEmpty) ...[
            ...block.steps.indexed.map((entry) {
              final index = entry.$1;
              final step = entry.$2;
              final status = planStepStatus(step.status, cards);

              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == block.steps.length - 1
                      ? 0
                      : PocketSpacing.sm,
                ),
                child: _PlanStepRow(step: step.step, status: status),
              );
            }),
          ] else ...[
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

class _PlanStepRow extends StatelessWidget {
  const _PlanStepRow({required this.step, required this.status});

  final String step;
  final PlanStepStatusPresentation status;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(status.icon, size: 16, color: status.accent),
        ),
        const SizedBox(width: PocketSpacing.xs),
        Expanded(
          child: Text(
            step,
            style: TextStyle(
              color: cards.textPrimary,
              fontSize: 13,
              height: 1.28,
            ),
          ),
        ),
        const SizedBox(width: PocketSpacing.xs),
        Text(
          status.label.toUpperCase(),
          style: TextStyle(
            color: status.accent,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.25,
          ),
        ),
      ],
    );
  }
}
