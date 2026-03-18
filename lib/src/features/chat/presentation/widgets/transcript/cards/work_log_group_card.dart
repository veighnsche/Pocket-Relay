import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_work_log_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
        decoration: BoxDecoration(
          color: cards.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cards.neutralBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.construction_outlined,
                  size: 16,
                  color: cards.textMuted,
                ),
                const SizedBox(width: 7),
                Text(
                  widget.item.hasOnlyKnownEntries ? 'Work log' : 'Activity',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cards.textSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Text(
                  '${entries.length}',
                  style: TextStyle(
                    color: cards.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...visibleEntries.map((entry) => _WorkLogEntryRow(entry: entry)),
            if (hasOverflow) ...[
              const SizedBox(height: 4),
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
      final ChatSedReadWorkLogEntryContract readEntry =>
        _SedReadWorkLogEntryRow(entry: readEntry),
      final ChatCatReadWorkLogEntryContract readEntry =>
        _CatReadWorkLogEntryRow(entry: readEntry),
      final ChatHeadReadWorkLogEntryContract readEntry =>
        _HeadReadWorkLogEntryRow(entry: readEntry),
      final ChatTailReadWorkLogEntryContract readEntry =>
        _TailReadWorkLogEntryRow(entry: readEntry),
      final ChatGetContentReadWorkLogEntryContract readEntry =>
        _GetContentReadWorkLogEntryRow(entry: readEntry),
      final ChatRipgrepSearchWorkLogEntryContract searchEntry =>
        _RipgrepSearchWorkLogEntryRow(entry: searchEntry),
      final ChatGrepSearchWorkLogEntryContract searchEntry =>
        _GrepSearchWorkLogEntryRow(entry: searchEntry),
      final ChatSelectStringSearchWorkLogEntryContract searchEntry =>
        _SelectStringSearchWorkLogEntryRow(entry: searchEntry),
      final ChatFindStrSearchWorkLogEntryContract searchEntry =>
        _FindStrSearchWorkLogEntryRow(entry: searchEntry),
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
    final icon = workLogIcon(entry.entryKind);
    final accent = workLogAccent(entry.entryKind, theme.brightness);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cards.accentBorder(accent)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    color: cards.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                if (entry.preview != null) ...[
                  const SizedBox(height: 2),
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (entry.isRunning)
            TranscriptBadge(
              label: 'running',
              color: tealAccent(theme.brightness),
            )
          else if (entry.exitCode != null)
            TranscriptBadge(
              label: 'exit ${entry.exitCode}',
              color: entry.exitCode == 0
                  ? blueAccent(theme.brightness)
                  : redAccent(theme.brightness),
            ),
        ],
      ),
    );
  }
}

Widget? _readStatusBadge(
  ThemeData theme,
  ChatFileReadWorkLogEntryContract entry,
) {
  return _specialCommandStatusBadge(
    theme: theme,
    isRunning: entry.isRunning,
    exitCode: entry.exitCode,
  );
}

Widget? _searchStatusBadge(
  ThemeData theme,
  ChatContentSearchWorkLogEntryContract entry,
) {
  return _specialCommandStatusBadge(
    theme: theme,
    isRunning: entry.isRunning,
    exitCode: entry.exitCode,
  );
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

class _RipgrepSearchWorkLogEntryRow extends StatelessWidget {
  const _RipgrepSearchWorkLogEntryRow({required this.entry});

  final ChatRipgrepSearchWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return _SearchCommandCardShell(
      entry: entry,
      accent: tealAccent(Theme.of(context).brightness),
      icon: Icons.manage_search_outlined,
    );
  }
}

class _GrepSearchWorkLogEntryRow extends StatelessWidget {
  const _GrepSearchWorkLogEntryRow({required this.entry});

  final ChatGrepSearchWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return _SearchCommandCardShell(
      entry: entry,
      accent: blueAccent(Theme.of(context).brightness),
      icon: Icons.saved_search_outlined,
    );
  }
}

