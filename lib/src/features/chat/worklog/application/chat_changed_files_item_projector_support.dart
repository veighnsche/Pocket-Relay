part of 'chat_changed_files_item_projector.dart';

ChatChangedFileRowContract _projectChangedFileRow({
  required String blockId,
  required int index,
  required CodexChangedFile file,
  required List<_ParsedDiffPatch> patches,
  required int totalFiles,
}) {
  final rowId = '${blockId}_$index';
  final patch = _patchForFile(file, patches, totalFiles: totalFiles);
  final stats = _resolveFileStats(file: file, patch: patch);
  final operationKind = _resolveOperationKind(file: file, patch: patch);
  final operationLabel = _operationLabel(operationKind);
  final presentation = ChatChangedFilePresentationContract.fromPaths(
    path: file.path,
    movePath: file.movePath,
    isBinary: patch?.isBinary ?? false,
  );

  return ChatChangedFileRowContract(
    id: rowId,
    file: presentation,
    operationKind: operationKind,
    operationLabel: operationLabel,
    stats: ChatChangedFileStatsContract(
      additions: stats.additions,
      deletions: stats.deletions,
    ),
    diff: patch == null
        ? null
        : () {
            const previewLineLimit = 320;
            final diffLines = patch.lines
                .map(
                  (line) => ChatChangedFileDiffLineContract(
                    text: line.text,
                    kind: const ChatChangedFilesItemProjector()._mapLineKind(
                      line.kind,
                    ),
                    oldLineNumber: line.oldLineNumber,
                    newLineNumber: line.newLineNumber,
                  ),
                )
                .toList(growable: false);
            final review = _buildDiffReview(
              lines: diffLines,
              isBinary: patch.isBinary,
            );
            final previewReview = diffLines.length <= previewLineLimit
                ? review
                : _buildDiffReview(
                    lines: diffLines
                        .take(previewLineLimit)
                        .toList(growable: false),
                    isBinary: patch.isBinary,
                  );

            return ChatChangedFileDiffContract(
              id: rowId,
              file: presentation,
              operationKind: operationKind,
              operationLabel: operationLabel,
              stats: ChatChangedFileStatsContract(
                additions: stats.additions,
                deletions: stats.deletions,
              ),
              lines: diffLines,
              review: review,
              previewReview: previewReview,
              statusLabel: patch.statusLabel,
              previewLineLimit: previewLineLimit,
            );
          }(),
  );
}

ChatChangedFileOperationKind _resolveOperationKind({
  required CodexChangedFile file,
  required _ParsedDiffPatch? patch,
}) {
  switch (patch?.statusLabel) {
    case 'new file':
      return ChatChangedFileOperationKind.created;
    case 'deleted file':
      return ChatChangedFileOperationKind.deleted;
    case 'renamed':
      return ChatChangedFileOperationKind.renamed;
  }

  final movePath = file.movePath?.trim();
  if (movePath != null && movePath.isNotEmpty && movePath != file.path) {
    return ChatChangedFileOperationKind.renamed;
  }

  return ChatChangedFileOperationKind.modified;
}

String _operationLabel(ChatChangedFileOperationKind kind) {
  return switch (kind) {
    ChatChangedFileOperationKind.created => 'Created',
    ChatChangedFileOperationKind.modified => 'Edited',
    ChatChangedFileOperationKind.renamed => 'Renamed',
    ChatChangedFileOperationKind.deleted => 'Deleted',
  };
}

List<CodexChangedFile> _displayFiles(
  List<CodexChangedFile> files,
  List<_ParsedDiffPatch> patches,
) {
  final baseFiles = files.isNotEmpty
      ? files
      : patches
            .map(
              (patch) => CodexChangedFile(
                path: patch.renameFromPath ?? patch.path,
                movePath: patch.renameToPath,
                additions: patch.additions,
                deletions: patch.deletions,
              ),
            )
            .toList(growable: false);
  if (baseFiles.isEmpty) {
    return const <CodexChangedFile>[];
  }

  return baseFiles
      .map(
        (file) => _enrichFileFromPatch(
          file,
          _patchForFile(file, patches, totalFiles: baseFiles.length),
        ),
      )
      .toList(growable: false);
}

CodexChangedFile _enrichFileFromPatch(
  CodexChangedFile file,
  _ParsedDiffPatch? patch,
) {
  if (patch == null) {
    return file;
  }

  final renameFromPath = patch.renameFromPath;
  final renameToPath = patch.renameToPath;
  if (renameFromPath == null && renameToPath == null) {
    return file;
  }

  final displayPath = renameFromPath ?? file.path;
  final movePath = renameToPath == null || renameToPath == displayPath
      ? file.movePath
      : renameToPath;
  return file.copyWith(path: displayPath, movePath: movePath);
}

_ParsedDiffPatch? _patchForFile(
  CodexChangedFile file,
  List<_ParsedDiffPatch> patches, {
  required int totalFiles,
}) {
  if (patches.isEmpty) {
    return null;
  }

  final normalizedPath = _normalizeDiffPath(file.path);
  for (final patch in patches) {
    if (patch.matchedPaths.contains(normalizedPath)) {
      return patch;
    }
  }

  if (totalFiles == 1 &&
      patches.length == 1 &&
      patches.single.matchedPaths.isEmpty) {
    return patches.single;
  }

  return null;
}

_DiffStats _resolveHeaderStats({
  required List<CodexChangedFile> files,
  required List<_ParsedDiffPatch> patches,
}) {
  final fileStats = files.fold<_DiffStats>(const _DiffStats(), (sum, file) {
    final stats = _resolveFileStats(
      file: file,
      patch: _patchForFile(file, patches, totalFiles: files.length),
    );
    return _DiffStats(
      additions: sum.additions + stats.additions,
      deletions: sum.deletions + stats.deletions,
    );
  });
  if (fileStats.additions > 0 || fileStats.deletions > 0) {
    return fileStats;
  }

  return patches.fold<_DiffStats>(
    const _DiffStats(),
    (sum, patch) => _DiffStats(
      additions: sum.additions + patch.additions,
      deletions: sum.deletions + patch.deletions,
    ),
  );
}

_DiffStats _resolveFileStats({
  required CodexChangedFile file,
  required _ParsedDiffPatch? patch,
}) {
  if (patch == null) {
    return _DiffStats(additions: file.additions, deletions: file.deletions);
  }

  return _DiffStats(
    additions: file.additions > 0 ? file.additions : patch.additions,
    deletions: file.deletions > 0 ? file.deletions : patch.deletions,
  );
}

class _DiffStats {
  const _DiffStats({this.additions = 0, this.deletions = 0});

  final int additions;
  final int deletions;
}
