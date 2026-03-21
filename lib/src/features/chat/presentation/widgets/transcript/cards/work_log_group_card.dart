import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_work_log_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_item_primitives.dart';

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

    return TranscriptAnnotation(
      accent: cards.textMuted,
      header: TranscriptAnnotationHeader(
        icon: Icons.construction_outlined,
        label: widget.item.hasOnlyKnownEntries ? 'Work log' : 'Activity',
        accent: cards.textSecondary,
        trailing: Text(
          '${entries.length}',
          style: TextStyle(color: cards.textMuted, fontWeight: FontWeight.w700),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...visibleEntries.map((entry) => _WorkLogEntryRow(entry: entry)),
          if (hasOverflow) ...[
            const SizedBox(height: PocketSpacing.xxs),
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? 'Show less'
                    : 'Show ${entries.length - visibleEntries.length} more',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkLogEntryRow extends StatelessWidget {
  const _WorkLogEntryRow({required this.entry});

  final ChatWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return switch (entry) {
      final ChatSedReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: blueAccent(Theme.of(context).brightness),
        icon: Icons.menu_book_outlined,
      ),
      final ChatCatReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: tealAccent(Theme.of(context).brightness),
        icon: Icons.description_outlined,
      ),
      final ChatHeadReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: amberAccent(Theme.of(context).brightness),
        icon: Icons.vertical_align_top,
      ),
      final ChatTailReadWorkLogEntryContract readEntry => _ReadWorkLogEntryRow(
        entry: readEntry,
        accent: pinkAccent(Theme.of(context).brightness),
        icon: Icons.vertical_align_bottom,
      ),
      final ChatGetContentReadWorkLogEntryContract readEntry =>
        _ReadWorkLogEntryRow(
          entry: readEntry,
          accent: violetAccent(Theme.of(context).brightness),
          icon: Icons.subject_outlined,
        ),
      final ChatRipgrepSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: tealAccent(Theme.of(context).brightness),
          icon: Icons.manage_search_outlined,
        ),
      final ChatGrepSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: blueAccent(Theme.of(context).brightness),
          icon: Icons.saved_search_outlined,
        ),
      final ChatSelectStringSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: violetAccent(Theme.of(context).brightness),
          icon: Icons.find_in_page_outlined,
        ),
      final ChatFindStrSearchWorkLogEntryContract searchEntry =>
        _SearchWorkLogEntryRow(
          entry: searchEntry,
          accent: amberAccent(Theme.of(context).brightness),
          icon: Icons.travel_explore_outlined,
        ),
      final ChatGitWorkLogEntryContract gitEntry => _GitWorkLogEntryRow(
        entry: gitEntry,
        accent: amberAccent(Theme.of(context).brightness),
        icon: Icons.source_outlined,
      ),
      final ChatCommandExecutionWorkLogEntryContract commandEntry =>
        _CommandExecutionWorkLogEntryRow(
          entry: commandEntry,
          accent: blueAccent(Theme.of(context).brightness),
          icon: Icons.terminal_outlined,
        ),
      final ChatWebSearchWorkLogEntryContract webSearchEntry =>
        _WebSearchWorkLogEntryRow(
          entry: webSearchEntry,
          accent: tealAccent(Theme.of(context).brightness),
          icon: Icons.travel_explore_outlined,
        ),
      final ChatMcpToolCallWorkLogEntryContract mcpEntry =>
        _McpToolCallWorkLogEntryRow(
          entry: mcpEntry,
          accent: mcpEntry.status == ChatMcpToolCallStatus.failed
              ? redAccent(Theme.of(context).brightness)
              : amberAccent(Theme.of(context).brightness),
          icon: Icons.extension_outlined,
        ),
      final ChatGenericWorkLogEntryContract genericEntry =>
        _GenericWorkLogEntryRow(entry: genericEntry),
    };
  }
}

class _GenericWorkLogEntryRow extends StatelessWidget {
  const _GenericWorkLogEntryRow({required this.entry});

  final ChatGenericWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);
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

class _SearchWorkLogEntryRow extends StatelessWidget {
  const _SearchWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatContentSearchWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.summaryLabel,
      titleWidget: Text.rich(
        _buildSearchQuerySpan(entry: entry, cards: cards),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
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
    final cards = ConversationCardPalette.of(context);

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

class _CommandExecutionWorkLogEntryRow extends StatelessWidget {
  const _CommandExecutionWorkLogEntryRow({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatCommandExecutionWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.activityLabel,
      title: entry.commandText,
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
  });

  final ChatGitWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.summaryLabel,
      title: entry.primaryLabel,
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
  });

  final ChatFileReadWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return _WorkLogRowShell(
      icon: icon,
      accent: accent,
      label: entry.summaryLabel,
      title: entry.fileName,
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
    final cards = ConversationCardPalette.of(context);
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
            style: TextStyle(
              color: cards.textSecondary,
              fontSize: 11.25,
              height: 1.25,
              fontFamily: 'monospace',
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

class _WorkLogRowShell extends StatelessWidget {
  const _WorkLogRowShell({
    required this.icon,
    required this.accent,
    this.label,
    this.title,
    this.titleWidget,
    this.titleMonospace = false,
    this.statusBadge,
    this.details = const <Widget>[],
  });

  final IconData icon;
  final Color accent;
  final String? label;
  final String? title;
  final Widget? titleWidget;
  final bool titleMonospace;
  final Widget? statusBadge;
  final List<Widget> details;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statusBadge != null) ...[
                  statusBadge!,
                  const SizedBox(height: 5),
                ],
                if (label != null) ...[
                  Text(
                    label!,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                if (titleWidget != null)
                  titleWidget!
                else if (title != null)
                  Text(
                    title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cards.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      height: 1.15,
                      fontFamily: titleMonospace ? 'monospace' : null,
                    ),
                  ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  ...details.indexed.map((entry) {
                    return Padding(
                      padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 2),
                      child: entry.$2,
                    );
                  }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget? _specialCommandStatusBadge({
  required ThemeData theme,
  required bool isRunning,
  required int? exitCode,
}) {
  if (isRunning) {
    return TranscriptBadge(
      label: 'running',
      color: tealAccent(theme.brightness),
    );
  }
  if (exitCode != null && exitCode != 0) {
    return TranscriptBadge(
      label: 'exit $exitCode',
      color: redAccent(theme.brightness),
    );
  }
  return null;
}

TextSpan _buildSearchQuerySpan({
  required ChatContentSearchWorkLogEntryContract entry,
  required ConversationCardPalette cards,
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
