import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';

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
            return ChatChangedFileRowContract(
              id: rowId,
              displayPathLabel: _displayPathLabel(file),
              operationKind: operationKind,
              operationLabel: _operationLabel(operationKind),
              stats: ChatChangedFileStatsContract(
                additions: stats.additions,
                deletions: stats.deletions,
              ),
              actionLabel: patch == null ? 'No patch' : 'View diff',
              diff: patch == null
                  ? null
                  : ChatChangedFileDiffContract(
                      id: rowId,
                      displayPathLabel: _displayPathLabel(file),
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
    default:
      break;
  }

  return ChatChangedFileOperationKind.modified;
}

String _operationLabel(ChatChangedFileOperationKind kind) {
  return switch (kind) {
    ChatChangedFileOperationKind.created => 'Created',
    ChatChangedFileOperationKind.modified => 'Edited',
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
  final currentLines = <String>[];
  String? diffPath;
  String? newPath;
  String? oldPath;
  String? renameToPath;
  String? renameFromPath;
  var additions = 0;
  var deletions = 0;
  var isNewFile = false;
  var isDeletedFile = false;

  void resetState() {
    currentLines.clear();
    diffPath = null;
    newPath = null;
    oldPath = null;
    renameToPath = null;
    renameFromPath = null;
    additions = 0;
    deletions = 0;
    isNewFile = false;
    isDeletedFile = false;
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
        matchedPaths: matchedPaths,
        renameFromPath: renameFromPath,
        renameToPath: renameToPath,
        lines: currentLines
            .map((line) => _DiffLine(text: line, kind: _classifyDiffLine(line)))
            .toList(growable: false),
      ),
    );
  }

  resetState();

  for (final line in lines) {
    if (line.startsWith('diff --git ')) {
      commitPatch();
      resetState();
      final match = RegExp(r'^diff --git a/(.+?) b/(.+)$').firstMatch(line);
      diffPath = _normalizeDiffPath(match?.group(2));
    } else if (line.startsWith('--- ') &&
        currentLines.isNotEmpty &&
        (oldPath != null ||
            newPath != null ||
            additions > 0 ||
            deletions > 0)) {
      commitPatch();
      resetState();
    }

    currentLines.add(line);

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
    } else if (line.startsWith('--- ')) {
      oldPath = _normalizeDiffPath(line.substring(4).trim());
    } else if (line.startsWith('+++ ')) {
      newPath = _normalizeDiffPath(line.substring(4).trim());
    } else if (line.startsWith('+') && !line.startsWith('+++')) {
      additions += 1;
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      deletions += 1;
    }
  }

  commitPatch();
  return patches;
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

_DiffLineKind _classifyDiffLine(String line) {
  if (line.startsWith('@@')) {
    return _DiffLineKind.hunk;
  }

  if (line.startsWith('diff --git ') ||
      line.startsWith('index ') ||
      line.startsWith('--- ') ||
      line.startsWith('+++ ') ||
      line.startsWith('new file mode ') ||
      line.startsWith('deleted file mode ') ||
      line.startsWith('rename from ') ||
      line.startsWith('rename to ') ||
      line.startsWith('similarity index ')) {
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

enum _DiffLineKind { meta, hunk, addition, deletion, context }

class _DiffLine {
  const _DiffLine({required this.text, required this.kind});

  final String text;
  final _DiffLineKind kind;
}

class _ParsedDiffPatch {
  const _ParsedDiffPatch({
    required this.path,
    required this.lines,
    required this.additions,
    required this.deletions,
    required this.matchedPaths,
    this.renameFromPath,
    this.renameToPath,
    this.statusLabel,
  });

  final String path;
  final List<_DiffLine> lines;
  final int additions;
  final int deletions;
  final Set<String> matchedPaths;
  final String? renameFromPath;
  final String? renameToPath;
  final String? statusLabel;
}

String _displayPathLabel(CodexChangedFile file) {
  final movePath = file.movePath?.trim();
  if (movePath == null || movePath.isEmpty || movePath == file.path) {
    return file.path;
  }
  return '${file.path} -> $movePath';
}

class _DiffStats {
  const _DiffStats({this.additions = 0, this.deletions = 0});

  final int additions;
  final int deletions;
}
