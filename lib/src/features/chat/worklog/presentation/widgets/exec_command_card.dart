import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ExecCommandCard extends StatelessWidget {
  const ExecCommandCard({super.key, required this.entry});

  final ChatCommandExecutionWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = blueAccent(brightness);
    final cards = ConversationCardPalette.of(context);

    return TranscriptBlocker(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranscriptAnnotationHeader(
            icon: Icons.terminal_outlined,
            label: entry.activityLabel,
            accent: accent,
          ),
          const SizedBox(height: 10),
          Text(
            entry.commandText,
            style: TextStyle(
              color: cards.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          if (entry.outputPreview case final output?) ...[
            const SizedBox(height: 10),
            TranscriptCodeInset(
              child: Text(
                output,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ExecWaitCard extends StatelessWidget {
  const ExecWaitCard({super.key, required this.entry});

  final ChatCommandWaitWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    final cards = ConversationCardPalette.of(context);

    return TranscriptBlocker(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranscriptAnnotationHeader(
            icon: Icons.hourglass_top_rounded,
            label: entry.activityLabel,
            accent: accent,
            trailing: TranscriptBadge(label: 'waiting', color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            entry.commandText,
            style: TextStyle(
              color: cards.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          if (entry.outputPreview case final output?) ...[
            const SizedBox(height: 10),
            TranscriptCodeInset(
              child: Text(
                output,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
