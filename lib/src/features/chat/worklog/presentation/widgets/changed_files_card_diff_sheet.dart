part of 'changed_files_card.dart';

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
                      child: _ChangedFileDiffSheetHeader(
                        diff: diff,
                        cards: cards,
                        accent: accent,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                      child: _ChangedFileDiffSheetMetrics(
                        diff: diff,
                        cards: cards,
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
