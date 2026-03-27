import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/domain/chat_work_log_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ExecCommandSurface extends StatelessWidget {
  const ExecCommandSurface({
    super.key,
    required this.entry,
    this.onOpenTerminal,
  });

  final ChatCommandExecutionWorkLogEntryContract entry;
  final void Function(ChatWorkLogTerminalContract terminal)? onOpenTerminal;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = blueAccent(brightness);
    final cards = TranscriptPalette.of(context);

    final body = TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.terminal_outlined,
        label: entry.activityLabel,
        accent: accent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

    final openTerminal = onOpenTerminal;
    if (openTerminal == null) {
      return body;
    }

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              openTerminal(ChatWorkLogTerminalContract.fromEntry(entry)),
          child: body,
        ),
      ),
    );
  }
}

class ExecWaitSurface extends StatelessWidget {
  const ExecWaitSurface({super.key, required this.entry, this.onOpenTerminal});

  final ChatCommandWaitWorkLogEntryContract entry;
  final void Function(ChatWorkLogTerminalContract terminal)? onOpenTerminal;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.tertiary;
    final cards = TranscriptPalette.of(context);

    final body = TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.hourglass_top_rounded,
        label: entry.activityLabel,
        accent: accent,
        trailing: TranscriptBadge(label: 'waiting', color: accent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

    final openTerminal = onOpenTerminal;
    if (openTerminal == null) {
      return body;
    }

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () =>
              openTerminal(ChatWorkLogTerminalContract.fromEntry(entry)),
          child: body,
        ),
      ),
    );
  }
}
