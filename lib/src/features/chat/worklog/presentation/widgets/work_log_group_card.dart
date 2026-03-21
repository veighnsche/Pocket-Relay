import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

part 'work_log_group_card_header.dart';
part 'work_log_group_card_rows_dispatch.dart';
part 'work_log_group_card_rows_command.dart';
part 'work_log_group_card_rows_tooling.dart';
part 'work_log_group_card_shell.dart';

class WorkLogGroupCard extends StatefulWidget {
  const WorkLogGroupCard({super.key, required this.item});

  final ChatWorkLogGroupItemContract item;

  @override
  State<WorkLogGroupCard> createState() => _WorkLogGroupCardState();
}

class _WorkLogGroupCardState extends State<WorkLogGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final entries = widget.item.entries;
    final hasOverflow = entries.length > 3;
    final visibleEntries = hasOverflow && !_expanded
        ? entries.skip(entries.length - 3).toList(growable: false)
        : entries;
    final hiddenCount = entries.length - visibleEntries.length;

    return TranscriptAnnotation(
      accent: cards.textMuted,
      header: _WorkLogHeader(
        label: widget.item.hasOnlyKnownEntries ? 'Work log' : 'Activity',
        accent: cards.textSecondary,
        totalCount: entries.length,
        hiddenCount: hiddenCount,
        isExpanded: _expanded,
        isInteractive: hasOverflow,
        onTap: hasOverflow
            ? () => setState(() => _expanded = !_expanded)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...visibleEntries.map((entry) => _WorkLogEntryRow(entry: entry)),
        ],
      ),
    );
  }
}
