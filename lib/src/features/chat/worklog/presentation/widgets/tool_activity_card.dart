import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class WebSearchActivityCard extends StatelessWidget {
  const WebSearchActivityCard({super.key, required this.entry});

  final ChatWebSearchWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final accent = tealAccent(Theme.of(context).brightness);
    final cards = ConversationCardPalette.of(context);

    return TranscriptBlocker(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranscriptAnnotationHeader(
            icon: Icons.travel_explore_outlined,
            label: entry.activityLabel,
            accent: accent,
            trailing: entry.isRunning
                ? TranscriptBadge(label: 'running', color: accent)
                : null,
          ),
          const SizedBox(height: 10),
          Text(
            entry.queryText,
            style: TextStyle(
              color: cards.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            entry.resultSummary ?? entry.scopeLabel,
            style: TextStyle(
              color: cards.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class McpToolActivityCard extends StatelessWidget {
  const McpToolActivityCard({super.key, required this.entry});

  final ChatMcpToolCallWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = entry.status == ChatMcpToolCallStatus.failed
        ? redAccent(brightness)
        : amberAccent(brightness);
    final cards = ConversationCardPalette.of(context);

    return TranscriptBlocker(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranscriptAnnotationHeader(
            icon: Icons.extension_outlined,
            label: 'MCP Tool Call',
            accent: accent,
            trailing: TranscriptBadge(label: entry.statusLabel, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            entry.identityLabel,
            style: TextStyle(
              color: cards.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.3,
              fontFamily: 'monospace',
            ),
          ),
          if (entry.argumentsLabel case final arguments?) ...[
            const SizedBox(height: 8),
            Text(
              arguments,
              style: TextStyle(
                color: cards.textSecondary,
                fontSize: 12,
                height: 1.3,
                fontFamily: 'monospace',
              ),
            ),
          ],
          if (entry.outcomeLabel case final outcome?) ...[
            const SizedBox(height: 8),
            Text(
              outcome,
              style: TextStyle(
                color: entry.status == ChatMcpToolCallStatus.failed
                    ? accent
                    : cards.textSecondary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
