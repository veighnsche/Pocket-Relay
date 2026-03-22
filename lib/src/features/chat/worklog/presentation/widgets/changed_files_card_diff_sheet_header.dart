part of 'changed_files_card.dart';

class _ChangedFileDiffSheetHeader extends StatelessWidget {
  const _ChangedFileDiffSheetHeader({
    required this.diff,
    required this.cards,
    required this.accent,
    required this.onClose,
  });

  final ChatChangedFileDiffContract diff;
  final ConversationCardPalette cards;
  final Color accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
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
              if (diff.renameSummary case final renameSummary?)
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
          onPressed: onClose,
          icon: Icon(Icons.close, color: cards.textMuted),
        ),
      ],
    );
  }
}

class _ChangedFileDiffSheetMetrics extends StatelessWidget {
  const _ChangedFileDiffSheetMetrics({required this.diff, required this.cards});

  final ChatChangedFileDiffContract diff;
  final ConversationCardPalette cards;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
