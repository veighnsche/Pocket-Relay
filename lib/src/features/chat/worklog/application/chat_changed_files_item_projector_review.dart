part of 'chat_changed_files_item_projector.dart';

ChatChangedFileDiffReviewContract _buildDiffReview({
  required List<ChatChangedFileDiffLineContract> lines,
  required bool isBinary,
}) {
  final metadataLines = _buildReviewMetadataLines(lines);
  if (isBinary) {
    return ChatChangedFileDiffReviewContract(
      metadataLines: metadataLines,
      sections: _buildBinaryReviewSections(lines),
    );
  }

  return ChatChangedFileDiffReviewContract(
    metadataLines: metadataLines,
    sections: _buildCodeReviewSections(lines: lines),
  );
}

List<String> _buildReviewMetadataLines(
  List<ChatChangedFileDiffLineContract> lines,
) {
  final metadataLines = <String>[];
  for (final line in lines) {
    if (line.kind != ChatChangedFileDiffLineKind.meta) {
      continue;
    }

    final text = line.text.trim();
    if (text.startsWith('similarity index ')) {
      metadataLines.add(
        'Similarity ${text.substring('similarity index '.length)}',
      );
      continue;
    }
    if (text == r'\ No newline at end of file') {
      metadataLines.add('No newline at end of file');
    }
  }
  return List<String>.unmodifiable(metadataLines);
}

List<ChatChangedFileDiffReviewSectionContract> _buildBinaryReviewSections(
  List<ChatChangedFileDiffLineContract> lines,
) {
  final messages = lines
      .where((line) => line.kind == ChatChangedFileDiffLineKind.meta)
      .map((line) => line.text.trim())
      .where(
        (text) =>
            text.startsWith('Binary files ') || text == 'GIT binary patch',
      )
      .toList(growable: false);
  if (messages.isEmpty) {
    return const <ChatChangedFileDiffReviewSectionContract>[];
  }

  return <ChatChangedFileDiffReviewSectionContract>[
    ChatChangedFileDiffReviewSectionContract(
      kind: ChatChangedFileDiffReviewSectionKind.binaryMessage,
      message: messages.join('\n'),
    ),
  ];
}

List<ChatChangedFileDiffReviewSectionContract> _buildCodeReviewSections({
  required List<ChatChangedFileDiffLineContract> lines,
}) {
  final sections = <ChatChangedFileDiffReviewSectionContract>[];
  final currentRows = <ChatChangedFileDiffReviewRowContract>[];
  String? currentLabel;

  void commitHunk() {
    if (currentRows.isEmpty) {
      currentLabel = null;
      return;
    }
    _appendCollapsedContextSections(
      sections: sections,
      rows: currentRows,
      label: currentLabel ?? 'File change',
    );
    currentRows.clear();
    currentLabel = null;
  }

  for (final line in lines) {
    switch (line.kind) {
      case ChatChangedFileDiffLineKind.meta:
        continue;
      case ChatChangedFileDiffLineKind.hunk:
        commitHunk();
        currentLabel = _reviewLabelForHunk(line.text);
      case ChatChangedFileDiffLineKind.addition ||
          ChatChangedFileDiffLineKind.deletion ||
          ChatChangedFileDiffLineKind.context:
        currentRows.add(_reviewRowFromLine(line));
    }
  }

  commitHunk();
  if (sections.isEmpty && currentRows.isEmpty) {
    final fallbackRows = lines
        .where(
          (line) =>
              line.kind == ChatChangedFileDiffLineKind.addition ||
              line.kind == ChatChangedFileDiffLineKind.deletion ||
              line.kind == ChatChangedFileDiffLineKind.context,
        )
        .map(_reviewRowFromLine)
        .toList(growable: false);
    if (fallbackRows.isNotEmpty) {
      _appendCollapsedContextSections(
        sections: sections,
        rows: fallbackRows,
        label: 'File change',
      );
    }
  }

  return List<ChatChangedFileDiffReviewSectionContract>.unmodifiable(sections);
}

