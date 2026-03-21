import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/changed_file_syntax_highlighter.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ChangedFilesCard extends StatelessWidget {
  const ChangedFilesCard({super.key, required this.item, this.onOpenDiff});

  final ChatChangedFilesItemContract item;
  final void Function(ChatChangedFileDiffContract diff)? onOpenDiff;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = amberAccent(cards.brightness);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.drive_file_rename_outline,
        label: item.title,
        accent: accent,
        trailing: item.isRunning ? _LiveUpdateLabel(accent: accent) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _summaryLabel(item),
            style: TextStyle(
              color: cards.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: PocketSpacing.sm),
          if (item.rows.isEmpty)
            Text(
              'Waiting for changed files…',
              style: TextStyle(color: cards.textMuted),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: cards.surface,
                borderRadius: PocketRadii.circular(PocketRadii.lg),
                border: Border.all(
                  color: cards.neutralBorder.withValues(alpha: 0.86),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cards.shadow.withValues(
                      alpha: cards.isDark ? 0.16 : 0.06,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: item.rows.indexed
                    .map(
                      (entry) => _ChangedFileRow(
                        row: entry.$2,
                        cards: cards,
                        isLast: entry.$1 == item.rows.length - 1,
                        onOpenDiff: onOpenDiff,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveUpdateLabel extends StatelessWidget {
  const _LiveUpdateLabel({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          'updating',
          style: TextStyle(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

String _summaryLabel(ChatChangedFilesItemContract item) {
  final fileLabel =
      '${item.fileCount} ${item.fileCount == 1 ? 'file' : 'files'}';
  if (!item.hasHeaderStats) {
    return '$fileLabel changed';
  }

  return '$fileLabel changed · ${item.headerStats.additions} additions · ${item.headerStats.deletions} deletions';
}

class _ChangedFileRow extends StatelessWidget {
  const _ChangedFileRow({
    required this.row,
    required this.cards,
    required this.isLast,
    this.onOpenDiff,
  });

  final ChatChangedFileRowContract row;
  final ConversationCardPalette cards;
  final bool isLast;
  final void Function(ChatChangedFileDiffContract diff)? onOpenDiff;

  bool get _canOpenDiff => row.canOpenDiff && onOpenDiff != null;

  @override
  Widget build(BuildContext context) {
    final accent = _accentForOperation(row.operationKind, cards.brightness);
    final body = Container(
      key: ValueKey<String>('changed_file_row_${row.id}'),
      decoration: BoxDecoration(
        color: _canOpenDiff
            ? cards.tintedSurface(accent, lightAlpha: 0.035, darkAlpha: 0.08)
            : Colors.transparent,
        borderRadius: PocketRadii.circular(PocketRadii.md),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Icon(_iconForOperation(row.operationKind), size: 18, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cards.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                if (_secondaryLabel(row) case final secondaryLabel?) ...[
                  Text(
                    secondaryLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cards.textMuted,
                      fontSize: 11.5,
                      fontFamily: 'monospace',
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  _tertiaryLabel(row),
                  style: TextStyle(
                    color: _canOpenDiff ? cards.textSecondary : cards.textMuted,
                    fontSize: 11.5,
                    fontWeight: _canOpenDiff
                        ? FontWeight.w600
                        : FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ChangeStatColumn(row: row, cards: cards),
          if (_canOpenDiff) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: cards.textMuted),
          ],
        ],
      ),
    );

    final content = Padding(
      padding: EdgeInsets.fromLTRB(8, 8, 8, isLast ? 8 : 0),
      child: body,
    );
    final divider = isLast
        ? null
        : Divider(
            height: 1,
            thickness: 1,
            color: cards.neutralBorder.withValues(alpha: 0.45),
          );

    if (!_canOpenDiff) {
      return Column(
        children: [
          content,
          if (divider case final Divider resolvedDivider) resolvedDivider,
        ],
      );
    }

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: PocketRadii.circular(PocketRadii.md),
            onTap: () => onOpenDiff!(row.diff!),
            child: content,
          ),
        ),
        if (divider case final Divider resolvedDivider) resolvedDivider,
      ],
    );
  }
}

String? _secondaryLabel(ChatChangedFileRowContract row) {
  if (row.renameSummary case final summary?) {
    return summary;
  }

  if (row.directoryLabel case final directory?) {
    return directory;
  }

  return row.currentPath == row.fileName ? null : row.currentPath;
}

String _tertiaryLabel(ChatChangedFileRowContract row) {
  final details = <String>[
    row.languageLabel ?? 'Plain text',
    row.operationLabel.toLowerCase(),
  ];
  if (!row.canOpenDiff) {
    details.add('patch unavailable');
  }
  return details.join(' · ');
}

class _ChangeStatColumn extends StatelessWidget {
  const _ChangeStatColumn({required this.row, required this.cards});

  final ChatChangedFileRowContract row;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    final hasChanges = row.stats.hasChanges;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          hasChanges ? '+${row.stats.additions}' : ' ',
          style: TextStyle(
            color: tealAccent(cards.brightness),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hasChanges ? '-${row.stats.deletions}' : ' ',
          style: TextStyle(
            color: redAccent(cards.brightness),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

Color _accentForOperation(
  ChatChangedFileOperationKind kind,
  Brightness brightness,
) {
  return switch (kind) {
    ChatChangedFileOperationKind.created => tealAccent(brightness),
    ChatChangedFileOperationKind.modified => amberAccent(brightness),
    ChatChangedFileOperationKind.renamed => blueAccent(brightness),
    ChatChangedFileOperationKind.deleted => redAccent(brightness),
  };
}

IconData _iconForOperation(ChatChangedFileOperationKind kind) {
  return switch (kind) {
    ChatChangedFileOperationKind.created => Icons.add_circle_outline_rounded,
    ChatChangedFileOperationKind.modified => Icons.edit_note_rounded,
    ChatChangedFileOperationKind.renamed => Icons.drive_file_move_outline,
    ChatChangedFileOperationKind.deleted => Icons.delete_outline_rounded,
  };
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
    final cards = ConversationCardPalette.of(context);
    final pocket = context.pocketPalette;
    final accent = _accentForOperation(diff.operationKind, cards.brightness);
    final visibleLines = _showFullDiff || !diff.hasPreviewLimit
        ? diff.lines
        : diff.lines.take(diff.previewLineLimit).toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.96,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth >= 1040
              ? 980.0
              : double.infinity;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: pocket.sheetBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border.all(color: cards.neutralBorder),
                  boxShadow: [
                    BoxShadow(
                      color: cards.shadow.withValues(
                        alpha: cards.isDark ? 0.34 : 0.14,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, -12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    const ModalSheetDragHandle(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 14, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  diff.operationLabel.toUpperCase(),
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  diff.fileName,
                                  style: TextStyle(
                                    color: cards.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'monospace',
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  diff.currentPath,
                                  style: TextStyle(
                                    color: cards.textSecondary,
                                    fontSize: 12.5,
                                    fontFamily: 'monospace',
                                    height: 1.35,
                                  ),
                                ),
                                if (diff.renameSummary
                                    case final renameSummary?)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      renameSummary,
                                      style: TextStyle(
                                        color: cards.textMuted,
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 12,
                        children: [
                          _DiffMetric(
                            label: 'Language',
                            value: diff.languageLabel ?? 'Plain text',
                            valueColor: cards.textPrimary,
                          ),
                          _DiffMetric(
                            label: 'Additions',
                            value: '+${diff.stats.additions}',
                            valueColor: tealAccent(cards.brightness),
                          ),
                          _DiffMetric(
                            label: 'Deletions',
                            value: '-${diff.stats.deletions}',
                            valueColor: redAccent(cards.brightness),
                          ),
                          _DiffMetric(
                            label: 'Lines',
                            value: '${diff.lineCount}',
                            valueColor: cards.textPrimary,
                          ),
                        ],
                      ),
                    ),
                    if (diff.hasPreviewLimit)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                        child: _PreviewNotice(
                          cards: cards,
                          accent: accent,
                          previewLineLimit: diff.previewLineLimit,
                          isExpanded: _showFullDiff,
                          onToggle: () {
                            setState(() {
                              _showFullDiff = !_showFullDiff;
                            });
                          },
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: _DiffCodeFrame(
                          diff: diff,
                          cards: cards,
                          accent: accent,
                          visibleLines: visibleLines,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiffMetric extends StatelessWidget {
  const _DiffMetric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: cards.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice({
    required this.cards,
    required this.accent,
    required this.previewLineLimit,
    required this.isExpanded,
    required this.onToggle,
  });

  final ConversationCardPalette cards;
  final Color accent;
  final int previewLineLimit;
  final bool isExpanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cards.tintedSurface(accent, lightAlpha: 0.05, darkAlpha: 0.1),
        borderRadius: PocketRadii.circular(PocketRadii.md),
        border: Border.all(
          color: cards.accentBorder(accent, lightAlpha: 0.2, darkAlpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isExpanded
                    ? 'Full diff loaded.'
                    : 'Showing the first $previewLineLimit lines to keep the review surface responsive.',
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: onToggle,
              child: Text(isExpanded ? 'Show preview' : 'Load full diff'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiffCodeFrame extends StatelessWidget {
  const _DiffCodeFrame({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.visibleLines,
  });

  final ChatChangedFileDiffContract diff;
  final ConversationCardPalette cards;
  final Color accent;
  final List<ChatChangedFileDiffLineContract> visibleLines;

  @override
  Widget build(BuildContext context) {
    final syntaxPalette = ChangedFileSyntaxPalette(
      base: cards.terminalText,
      comment: cards.textMuted,
      keyword: blueAccent(cards.brightness),
      string: tealAccent(cards.brightness),
      number: amberAccent(cards.brightness),
      type: violetAccent(cards.brightness),
      symbol: pinkAccent(cards.brightness),
      function: const Color(0xFFFCD34D),
      attribute: const Color(0xFFF9A8D4),
      meta: cards.textSecondary,
      variable: const Color(0xFFEAB308),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cards.terminalBody,
        borderRadius: PocketRadii.circular(PocketRadii.xl),
        border: Border.all(
          color: cards.accentBorder(accent, lightAlpha: 0.18, darkAlpha: 0.26),
        ),
      ),
      child: Column(
        children: [
          _DiffEditorBar(diff: diff, cards: cards),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final minimumWidth = constraints.maxWidth - 32;
                return Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: minimumWidth),
                        child: SelectionArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: visibleLines
                                .map(
                                  (line) => _DiffLineView(
                                    line: line,
                                    syntaxLanguage: diff.syntaxLanguage,
                                    cards: cards,
                                    syntaxPalette: syntaxPalette,
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffEditorBar extends StatelessWidget {
  const _DiffEditorBar({required this.diff, required this.cards});

  final ChatChangedFileDiffContract diff;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cards.terminalShell,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          bottom: BorderSide(
            color: cards.neutralBorder.withValues(alpha: 0.38),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            ...const [
              _EditorDot(color: Color(0xFFFB7185)),
              SizedBox(width: 6),
              _EditorDot(color: Color(0xFFFBBF24)),
              SizedBox(width: 6),
              _EditorDot(color: Color(0xFF34D399)),
            ],
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                diff.currentPath,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cards.textSecondary,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.2,
                ),
              ),
            ),
            if (diff.languageLabel case final language?)
              Text(
                language,
                style: TextStyle(
                  color: cards.textMuted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditorDot extends StatelessWidget {
  const _EditorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DiffLineView extends StatelessWidget {
  const _DiffLineView({
    required this.line,
    required this.syntaxLanguage,
    required this.cards,
    required this.syntaxPalette,
  });

  final ChatChangedFileDiffLineContract line;
  final String? syntaxLanguage;
  final ConversationCardPalette cards;
  final ChangedFileSyntaxPalette syntaxPalette;

  @override
  Widget build(BuildContext context) {
    final style = _styleForLine(line.kind, cards);
    final lineDisplay = _DiffLineDisplay.fromContract(line);
    final baseTextStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 12.2,
      height: 1.45,
      color: style.foreground,
      fontWeight: style.fontWeight,
    );

    final contentSpan = lineDisplay.shouldHighlight
        ? ChangedFileSyntaxHighlighter.buildTextSpan(
            source: lineDisplay.content,
            language: syntaxLanguage,
            baseStyle: baseTextStyle,
            palette: syntaxPalette,
          )
        : TextSpan(text: lineDisplay.content, style: baseTextStyle);

    return Container(
      color: style.background,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LineNumberCell(number: line.oldLineNumber, cards: cards),
          const SizedBox(width: 8),
          _LineNumberCell(number: line.newLineNumber, cards: cards),
          const SizedBox(width: 10),
          SizedBox(
            width: 14,
            child: Text(
              lineDisplay.prefix,
              style: baseTextStyle.copyWith(color: style.prefixColor),
            ),
          ),
          const SizedBox(width: 8),
          RichText(text: contentSpan, softWrap: false),
        ],
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
        prefixColor: tealAccent(cards.brightness),
      ),
      ChatChangedFileDiffLineKind.deletion => _DiffLineStyle(
        background: Color.alphaBlend(
          redAccent(
            cards.brightness,
          ).withValues(alpha: cards.isDark ? 0.2 : 0.12),
          cards.terminalBody,
        ),
        foreground: cards.terminalText,
        prefixColor: redAccent(cards.brightness),
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
        prefixColor: blueAccent(cards.brightness),
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
        prefixColor: cards.textSecondary,
      ),
      ChatChangedFileDiffLineKind.context => _DiffLineStyle(
        background: cards.terminalBody,
        foreground: cards.terminalText,
        prefixColor: cards.textMuted,
      ),
    };
  }
}

class _LineNumberCell extends StatelessWidget {
  const _LineNumberCell({required this.number, required this.cards});

  final int? number;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(
        number?.toString() ?? '',
        textAlign: TextAlign.right,
        style: TextStyle(
          color: cards.textMuted.withValues(alpha: 0.82),
          fontFamily: 'monospace',
          fontSize: 11.5,
          height: 1.45,
        ),
      ),
    );
  }
}

class _DiffLineDisplay {
  const _DiffLineDisplay({
    required this.prefix,
    required this.content,
    required this.shouldHighlight,
  });

  factory _DiffLineDisplay.fromContract(ChatChangedFileDiffLineContract line) {
    if (line.text.isEmpty) {
      return const _DiffLineDisplay(
        prefix: '',
        content: '',
        shouldHighlight: false,
      );
    }

    if (line.kind == ChatChangedFileDiffLineKind.addition ||
        line.kind == ChatChangedFileDiffLineKind.deletion ||
        (line.kind == ChatChangedFileDiffLineKind.context &&
            line.text.startsWith(' '))) {
      return _DiffLineDisplay(
        prefix: line.text[0],
        content: line.text.length > 1 ? line.text.substring(1) : '',
        shouldHighlight: true,
      );
    }

    return _DiffLineDisplay(
      prefix: '',
      content: line.text,
      shouldHighlight: false,
    );
  }

  final String prefix;
  final String content;
  final bool shouldHighlight;
}

class _DiffLineStyle {
  const _DiffLineStyle({
    required this.background,
    required this.foreground,
    required this.prefixColor,
    this.fontWeight = FontWeight.w500,
  });

  final Color background;
  final Color foreground;
  final Color prefixColor;
  final FontWeight fontWeight;
}
