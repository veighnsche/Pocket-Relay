part of 'work_log_group_surface.dart';

class _GenericWorkLogEntryRow extends StatelessWidget {
  const _GenericWorkLogEntryRow({required this.entry});

  final ChatGenericWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = TranscriptPalette.of(context);
    final accent = workLogAccent(entry.entryKind, theme.brightness);

    return _WorkLogRowShell(
      icon: workLogIcon(entry.entryKind),
      accent: accent,
      title: entry.title,
      statusBadge: _specialCommandStatusBadge(
        theme: theme,
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      details: entry.preview == null
          ? const <Widget>[]
          : <Widget>[
              Text(
                entry.preview!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 11.5,
                  height: 1.25,
                ),
              ),
            ],
    );
  }
}

class _CommandWaitWorkLogEntryRow extends StatelessWidget {
  const _CommandWaitWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
    this.onTap,
  });

  final ChatCommandWaitWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.activityLabel,
      title: entry.commandText,
      statusBadge: TranscriptBadge(label: 'waiting', color: accent),
      onTap: onTap,
      details: entry.outputPreview == null
          ? const <Widget>[]
          : <Widget>[
              Text(
                entry.outputPreview!,
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

class _CommandExecutionWorkLogEntryRow extends StatelessWidget {
  const _CommandExecutionWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
    this.onTap,
  });

  final ChatCommandExecutionWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.activityLabel,
      title: entry.commandText,
      onTap: onTap,
      statusBadge: _specialCommandStatusBadge(
        theme: Theme.of(context),
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      details: entry.outputPreview == null
          ? const <Widget>[]
          : <Widget>[
              Text(
                entry.outputPreview!,
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

class _GitWorkLogEntryRow extends StatelessWidget {
  const _GitWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
    this.onTap,
  });

  final ChatGitWorkLogEntryContract entry;
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
      title: entry.primaryLabel,
      onTap: onTap,
      statusBadge: _specialCommandStatusBadge(
        theme: Theme.of(context),
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      details: entry.secondaryLabel == null
          ? const <Widget>[]
          : <Widget>[
              Text(
                entry.secondaryLabel!,
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

class _ReadWorkLogEntryRow extends StatelessWidget {
  const _ReadWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
    this.onTap,
  });

  final ChatFileReadWorkLogEntryContract entry;
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
      title: entry.fileName,
      onTap: onTap,
      statusBadge: _specialCommandStatusBadge(
        theme: Theme.of(context),
        isRunning: entry.isRunning,
        exitCode: entry.exitCode,
      ),
      details: <Widget>[
        Text(
          entry.filePath,
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
