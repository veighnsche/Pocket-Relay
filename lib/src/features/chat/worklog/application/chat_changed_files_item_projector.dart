import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';

class ChatChangedFilesItemProjector {
  const ChatChangedFilesItemProjector();

  ChatChangedFilesItemContract project(CodexChangedFilesBlock block) {
    final patches = _parseUnifiedDiff(block.unifiedDiff);
    final files = _displayFiles(block.files, patches);
    final headerStats = _resolveHeaderStats(files: files, patches: patches);

    return ChatChangedFilesItemContract(
      id: block.id,
      title: block.title,
      isRunning: block.isRunning,
      headerStats: ChatChangedFileStatsContract(
        additions: headerStats.additions,
        deletions: headerStats.deletions,
      ),
      rows: files.indexed
          .map((entry) {
            final index = entry.$1;
            final file = entry.$2;
            final rowId = '${block.id}_$index';
            final patch = _patchForFile(
              file,
              patches,
              totalFiles: files.length,
            );
            final stats = _resolveFileStats(file: file, patch: patch);
            final operationKind = _resolveOperationKind(
              file: file,
              patch: patch,
            );
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
                  : ChatChangedFileDiffContract(
                      id: rowId,
                      file: presentation,
                      operationKind: operationKind,
                      operationLabel: operationLabel,
                      stats: ChatChangedFileStatsContract(
                        additions: stats.additions,
                        deletions: stats.deletions,
                      ),
                      statusLabel: patch.statusLabel,
                      lines: patch.lines
                          .map(
                            (line) => ChatChangedFileDiffLineContract(
                              text: line.text,
                              kind: _mapLineKind(line.kind),
                              oldLineNumber: line.oldLineNumber,
                              newLineNumber: line.newLineNumber,
                            ),
                          )
                          .toList(growable: false),
                    ),
            );
          })
          .toList(growable: false),
    );
  }

  ChatChangedFileDiffLineKind _mapLineKind(_DiffLineKind kind) {
    return switch (kind) {
      _DiffLineKind.meta => ChatChangedFileDiffLineKind.meta,
      _DiffLineKind.hunk => ChatChangedFileDiffLineKind.hunk,
      _DiffLineKind.addition => ChatChangedFileDiffLineKind.addition,
      _DiffLineKind.deletion => ChatChangedFileDiffLineKind.deletion,
      _DiffLineKind.context => ChatChangedFileDiffLineKind.context,
    };
  }
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

List<_ParsedDiffPatch> _parseUnifiedDiff(String? unifiedDiff) {
  final trimmed = unifiedDiff?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return const <_ParsedDiffPatch>[];
  }

  final lines = trimmed.split(RegExp(r'\r?\n'));
  final patches = <_ParsedDiffPatch>[];
  final currentLines = <_DiffLine>[];
  String? diffPath;
  String? newPath;
  String? oldPath;
  String? renameToPath;
  String? renameFromPath;
  int? oldLineCursor;
  int? newLineCursor;
  var additions = 0;
  var deletions = 0;
  var isNewFile = false;
  var isDeletedFile = false;
  var isBinary = false;

  void resetState() {
    currentLines.clear();
    diffPath = null;
    newPath = null;
    oldPath = null;
    renameToPath = null;
    renameFromPath = null;
    oldLineCursor = null;
    newLineCursor = null;
    additions = 0;
    deletions = 0;
    isNewFile = false;
    isDeletedFile = false;
    isBinary = false;
  }

  void commitPatch() {
    if (currentLines.isEmpty) {
      return;
    }

    final resolvedPath =
        renameToPath ??
        newPath ??
        diffPath ??
        renameFromPath ??
        oldPath ??
        'Unknown file';
    final matchedPaths = <String>{
      _normalizeDiffPath(diffPath),
      _normalizeDiffPath(newPath),
      _normalizeDiffPath(oldPath),
      _normalizeDiffPath(renameToPath),
      _normalizeDiffPath(renameFromPath),
      _normalizeDiffPath(resolvedPath),
    }..removeWhere((path) => path.isEmpty);
    final statusLabel = switch ((
      isNewFile,
      isDeletedFile,
      renameToPath != null,
    )) {
      (true, _, _) => 'new file',
      (_, true, _) => 'deleted file',
      (_, _, true) => 'renamed',
      _ => null,
    };

    patches.add(
      _ParsedDiffPatch(
        path: resolvedPath,
        statusLabel: statusLabel,
        additions: additions,
        deletions: deletions,
        isBinary: isBinary,
        matchedPaths: matchedPaths,
        renameFromPath: renameFromPath,
        renameToPath: renameToPath,
        lines: List<_DiffLine>.unmodifiable(currentLines),
      ),
    );
  }

  resetState();

  for (final line in lines) {
    final isOldPathHeader = _isOldDiffPathHeaderLine(line);
    final isNewPathHeader = _isNewDiffPathHeaderLine(line);
    if (line.startsWith('diff --git ')) {
      commitPatch();
      resetState();
      final match = RegExp(r'^diff --git a/(.+?) b/(.+)$').firstMatch(line);
      diffPath = _normalizeDiffPath(match?.group(2));
    } else if (isOldPathHeader &&
        currentLines.isNotEmpty &&
        (oldPath != null ||
            newPath != null ||
            additions > 0 ||
            deletions > 0)) {
      commitPatch();
      resetState();
    }

    if (line.startsWith('new file mode ')) {
      isNewFile = true;
    } else if (line.startsWith('deleted file mode ')) {
      isDeletedFile = true;
    } else if (line.startsWith('rename from ')) {
      renameFromPath = _normalizeDiffPath(
        line.substring('rename from '.length),
      );
    } else if (line.startsWith('rename to ')) {
      renameToPath = _normalizeDiffPath(line.substring('rename to '.length));
    } else if (isOldPathHeader) {
      oldPath = _normalizeDiffPath(line.substring(4).trim());
    } else if (isNewPathHeader) {
      newPath = _normalizeDiffPath(line.substring(4).trim());
    }
    if (line.startsWith('Binary files ') ||
        line.startsWith('GIT binary patch')) {
      isBinary = true;
    }

    final kind = _classifyDiffLine(line, isBinary: isBinary);
    if (kind == _DiffLineKind.hunk) {
      final range = _parseHunkRange(line);
      if (range != null) {
        oldLineCursor = range.oldStart;
        newLineCursor = range.newStart;
      }
    }

    int? oldLineNumber;
    int? newLineNumber;
    switch (kind) {
      case _DiffLineKind.addition:
        newLineNumber = newLineCursor;
        if (newLineCursor != null) {
          newLineCursor = newLineCursor! + 1;
        }
      case _DiffLineKind.deletion:
        oldLineNumber = oldLineCursor;
        if (oldLineCursor != null) {
          oldLineCursor = oldLineCursor! + 1;
        }
      case _DiffLineKind.context:
        if (line.startsWith(' ')) {
          oldLineNumber = oldLineCursor;
          newLineNumber = newLineCursor;
          if (oldLineCursor != null) {
            oldLineCursor = oldLineCursor! + 1;
          }
          if (newLineCursor != null) {
            newLineCursor = newLineCursor! + 1;
          }
        }
      case _DiffLineKind.meta || _DiffLineKind.hunk:
        break;
    }

    currentLines.add(
      _DiffLine(
        text: line,
        kind: kind,
        oldLineNumber: oldLineNumber,
        newLineNumber: newLineNumber,
      ),
    );

    if (kind == _DiffLineKind.addition) {
      additions += 1;
    } else if (kind == _DiffLineKind.deletion) {
      deletions += 1;
    }
  }

  commitPatch();
  return patches;
}