void _appendCollapsedContextSections({
  required List<ChatChangedFileDiffReviewSectionContract> sections,
  required List<ChatChangedFileDiffReviewRowContract> rows,
  required String label,
}) {
  const collapsedEdgeContextSize = 2;
  final currentChunk = <ChatChangedFileDiffReviewRowContract>[];
  String? nextLabel = label;
  var index = 0;

  void commitChunk() {
    if (currentChunk.isEmpty) {
      return;
    }
    sections.add(
      ChatChangedFileDiffReviewSectionContract(
        kind: ChatChangedFileDiffReviewSectionKind.hunk,
        label: nextLabel,
        rows: List<ChatChangedFileDiffReviewRowContract>.unmodifiable(
          currentChunk.toList(growable: false),
        ),
      ),
    );
    currentChunk.clear();
    nextLabel = null;
  }

  while (index < rows.length) {
    final row = rows[index];
    if (row.kind != ChatChangedFileDiffReviewRowKind.context) {
      currentChunk.add(row);
      index += 1;
      continue;
    }

    final start = index;
    while (index < rows.length &&
        rows[index].kind == ChatChangedFileDiffReviewRowKind.context) {
      index += 1;
    }
    final run = rows.sublist(start, index);
    if (run.length <= collapsedEdgeContextSize * 2) {
      currentChunk.addAll(run);
      continue;
    }

    currentChunk.addAll(run.take(collapsedEdgeContextSize));
    commitChunk();
    sections.add(
      ChatChangedFileDiffReviewSectionContract(
        kind: ChatChangedFileDiffReviewSectionKind.collapsedGap,
        hiddenLineCount: run.length - (collapsedEdgeContextSize * 2),
      ),
    );
    currentChunk.addAll(run.skip(run.length - collapsedEdgeContextSize));
  }

  commitChunk();
}

ChatChangedFileDiffReviewRowContract _reviewRowFromLine(
  ChatChangedFileDiffLineContract line,
) {
  return ChatChangedFileDiffReviewRowContract(
    kind: switch (line.kind) {
      ChatChangedFileDiffLineKind.addition =>
        ChatChangedFileDiffReviewRowKind.addition,
      ChatChangedFileDiffLineKind.deletion =>
        ChatChangedFileDiffReviewRowKind.deletion,
      ChatChangedFileDiffLineKind.context =>
        ChatChangedFileDiffReviewRowKind.context,
      ChatChangedFileDiffLineKind.meta ||
      ChatChangedFileDiffLineKind.hunk => throw ArgumentError.value(
        line.kind,
        'line.kind',
        'Unsupported line kind for a review row.',
      ),
    },
    content: _contentForReviewLine(line),
    lineToken: _lineTokenForReviewLine(line),
    oldLineNumber: line.oldLineNumber,
    newLineNumber: line.newLineNumber,
  );
}

String _contentForReviewLine(ChatChangedFileDiffLineContract line) {
  final text = line.text;
  if (text.isEmpty) {
    return text;
  }

  if ((line.kind == ChatChangedFileDiffLineKind.addition ||
          line.kind == ChatChangedFileDiffLineKind.deletion ||
          line.kind == ChatChangedFileDiffLineKind.context) &&
      (text.startsWith('+') || text.startsWith('-') || text.startsWith(' '))) {
    return text.substring(1);
  }

  return text;
}

String _lineTokenForReviewLine(ChatChangedFileDiffLineContract line) {
  return switch (line.kind) {
    ChatChangedFileDiffLineKind.addition =>
      line.newLineNumber == null ? '+' : '+${line.newLineNumber}',
    ChatChangedFileDiffLineKind.deletion =>
      line.oldLineNumber == null ? '-' : '-${line.oldLineNumber}',
    ChatChangedFileDiffLineKind.context =>
      '${line.newLineNumber ?? line.oldLineNumber ?? ''}',
    ChatChangedFileDiffLineKind.meta || ChatChangedFileDiffLineKind.hunk => '',
  };
}

String _reviewLabelForHunk(String line) {
  final match = RegExp(
    r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@',
  ).firstMatch(line);
  if (match == null) {
    return 'File change';
  }

  final oldStart = int.parse(match.group(1)!);
  final oldCount = int.tryParse(match.group(2) ?? '') ?? 1;
  final newStart = int.parse(match.group(3)!);
  final newCount = int.tryParse(match.group(4) ?? '') ?? 1;
  final anchor = newStart > 0 ? newStart : oldStart;
  final spanCount = newCount > 0 ? newCount : oldCount;
  if (spanCount <= 1) {
    return 'Around line $anchor';
  }

  final end = anchor + spanCount - 1;
  return 'Around lines $anchor-$end';
}
