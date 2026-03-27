part of 'changed_files_surface.dart';

class _DiffCodeFrame extends StatelessWidget {
  const _DiffCodeFrame({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.review,
    required this.showRawPatch,
    required this.onToggleRawPatch,
    required this.visibleLines,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final Color accent;
  final ChatChangedFileDiffReviewContract review;
  final bool showRawPatch;
  final VoidCallback onToggleRawPatch;
  final List<ChatChangedFileDiffLineContract> visibleLines;

  @override
  Widget build(BuildContext context) {
    final syntaxPalette = ChangedFileSyntaxPalette(
      base: cards.terminalText,
      comment: cards.textMuted,
      keyword: cards.isDark ? const Color(0xFFB8D1F4) : const Color(0xFF93C5FD),
      string: cards.isDark ? const Color(0xFFA5E4D8) : const Color(0xFF6EE7B7),
      number: cards.isDark ? const Color(0xFFF6D28F) : const Color(0xFFFCD34D),
      type: cards.isDark ? const Color(0xFFD5CAF8) : const Color(0xFFC4B5FD),
      symbol: cards.textSecondary,
      function: cards.isDark
          ? const Color(0xFFE9D8A6)
          : const Color(0xFFFDE68A),
      attribute: cards.isDark
          ? const Color(0xFFC7D2E5)
          : const Color(0xFFBFDBFE),
      meta: cards.textSecondary,
      variable: cards.isDark
          ? const Color(0xFFF3D38E)
          : const Color(0xFFFCD34D),
    );
    final shouldShowRawPatch = showRawPatch || review.isEmpty;
    final canToggleRawPatch = diff.lines.isNotEmpty && !review.isEmpty;

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
          _DiffEditorBar(
            diff: diff,
            cards: cards,
            showRawPatch: shouldShowRawPatch,
            canToggleRawPatch: canToggleRawPatch,
            onToggleRawPatch: onToggleRawPatch,
          ),
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
                          child: shouldShowRawPatch
                              ? _RawDiffContent(
                                  diff: diff,
                                  cards: cards,
                                  syntaxPalette: syntaxPalette,
                                  visibleLines: visibleLines,
                                )
                              : _ReviewDiffContent(
                                  diff: diff,
                                  cards: cards,
                                  accent: accent,
                                  syntaxPalette: syntaxPalette,
                                  review: review,
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
  const _DiffEditorBar({
    required this.diff,
    required this.cards,
    required this.showRawPatch,
    required this.canToggleRawPatch,
    required this.onToggleRawPatch,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final bool showRawPatch;
  final bool canToggleRawPatch;
  final VoidCallback onToggleRawPatch;

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
                style: PocketTypography.monospaceStyle(
                  base: const TextStyle(),
                  color: cards.textSecondary,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),
            ),
            if (canToggleRawPatch) ...[
              TextButton(
                onPressed: onToggleRawPatch,
                style: TextButton.styleFrom(
                  foregroundColor: showRawPatch
                      ? cards.terminalText
                      : cards.textMuted,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(showRawPatch ? 'Readable view' : 'Raw patch'),
              ),
              const SizedBox(width: 4),
            ],
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

class _ReviewDiffContent extends StatelessWidget {
  const _ReviewDiffContent({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.syntaxPalette,
    required this.review,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final Color accent;
  final ChangedFileSyntaxPalette syntaxPalette;
  final ChatChangedFileDiffReviewContract review;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (review.hasMetadata)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: _ReviewMetadataLines(
              cards: cards,
              accent: accent,
              metadataLines: review.metadataLines,
            ),
          ),
        ...review.sections.indexed.map((entry) {
          return Padding(
            padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 10),
            child: _ReviewSectionView(
              diff: diff,
              cards: cards,
              accent: accent,
              syntaxPalette: syntaxPalette,
              section: entry.$2,
            ),
          );
        }),
        if (!review.hasSections)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Text(
              'No code preview available.',
              style: TextStyle(
                color: cards.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewMetadataLines extends StatelessWidget {
  const _ReviewMetadataLines({
    required this.cards,
    required this.accent,
    required this.metadataLines,
  });

  final TranscriptPalette cards;
  final Color accent;
  final List<String> metadataLines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: accent.withValues(alpha: cards.isDark ? 0.55 : 0.45),
            width: 2.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: metadataLines.indexed
              .map((entry) {
                return Padding(
                  padding: EdgeInsets.only(top: entry.$1 == 0 ? 0 : 4),
                  child: Text(
                    entry.$2,
                    style: TextStyle(
                      color: cards.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _ReviewSectionView extends StatelessWidget {
  const _ReviewSectionView({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.syntaxPalette,
    required this.section,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final Color accent;
  final ChangedFileSyntaxPalette syntaxPalette;
  final ChatChangedFileDiffReviewSectionContract section;

  @override
  Widget build(BuildContext context) {
    return switch (section.kind) {
      ChatChangedFileDiffReviewSectionKind.hunk => _ReviewHunkSection(
        diff: diff,
        cards: cards,
        accent: accent,
        syntaxPalette: syntaxPalette,
        section: section,
      ),
      ChatChangedFileDiffReviewSectionKind.collapsedGap => _CollapsedGapSection(
        cards: cards,
        hiddenLineCount: section.hiddenLineCount ?? 0,
      ),
      ChatChangedFileDiffReviewSectionKind.binaryMessage =>
        _BinaryMessageSection(
          cards: cards,
          message: section.message ?? 'Binary patch data available.',
        ),
    };
  }
}

class _ReviewHunkSection extends StatelessWidget {
  const _ReviewHunkSection({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.syntaxPalette,
    required this.section,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final Color accent;
  final ChangedFileSyntaxPalette syntaxPalette;
  final ChatChangedFileDiffReviewSectionContract section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (section.label case final label?)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: _HunkSectionLabel(
              cards: cards,
              accent: accent,
              label: label,
            ),
          ),
        ...section.rows.map(
          (row) => _ReviewRowView(
            row: row,
            syntaxLanguage: diff.syntaxLanguage,
            cards: cards,
            syntaxPalette: syntaxPalette,
          ),
        ),
      ],
    );
  }
}

class _HunkSectionLabel extends StatelessWidget {
  const _HunkSectionLabel({
    required this.cards,
    required this.accent,
    required this.label,
  });

  final TranscriptPalette cards;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: cards.isDark ? 0.9 : 1),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: cards.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 84,
          height: 1,
          color: cards.neutralBorder.withValues(alpha: 0.45),
        ),
      ],
    );
  }
}

class _CollapsedGapSection extends StatelessWidget {
  const _CollapsedGapSection({
    required this.cards,
    required this.hiddenLineCount,
  });

  final TranscriptPalette cards;
  final int hiddenLineCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 1,
            color: cards.neutralBorder.withValues(alpha: 0.28),
          ),
          const SizedBox(width: 12),
          Text(
            '$hiddenLineCount unchanged lines',
            style: TextStyle(
              color: cards.textMuted,
              fontSize: 11.25,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 1,
            color: cards.neutralBorder.withValues(alpha: 0.28),
          ),
        ],
      ),
    );
  }
}

class _BinaryMessageSection extends StatelessWidget {
  const _BinaryMessageSection({required this.cards, required this.message});

  final TranscriptPalette cards;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: cards.neutralBorder.withValues(alpha: 0.6),
            width: 2.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
        child: Text(
          message,
          style: _changedFileCodeTextStyle(
            color: cards.terminalText,
            fontSize: 12.2,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _ReviewRowView extends StatelessWidget {
  const _ReviewRowView({
    required this.row,
    required this.syntaxLanguage,
    required this.cards,
    required this.syntaxPalette,
  });

  final ChatChangedFileDiffReviewRowContract row;
  final String? syntaxLanguage;
  final TranscriptPalette cards;
  final ChangedFileSyntaxPalette syntaxPalette;

  @override
  Widget build(BuildContext context) {
    final style = _styleForReviewRow(row.kind, cards);
    final baseTextStyle = _changedFileCodeTextStyle(
      color: style.foreground,
      fontSize: 12.2,
      height: 1.5,
    );

    final contentSpan = ChangedFileSyntaxHighlighter.buildTextSpan(
      source: row.content,
      language: syntaxLanguage,
      baseStyle: baseTextStyle,
      palette: syntaxPalette,
    );

    return Container(
      decoration: BoxDecoration(
        color: style.background,
        border: Border(left: BorderSide(color: style.railColor, width: 2.5)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              row.lineToken,
              textAlign: TextAlign.right,
              style: _changedFileCodeTextStyle(
                color: style.tokenColor,
                fontSize: 11.25,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          RichText(text: contentSpan, softWrap: false),
        ],
      ),
    );
  }
}

class _RawDiffContent extends StatelessWidget {
  const _RawDiffContent({
    required this.diff,
    required this.cards,
    required this.syntaxPalette,
    required this.visibleLines,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
  final ChangedFileSyntaxPalette syntaxPalette;
  final List<ChatChangedFileDiffLineContract> visibleLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: visibleLines
          .map(
            (line) => _RawDiffLineView(
              line: line,
              syntaxLanguage: diff.syntaxLanguage,
              cards: cards,
              syntaxPalette: syntaxPalette,
            ),
          )
          .toList(growable: false),
    );
  }
}

class _RawDiffLineView extends StatelessWidget {
  const _RawDiffLineView({
    required this.line,
    required this.syntaxLanguage,
    required this.cards,
    required this.syntaxPalette,
  });

  final ChatChangedFileDiffLineContract line;
  final String? syntaxLanguage;
  final TranscriptPalette cards;
  final ChangedFileSyntaxPalette syntaxPalette;

  @override
  Widget build(BuildContext context) {
    final style = _styleForDiffLine(line.kind, cards);
    final lineDisplay = _DiffLineDisplay.fromContract(line);
    final baseTextStyle = _changedFileCodeTextStyle(
      color: style.foreground,
      fontSize: 12.2,
      height: 1.45,
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
}

class _LineNumberCell extends StatelessWidget {
  const _LineNumberCell({required this.number, required this.cards});

  final int? number;
  final TranscriptPalette cards;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      child: Text(
        number?.toString() ?? '',
        textAlign: TextAlign.right,
        style: _changedFileCodeTextStyle(
          color: cards.textMuted.withValues(alpha: 0.82),
          fontSize: 11.5,
          height: 1.45,
        ),
      ),
    );
  }
}
