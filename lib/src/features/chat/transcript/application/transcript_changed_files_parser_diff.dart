part of 'transcript_changed_files_parser.dart';

List<TranscriptChangedFile> _extractChangedFilesFromDiff(String diff) {
  final files = <String, _DiffStat>{};
  String? currentPath;

  for (final line in diff.split(RegExp(r'\r?\n'))) {
    if (line.startsWith('diff --git ')) {
      final match = RegExp(r'^diff --git a/(.+?) b/(.+)$').firstMatch(line);
      final path = _normalizeDiffPath(match?.group(2));
      if (path != null) {
        currentPath = path;
        files.putIfAbsent(path, () => const _DiffStat());
      }
      continue;
    }

    if (line.startsWith('+++ ')) {
      final path = _normalizeDiffPath(line.substring(4).trim());
      if (path != null) {
        currentPath = path;
        files.putIfAbsent(path, () => const _DiffStat());
      }
      continue;
    }

    if (line.startsWith('rename to ')) {
      final path = _normalizeDiffPath(line.substring('rename to '.length));
      if (path != null) {
        currentPath = path;
        files.putIfAbsent(path, () => const _DiffStat());
      }
      continue;
    }

    if (currentPath == null) {
      continue;
    }

    if (line.startsWith('+++') || line.startsWith('---')) {
      continue;
    }

    if (line.startsWith('+')) {
      final stat = files[currentPath] ?? const _DiffStat();
      files[currentPath] = stat.copyWith(additions: stat.additions + 1);
    } else if (line.startsWith('-')) {
      final stat = files[currentPath] ?? const _DiffStat();
      files[currentPath] = stat.copyWith(deletions: stat.deletions + 1);
    }
  }

  return files.entries
      .map(
        (entry) => TranscriptChangedFile(
          path: entry.key,
          additions: entry.value.additions,
          deletions: entry.value.deletions,
        ),
      )
      .toList(growable: false);
}

String? _firstDiffLikeString(List<Object?> candidates) {
  for (final candidate in candidates) {
    final value = _asNonEmptyString(candidate);
    if (value == null || !_looksLikeDiff(value)) {
      continue;
    }
    return value;
  }
  return null;
}

bool _looksLikeDiff(String value) {
  return value.contains('diff --git') ||
      value.contains('@@') ||
      (value.contains('--- ') && value.contains('+++ '));
}

String? _normalizeDiffPath(String? rawPath) {
  if (rawPath == null) {
    return null;
  }

  final trimmed = rawPath.trim();
  if (trimmed.isEmpty || trimmed == '/dev/null') {
    return null;
  }

  if (trimmed.startsWith('a/') || trimmed.startsWith('b/')) {
    return trimmed.substring(2);
  }
  return trimmed;
}
