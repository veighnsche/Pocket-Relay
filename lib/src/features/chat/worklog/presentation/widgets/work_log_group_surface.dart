import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';

part 'work_log_group_header.dart';
part 'work_log_group_rows_dispatch.dart';
part 'work_log_group_rows_command.dart';
part 'work_log_group_rows_tooling.dart';
part 'work_log_group_shell.dart';

class WorkLogGroupSurface extends StatefulWidget {
  const WorkLogGroupSurface({
    super.key,
    required this.item,
    this.onOpenTerminal,
  });

  final ChatWorkLogGroupItemContract item;
  final void Function(ChatWorkLogTerminalContract terminal)? onOpenTerminal;

  @override
  State<WorkLogGroupSurface> createState() => _WorkLogGroupSurfaceState();
}

class _WorkLogGroupSurfaceState extends State<WorkLogGroupSurface> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);
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
          ...visibleEntries.map(
            (entry) => _WorkLogEntryRow(
              entry: entry,
              onOpenTerminal: widget.onOpenTerminal,
            ),
          ),
        ],
      ),
    );
  }
}