_HunkRange? _parseHunkRange(String line) {
  final match = RegExp(
    r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@',
  ).firstMatch(line);
  if (match == null) {
    return null;
  }

  return _HunkRange(
    oldStart: int.parse(match.group(1)!),
    newStart: int.parse(match.group(2)!),
  );
}

String _normalizeDiffPath(String? rawPath) {
  if (rawPath == null) {
    return '';
  }

  final trimmed = rawPath.trim();
  if (trimmed.isEmpty || trimmed == '/dev/null') {
    return '';
  }

  if (trimmed.startsWith('a/') || trimmed.startsWith('b/')) {
    return trimmed.substring(2);
  }

  return trimmed;
}

_DiffLineKind _classifyDiffLine(String line, {required bool isBinary}) {
  if (line.startsWith('@@')) {
    return _DiffLineKind.hunk;
  }

  if (line.startsWith('diff --git ') ||
      line.startsWith('index ') ||
      line.startsWith('new file mode ') ||
      line.startsWith('deleted file mode ') ||
      line.startsWith('rename from ') ||
      line.startsWith('rename to ') ||
      line.startsWith('similarity index ') ||
      line.startsWith(r'\ No newline at end of file') ||
      line.startsWith('Binary files ') ||
      line.startsWith('GIT binary patch')) {
    return _DiffLineKind.meta;
  }

  if (_isOldDiffPathHeaderLine(line) ||
      _isNewDiffPathHeaderLine(line) ||
      isBinary) {
    return _DiffLineKind.meta;
  }

  if (line.startsWith('+')) {
    return _DiffLineKind.addition;
  }

  if (line.startsWith('-')) {
    return _DiffLineKind.deletion;
  }

  return _DiffLineKind.context;
}

bool _isOldDiffPathHeaderLine(String line) {
  return line.startsWith('--- a/') ||
      line.startsWith('--- b/') ||
      line == '--- /dev/null';
}

bool _isNewDiffPathHeaderLine(String line) {
  return line.startsWith('+++ a/') ||
      line.startsWith('+++ b/') ||
      line == '+++ /dev/null';
}

enum _DiffLineKind { meta, hunk, addition, deletion, context }

class _DiffLine {
  const _DiffLine({
    required this.text,
    required this.kind,
    this.oldLineNumber,
    this.newLineNumber,
  });

  final String text;
  final _DiffLineKind kind;
  final int? oldLineNumber;
  final int? newLineNumber;
}

class _ParsedDiffPatch {
  const _ParsedDiffPatch({
    required this.path,
    required this.lines,
    required this.additions,
    required this.deletions,
    required this.isBinary,
    required this.matchedPaths,
    this.renameFromPath,
    this.renameToPath,
    this.statusLabel,
  });

  final String path;
  final List<_DiffLine> lines;
  final int additions;
  final int deletions;
  final bool isBinary;
  final Set<String> matchedPaths;
  final String? renameFromPath;
  final String? renameToPath;
  final String? statusLabel;
}

class _DiffStats {
  const _DiffStats({this.additions = 0, this.deletions = 0});

  final int additions;
  final int deletions;
}

class _HunkRange {
  const _HunkRange({required this.oldStart, required this.newStart});

  final int oldStart;
  final int newStart;
}
