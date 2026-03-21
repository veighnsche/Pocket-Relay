import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_transcript_frame.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class ChangedFilesCard extends StatelessWidget {
  const ChangedFilesCard({super.key, required this.item, this.onOpenDiff});

  final ChatChangedFilesItemContract item;
  final void Function(ChatChangedFileDiffContract diff)? onOpenDiff;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = amberAccent(Theme.of(context).brightness);
    final fileCountLabel =
        '${item.fileCount} ${item.fileCount == 1 ? 'file' : 'files'}';

    return PocketTranscriptFrame(
      shadowColor: cards.shadow,
      shadowOpacity: cards.isDark ? 0.18 : 0.06,
      backgroundColor: cards.surface,
      borderColor: cards.accentBorder(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.drive_file_rename_outline, size: 16, color: accent),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (item.isRunning) const InlinePulseChip(label: 'updating'),
            ],
          ),
          const SizedBox(height: PocketSpacing.sm),
          Row(
            children: [
              Text(
                fileCountLabel,
                style: TextStyle(
                  color: cards.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              if (item.hasHeaderStats) ...[
                const SizedBox(width: PocketSpacing.xs),
                Text(
                  '+${item.headerStats.additions} -${item.headerStats.deletions}',
                  style: TextStyle(color: cards.textSecondary, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: PocketSpacing.xs),
          if (item.rows.isEmpty)
            Text(
              'Waiting for changed files…',
              style: TextStyle(color: cards.textMuted),
            )
          else
            Column(
              children: item.rows
                  .map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _ChangedFileRow(
                        row: row,
                        accent: accent,
                        cards: cards,
                        onOpenDiff: onOpenDiff,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}

class _ChangedFileRow extends StatelessWidget {
  const _ChangedFileRow({
    required this.row,
    required this.accent,
    required this.cards,
    this.onOpenDiff,
  });

  final ChatChangedFileRowContract row;
  final Color accent;
  final ConversationCardPalette cards;
  final void Function(ChatChangedFileDiffContract diff)? onOpenDiff;

  bool get _canOpenPatch => row.canOpenDiff;

  (_ChangedFileVisuals visuals, Color accent) _visualsForRow() {
    final brightness = cards.brightness;
    final accent = switch (row.operationKind) {
      ChatChangedFileOperationKind.created => tealAccent(brightness),
      ChatChangedFileOperationKind.modified => amberAccent(brightness),
      ChatChangedFileOperationKind.deleted => redAccent(brightness),
    };

    final visuals = switch (row.operationKind) {
      ChatChangedFileOperationKind.created => const _ChangedFileVisuals(
        icon: Icons.add_circle_outline_rounded,
      ),
      ChatChangedFileOperationKind.modified => const _ChangedFileVisuals(
        icon: Icons.edit_outlined,
      ),
      ChatChangedFileOperationKind.deleted => const _ChangedFileVisuals(
        icon: Icons.delete_outline_rounded,
      ),
    };

    return (visuals, accent);
  }

  @override
  Widget build(BuildContext context) {
    final (visuals, rowAccent) = _visualsForRow();
    final body = Container(
      key: ValueKey<String>('changed_file_row_${row.id}'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: PocketSpacing.sm,
        vertical: PocketSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: cards.tintedSurface(
          rowAccent,
          lightAlpha: 0.08,
          darkAlpha: 0.14,
        ),
        borderRadius: PocketRadii.circular(PocketRadii.sm),
        border: Border.all(
          color: cards.accentBorder(
            rowAccent,
            lightAlpha: 0.32,
            darkAlpha: 0.42,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visuals.icon, size: 14, color: rowAccent),
          const SizedBox(width: 6),
          _ChangedFileStatusChip(
            label: row.operationLabel,
            accent: rowAccent,
            cards: cards,
          ),
          const SizedBox(width: PocketSpacing.xs),
          Expanded(
            child: Text(
              row.displayPathLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontFamily: 'monospace',
                color: cards.textSecondary,
                height: 1.2,
              ),
            ),
          ),
          if (row.stats.hasChanges) ...[
            const SizedBox(width: PocketSpacing.xs),
            Text(
              '+${row.stats.additions} -${row.stats.deletions}',
              style: TextStyle(fontSize: 11, color: cards.textMuted),
            ),
          ],
          const SizedBox(width: PocketSpacing.xs),
          _ChangedFileActionChip(
            label: row.actionLabel,
            accent: rowAccent,
            cards: cards,
            isEnabled: _canOpenPatch,
          ),
        ],
      ),
    );

    if (!_canOpenPatch || onOpenDiff == null) {
      return body;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: PocketRadii.circular(PocketRadii.sm),
        onTap: () => onOpenDiff!(row.diff!),
        child: body,
      ),
    );
  }
}

class _ChangedFileVisuals {
  const _ChangedFileVisuals({required this.icon});

  final IconData icon;
}

class _ChangedFileStatusChip extends StatelessWidget {
  const _ChangedFileStatusChip({
    required this.label,
    required this.accent,
    required this.cards,
  });

  final String label;
  final Color accent;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.12, darkAlpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cards.accentBorder(accent, lightAlpha: 0.3, darkAlpha: 0.42),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: accent,
        ),
      ),
    );
  }
}

class _ChangedFileActionChip extends StatelessWidget {
  const _ChangedFileActionChip({
    required this.label,
    required this.accent,
    required this.cards,
    required this.isEnabled,
  });

  final String label;
  final Color accent;
  final ConversationCardPalette cards;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final chipAccent = isEnabled ? accent : cards.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cards.tintedSurface(
          chipAccent,
          lightAlpha: isEnabled ? 0.12 : 0.05,
          darkAlpha: isEnabled ? 0.22 : 0.1,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cards.accentBorder(
            chipAccent,
            lightAlpha: isEnabled ? 0.3 : 0.18,
            darkAlpha: isEnabled ? 0.42 : 0.24,
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: chipAccent,
        ),
      ),
    );
  }
}

