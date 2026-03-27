part of 'changed_files_surface.dart';

class _DiffCodeFrame extends StatelessWidget {
  const _DiffCodeFrame({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.visibleLines,
  });

  final ChatChangedFileDiffContract diff;
  final TranscriptPalette cards;
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
  final TranscriptPalette cards;

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
  final TranscriptPalette cards;
  final ChangedFileSyntaxPalette syntaxPalette;

  @override
  Widget build(BuildContext context) {
    final style = _styleForDiffLine(line.kind, cards);
    final lineDisplay = _DiffLineDisplay.fromContract(line);
    final baseTextStyle = PocketTypography.monospaceStyle(
      base: const TextStyle(),
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
        style: PocketTypography.monospaceStyle(
          base: const TextStyle(),
          color: cards.textMuted.withValues(alpha: 0.82),
          fontSize: 11.5,
          height: 1.45,
        ),
      ),
    );
  }
}