class _SelectStringSearchWorkLogEntryRow extends StatelessWidget {
  const _SelectStringSearchWorkLogEntryRow({required this.entry});

  final ChatSelectStringSearchWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return _SearchCommandCardShell(
      entry: entry,
      accent: violetAccent(Theme.of(context).brightness),
      icon: Icons.find_in_page_outlined,
    );
  }
}

class _FindStrSearchWorkLogEntryRow extends StatelessWidget {
  const _FindStrSearchWorkLogEntryRow({required this.entry});

  final ChatFindStrSearchWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return _SearchCommandCardShell(
      entry: entry,
      accent: amberAccent(Theme.of(context).brightness),
      icon: Icons.travel_explore_outlined,
    );
  }
}

class _SedReadWorkLogEntryRow extends StatelessWidget {
  const _SedReadWorkLogEntryRow({required this.entry});

  final ChatSedReadWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return _ReadCommandCardShell(
      entry: entry,
      accent: blueAccent(Theme.of(context).brightness),
      icon: Icons.menu_book_outlined,
    );
  }
}

class _CatReadWorkLogEntryRow extends StatelessWidget {
  const _CatReadWorkLogEntryRow({required this.entry});

  final ChatCatReadWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return _ReadCommandCardShell(
      entry: entry,
      accent: tealAccent(Theme.of(context).brightness),
      icon: Icons.description_outlined,
    );
  }
}

class _HeadReadWorkLogEntryRow extends StatelessWidget {
  const _HeadReadWorkLogEntryRow({required this.entry});

  final ChatHeadReadWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return _ReadCommandCardShell(
      entry: entry,
      accent: amberAccent(Theme.of(context).brightness),
      icon: Icons.vertical_align_top,
    );
  }
}

class _TailReadWorkLogEntryRow extends StatelessWidget {
  const _TailReadWorkLogEntryRow({required this.entry});

  final ChatTailReadWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return _ReadCommandCardShell(
      entry: entry,
      accent: pinkAccent(Theme.of(context).brightness),
      icon: Icons.vertical_align_bottom,
    );
  }
}

class _GetContentReadWorkLogEntryRow extends StatelessWidget {
  const _GetContentReadWorkLogEntryRow({required this.entry});

  final ChatGetContentReadWorkLogEntryContract entry;

  @override
  Widget build(BuildContext context) {
    return _ReadCommandCardShell(
      entry: entry,
      accent: violetAccent(Theme.of(context).brightness),
      icon: Icons.subject_outlined,
    );
  }
}

class _SearchCommandCardShell extends StatelessWidget {
  const _SearchCommandCardShell({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatContentSearchWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);
    final statusBadge = _searchStatusBadge(theme, entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.1, darkAlpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cards.accentBorder(accent)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: cards.tintedSurface(
                accent,
                lightAlpha: 0.16,
                darkAlpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statusBadge != null) ...[
                  statusBadge,
                  const SizedBox(height: 7),
                ],
                Text(
                  entry.summaryLabel,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  _buildSearchQuerySpan(
                    entry: entry,
                    cards: cards,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
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
            ),
          ),
        ],
      ),
    );
  }
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
  for (var index = 0; index < segments.length; index++) {
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

class _ReadCommandCardShell extends StatelessWidget {
  const _ReadCommandCardShell({
    required this.entry,
    required this.accent,
    required this.icon,
  });

  final ChatFileReadWorkLogEntryContract entry;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = ConversationCardPalette.of(context);
    final statusBadge = _readStatusBadge(theme, entry);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.1, darkAlpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cards.accentBorder(accent)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: cards.tintedSurface(
                accent,
                lightAlpha: 0.16,
                darkAlpha: 0.3,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (statusBadge != null) ...[
                  statusBadge,
                  const SizedBox(height: 7),
                ],
                Text(
                  entry.summaryLabel,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.fileName,
                  style: TextStyle(
                    color: cards.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.filePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cards.textSecondary,
                    fontSize: 11.25,
                    height: 1.25,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
