part of 'work_log_group_surface.dart';

class _SearchWorkLogEntryRow extends StatelessWidget {
  const _SearchWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
    this.onTap,
  });

  final ChatContentSearchWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.summaryLabel,
      titleWidget: Text.rich(
        _buildSearchQuerySpan(entry: entry, cards: cards),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      statusBadge: _specialCommandStatusBadge(
        theme: Theme.of(context),
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      details: <Widget>[
        Text(
          entry.scopeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cards.textSecondary,
            fontSize: 11.25,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _WebSearchWorkLogEntryRow extends StatelessWidget {
  const _WebSearchWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatWebSearchWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.activityLabel,
      title: entry.queryText,
      statusBadge: entry.isRunning
          ? TranscriptBadge(
              label: 'running',
              color: tealAccent(Theme.of(context).brightness),
            )
          : null,
      details: <Widget>[
        Text(
          entry.resultSummary ?? entry.scopeLabel,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cards.textSecondary,
            fontSize: 11.25,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _McpToolCallWorkLogEntryRow extends StatelessWidget {
  const _McpToolCallWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatMcpToolCallWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);
    final outcomeColor = entry.status == ChatMcpToolCallStatus.failed
        ? accent
        : cards.textSecondary;

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      title: entry.identityLabel,
      titleMonospace: true,
      details: <Widget>[
        if (entry.argumentsLabel != null)
          Text(
            entry.argumentsLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PocketTypography.monospaceStyle(
              base: const TextStyle(),
              color: cards.textSecondary,
              fontSize: 11.25,
              height: 1.25,
            ),
          ),
        if (entry.outcomeLabel != null)
          Text(
            entry.outcomeLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: outcomeColor,
              fontSize: 11.25,
              height: 1.25,
            ),
          ),
      ],
    );
  }
}

TextSpan _buildSearchQuerySpan({
  required ChatContentSearchWorkLogEntryContract entry,
  required TranscriptPalette cards,
}) {
  final segments = entry.querySegments;
  if (segments.length <= 1) {
    return TextSpan(
      text: entry.displayQueryText,
      style: TextStyle(
        color: cards.textPrimary,
        fontWeight: FontWeight.w800,
        fontSize: 13.5,
        height: 1.15,
      ),
    );
  }

  final children = <InlineSpan>[];
  for (var index = 0; index < segments.length; index += 1) {
    if (index > 0) {
      children.add(
        TextSpan(
          text: ' | ',
          style: TextStyle(
            color: cards.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12.25,
            height: 1.2,
          ),
        ),
      );
    }
    children.add(
      TextSpan(
        text: segments[index],
        style: TextStyle(
          color: cards.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
          height: 1.15,
        ),
      ),
    );
  }

  return TextSpan(children: children);
}