class ChangedFileDiffSheet extends StatefulWidget {
  const ChangedFileDiffSheet({super.key, required this.diff});

  final ChatChangedFileDiffContract diff;

  @override
  State<ChangedFileDiffSheet> createState() => _ChangedFileDiffSheetState();
}

class _ChangedFileDiffSheetState extends State<ChangedFileDiffSheet> {
  bool _showFullDiff = false;

  @override
  Widget build(BuildContext context) {
    final diff = widget.diff;
    final accent = amberAccent(Theme.of(context).brightness);
    final cards = ConversationCardPalette.of(context);
    final pocket = context.pocketPalette;
    final statusLabel = diff.statusLabel;
    final hasPreviewLimit = diff.hasPreviewLimit;
    final visibleLines = _showFullDiff || !hasPreviewLimit
        ? diff.lines
        : diff.lines.take(diff.previewLineLimit).toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: pocket.sheetBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: cards.neutralBorder),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.34 : 0.14),
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: pocket.dragHandle,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          diff.displayPathLabel,
                          style: TextStyle(
                            color: cards.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SheetChip(
                              label: '+${diff.stats.additions} additions',
                              accent: tealAccent(cards.brightness),
                              cards: cards,
                            ),
                            _SheetChip(
                              label: '-${diff.stats.deletions} deletions',
                              accent: redAccent(cards.brightness),
                              cards: cards,
                            ),
                            _SheetChip(
                              label: '${diff.lineCount} lines',
                              accent: neutralAccent(cards.brightness),
                              cards: cards,
                            ),
                            if (statusLabel != null && statusLabel.isNotEmpty)
                              _SheetChip(
                                label: statusLabel,
                                accent: accent,
                                cards: cards,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close diff',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: cards.textMuted),
                  ),
                ],
              ),
            ),
            if (hasPreviewLimit)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: cards.tintedSurface(
                      accent,
                      lightAlpha: 0.06,
                      darkAlpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: cards.accentBorder(
                        accent,
                        lightAlpha: 0.22,
                        darkAlpha: 0.3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _showFullDiff
                              ? 'Full diff loaded.'
                              : 'Showing the first ${diff.previewLineLimit} lines to keep the sheet responsive.',
                          style: TextStyle(
                            color: cards.textSecondary,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showFullDiff = !_showFullDiff;
                          });
                        },
                        child: Text(
                          _showFullDiff ? 'Show preview' : 'Load full diff',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cards.terminalBody,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: cards.accentBorder(
                        accent,
                        lightAlpha: 0.18,
                        darkAlpha: 0.28,
                      ),
                    ),
                  ),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: SelectionArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: visibleLines
                                .map(
                                  (line) =>
                                      _DiffLineView(line: line, cards: cards),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetChip extends StatelessWidget {
  const _SheetChip({
    required this.label,
    required this.accent,
    required this.cards,
  });

  final String label;
  final Color accent;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: cards.accentBorder(accent, lightAlpha: 0.26, darkAlpha: 0.36),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DiffLineView extends StatelessWidget {
  const _DiffLineView({required this.line, required this.cards});

  final ChatChangedFileDiffLineContract line;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    final style = _styleForLine(line.kind, cards);
    return Container(
      color: style.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Text(
        line.text,
        softWrap: false,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.8,
          height: 1.38,
          color: style.foreground,
          fontWeight: style.fontWeight,
        ),
      ),
    );
  }

  _DiffLineStyle _styleForLine(
    ChatChangedFileDiffLineKind kind,
    ConversationCardPalette cards,
  ) {
    return switch (kind) {
      ChatChangedFileDiffLineKind.addition => _DiffLineStyle(
        background: Color.alphaBlend(
          tealAccent(
            cards.brightness,
          ).withValues(alpha: cards.isDark ? 0.18 : 0.12),
          cards.terminalBody,
        ),
        foreground: cards.terminalText,
      ),
      ChatChangedFileDiffLineKind.deletion => _DiffLineStyle(
        background: Color.alphaBlend(
          redAccent(
            cards.brightness,
          ).withValues(alpha: cards.isDark ? 0.2 : 0.12),
          cards.terminalBody,
        ),
        foreground: cards.terminalText,
      ),
      ChatChangedFileDiffLineKind.hunk => _DiffLineStyle(
        background: Color.alphaBlend(
          blueAccent(
            cards.brightness,
          ).withValues(alpha: cards.isDark ? 0.18 : 0.12),
          cards.terminalBody,
        ),
        foreground: blueAccent(
          cards.brightness,
        ).withValues(alpha: cards.isDark ? 0.92 : 1),
        fontWeight: FontWeight.w700,
      ),
      ChatChangedFileDiffLineKind.meta => _DiffLineStyle(
        background: Color.alphaBlend(
          amberAccent(
            cards.brightness,
          ).withValues(alpha: cards.isDark ? 0.12 : 0.08),
          cards.terminalBody,
        ),
        foreground: cards.textSecondary,
      ),
      ChatChangedFileDiffLineKind.context => _DiffLineStyle(
        background: cards.terminalBody,
        foreground: cards.terminalText,
      ),
    };
  }
}

class _DiffLineStyle {
  const _DiffLineStyle({
    required this.background,
    required this.foreground,
    this.fontWeight = FontWeight.w500,
  });

  final Color background;
  final Color foreground;
  final FontWeight fontWeight;
}
