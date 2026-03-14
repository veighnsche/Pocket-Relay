import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptChangedFilesParser {
  const TranscriptChangedFilesParser({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
  }) : _support = support;

  final TranscriptPolicySupport _support;

  List<CodexChangedFile> changedFilesFromSources({
    Map<String, dynamic>? snapshot,
    String? body,
    Object? rawPayload,
  }) {
    final filesByPath = <String, CodexChangedFile>{};

    void addFiles(Iterable<CodexChangedFile> files) {
      for (final file in files) {
        final existing = filesByPath[file.path];
        if (existing == null) {
          filesByPath[file.path] = file;
          continue;
        }
        filesByPath[file.path] = CodexChangedFile(
          path: file.path,
          additions: file.additions > 0 ? file.additions : existing.additions,
          deletions: file.deletions > 0 ? file.deletions : existing.deletions,
        );
      }
    }

    addFiles(_extractChangedFilesFromObject(snapshot));
    if (rawPayload is Map<String, dynamic>) {
      addFiles(_extractChangedFilesFromObject(rawPayload));
    } else if (rawPayload is Map) {
      addFiles(
        _extractChangedFilesFromObject(Map<String, dynamic>.from(rawPayload)),
      );
    }

    final unifiedDiff = unifiedDiffFromSources(snapshot: snapshot, body: body);
    if (unifiedDiff != null && unifiedDiff.isNotEmpty) {
      addFiles(_extractChangedFilesFromDiff(unifiedDiff));
    }

    return filesByPath.values.toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));
  }

  String? unifiedDiffFromSources({
    Map<String, dynamic>? snapshot,
    String? body,
  }) {
    final diff = _support.stringFromCandidates(<Object?>[
      body,
      snapshot?['unifiedDiff'],
      snapshot?['diff'],
      snapshot?['patch'],
      snapshot?['text'],
      snapshot?['aggregatedOutput'],
      snapshot?['aggregated_output'],
    ]);
    if (diff == null) {
      return null;
    }
    return diff.contains('diff --git') || diff.contains('@@') ? diff : null;
  }

  List<CodexChangedFile> _extractChangedFilesFromObject(
    Map<String, dynamic>? value,
  ) {
    if (value == null) {
      return const <CodexChangedFile>[];
    }

    final paths = <String>{};

    void collect(Object? current, int depth) {
      if (current == null || depth > 4 || paths.length >= 20) {
        return;
      }

      if (current is List) {
        for (final entry in current) {
          collect(entry, depth + 1);
          if (paths.length >= 20) {
            return;
          }
        }
        return;
      }

      final map = switch (current) {
        final Map<String, dynamic> typedMap => typedMap,
        final Map rawMap => Map<String, dynamic>.from(rawMap),
        _ => null,
      };
      if (map == null) {
        return;
      }

      for (final key in <String>[
        'path',
        'filePath',
        'relativePath',
        'filename',
        'newPath',
        'oldPath',
      ]) {
        final candidate = map[key];
        if (candidate is String && candidate.trim().isNotEmpty) {
          paths.add(candidate.trim());
        }
      }

      for (final nestedKey in <String>[
        'item',
        'result',
        'input',
        'data',
        'changes',
        'files',
        'edits',
        'patch',
        'patches',
        'operations',
      ]) {
        if (map.containsKey(nestedKey)) {
          collect(map[nestedKey], depth + 1);
        }
      }
    }

    collect(value, 0);
    return paths
        .map((path) => CodexChangedFile(path: path))
        .toList(growable: false);
  }

  List<CodexChangedFile> _extractChangedFilesFromDiff(String diff) {
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
          (entry) => CodexChangedFile(
            path: entry.key,
            additions: entry.value.additions,
            deletions: entry.value.deletions,
          ),
        )
        .toList(growable: false);
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
}

class _DiffStat {
  const _DiffStat({this.additions = 0, this.deletions = 0});

  final int additions;
  final int deletions;

  _DiffStat copyWith({int? additions, int? deletions}) {
    return _DiffStat(
      additions: additions ?? this.additions,
      deletions: deletions ?? this.deletions,
    );
  }
}
