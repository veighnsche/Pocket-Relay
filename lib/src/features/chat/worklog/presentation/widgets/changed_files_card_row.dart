part of 'changed_files_card.dart';

class _ChangedFileRow extends StatelessWidget {
  const _ChangedFileRow({
    required this.row,
    required this.cards,
    this.onOpenDiff,
  });

  final ChatChangedFileRowContract row;
  final ConversationCardPalette cards;
  final void Function(ChatChangedFileDiffContract diff)? onOpenDiff;

  bool get _canOpenPatch => row.canOpenDiff && onOpenDiff != null;

  (_ChangedFileVisuals visuals, Color accent) _visualsForRow() {
    final brightness = cards.brightness;
    final accent = _accentForOperation(row.operationKind, brightness);
    final visuals = switch (row.operationKind) {
      ChatChangedFileOperationKind.created => const _ChangedFileVisuals(
        icon: Icons.add_circle_outline_rounded,
      ),
      ChatChangedFileOperationKind.modified => const _ChangedFileVisuals(
        icon: Icons.edit_outlined,
      ),
      ChatChangedFileOperationKind.renamed => const _ChangedFileVisuals(
        icon: Icons.drive_file_move_outline,
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
    final body = Padding(
      key: ValueKey<String>('changed_file_row_${row.id}'),
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(visuals.icon, size: 14, color: rowAccent),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.operationLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.25,
                        color: rowAccent,
                      ),
                    ),
                    const SizedBox(width: PocketSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.75,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: cards.textPrimary,
                              height: 1.2,
                            ),
                          ),
                          if (_secondaryLabel(row) case final secondaryLabel?)
                            Text(
                              secondaryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.75,
                                fontFamily: 'monospace',
                                color: cards.textMuted,
                                height: 1.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (row.stats.hasChanges || _tertiaryLabel(row).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (row.stats.hasChanges)
                        Text(
                          '+${row.stats.additions} -${row.stats.deletions}',
                          style: TextStyle(
                            fontSize: 11,
                            color: cards.textMuted,
                          ),
                        ),
                      if (row.stats.hasChanges &&
                          _tertiaryLabel(row).isNotEmpty)
                        Text(
                          '  ·  ',
                          style: TextStyle(
                            fontSize: 11,
                            color: cards.textMuted,
                          ),
                        ),
                      if (_tertiaryLabel(row).isNotEmpty)
                        Text(
                          _tertiaryLabel(row),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: _canOpenPatch
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: _canOpenPatch ? rowAccent : cards.textMuted,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!_canOpenPatch) {
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
