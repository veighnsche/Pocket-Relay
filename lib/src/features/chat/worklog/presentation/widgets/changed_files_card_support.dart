part of 'changed_files_card.dart';

String _summaryLabel(ChatChangedFilesItemContract item) {
  final fileLabel =
      '${item.fileCount} ${item.fileCount == 1 ? 'file' : 'files'}';
  if (!item.hasHeaderStats) {
    return '$fileLabel changed';
  }

  return '$fileLabel changed · ${item.headerStats.additions} additions · ${item.headerStats.deletions} deletions';
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
  final details = <String>[];
  if (row.languageLabel case final language?) {
    details.add(language);
  }
  details.add(row.operationLabel.toLowerCase());
  if (!row.canOpenDiff) {
    details.add('patch unavailable');
  }
  return details.join(' · ');
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

_DiffLineStyle _styleForDiffLine(
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
