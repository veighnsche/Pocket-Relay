import 'dart:convert';

import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

class TranscriptChangedFilesParser {
  const TranscriptChangedFilesParser();

  List<CodexChangedFile> changedFilesFromSources({
    Map<String, dynamic>? snapshot,
    String? body,
    Object? rawPayload,
  }) {
    final filesByPath = <String, CodexChangedFile>{};
    var hasStructuredChanges = false;

    void addFiles(Iterable<CodexChangedFile> files) {
      for (final file in files) {
        final existing = filesByPath[file.path];
        if (existing == null) {
          filesByPath[file.path] = file;
          continue;
        }
        filesByPath[file.path] = existing.copyWith(
          movePath: file.movePath ?? existing.movePath,
          additions: file.additions > 0 ? file.additions : existing.additions,
          deletions: file.deletions > 0 ? file.deletions : existing.deletions,
        );
      }
    }

    final structuredSnapshotChanges = _extractStructuredChangedFiles(snapshot);
    if (structuredSnapshotChanges.isNotEmpty) {
      hasStructuredChanges = true;
      addFiles(
        structuredSnapshotChanges
            .map((change) => change.file)
            .toList(growable: false),
      );
    }
    if (rawPayload is Map<String, dynamic>) {
      final structuredPayloadChanges = _extractStructuredChangedFiles(
        rawPayload,
      );
      if (structuredPayloadChanges.isNotEmpty) {
        hasStructuredChanges = true;
        addFiles(
          structuredPayloadChanges
              .map((change) => change.file)
              .toList(growable: false),
        );
      }
    } else if (rawPayload is Map) {
      final structuredPayloadChanges = _extractStructuredChangedFiles(
        Map<String, dynamic>.from(rawPayload),
      );
      if (structuredPayloadChanges.isNotEmpty) {
        hasStructuredChanges = true;
        addFiles(
          structuredPayloadChanges
              .map((change) => change.file)
              .toList(growable: false),
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
    if (!hasStructuredChanges &&
        unifiedDiff != null &&
        unifiedDiff.isNotEmpty) {
      addFiles(_extractChangedFilesFromDiff(unifiedDiff));
    }

    return filesByPath.values.toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));
  }

  String? unifiedDiffFromSources({
    Map<String, dynamic>? snapshot,
    String? body,
  }) {
    final diff = _firstDiffLikeString(<Object?>[
      body,
      snapshot?['unifiedDiff'],
      snapshot?['diff'],
      snapshot?['patch'],
      snapshot?['text'],
      snapshot?['aggregatedOutput'],
      snapshot?['aggregated_output'],
    ]);
    if (diff != null && diff.isNotEmpty) {
      return diff;
    }

    final structuredDiff = _synthesizedStructuredUnifiedDiff(snapshot);
    if (structuredDiff == null || structuredDiff.isEmpty) {
      return null;
    }
    return structuredDiff;
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

  List<_StructuredChangedFile> _extractStructuredChangedFiles(
    Map<String, dynamic>? value,
  ) {
    if (value == null) {
      return const <_StructuredChangedFile>[];
    }

    final changes = <_StructuredChangedFile>[];
    final seenSignatures = <String>{};

    void addStructured(Iterable<_StructuredChangedFile> entries) {
      for (final entry in entries) {
        if (seenSignatures.add(entry.signature)) {
          changes.add(entry);
        }
      }
    }

    void collect(Object? current, int depth) {
      if (current == null || depth > 4 || changes.length >= 20) {
        return;
      }

      if (current is List) {
        for (final entry in current) {
          collect(entry, depth + 1);
          if (changes.length >= 20) {
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

      final structuredEntries = _parseStructuredChangeList(
        _asList(map['changes']),
      );
      if (structuredEntries.isNotEmpty) {
        addStructured(structuredEntries);
      }

      for (final nestedKey in <String>[
        'item',
        'result',
        'input',
        'data',
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
    return changes;
  }

  List<_StructuredChangedFile> _parseStructuredChangeList(
    List<Object?> changes,
  ) {
    final parsed = <_StructuredChangedFile>[];
    for (final entry in changes) {
      final map = switch (entry) {
        final Map<String, dynamic> typedMap => typedMap,
        final Map rawMap => Map<String, dynamic>.from(rawMap),
        _ => null,
      };
      if (map == null) {
        continue;
      }

      final path = _asNonEmptyString(map['path']);
      final diff =
          _asNonEmptyString(map['diff']) ??
          _asNonEmptyString(map['patch']) ??
          _asNonEmptyString(map['text']) ??
          '';
      final kind = _structuredKind(map['kind']);
      if (path == null || kind == null) {
        continue;
      }

      final movePath = _structuredMovePath(map['kind']);
      final patch = _synthesizeStructuredPatch(
        path: path,
        kind: kind,
        diff: diff,
        movePath: movePath,
      );
      final stats = _statsForStructuredChange(
        path: path,
        kind: kind,
        diff: diff,
        movePath: movePath,
      );
      parsed.add(
        _StructuredChangedFile(
          file: CodexChangedFile(
            path: path,
            movePath: movePath,
            additions: stats.additions,
            deletions: stats.deletions,
          ),
          patch: patch,
        ),
      );
    }
    return parsed;
  }

  String? _synthesizedStructuredUnifiedDiff(Map<String, dynamic>? value) {
    final structuredChanges = _extractStructuredChangedFiles(value);
    if (structuredChanges.isEmpty) {
      return null;
    }

    return structuredChanges
        .map((change) => change.patch.trim())
        .where((patch) => patch.isNotEmpty)
        .join('\n');
  }

  _DiffStat _statsForStructuredChange({
    required String path,
    required _StructuredChangeKind kind,
    required String diff,
    required String? movePath,
  }) {
    switch (kind) {
      case _StructuredChangeKind.add:
        return _DiffStat(additions: _contentLineCount(diff));
      case _StructuredChangeKind.delete:
        return _DiffStat(deletions: _contentLineCount(diff));
      case _StructuredChangeKind.update:
        final diffFiles = _extractChangedFilesFromDiff(diff);
        if (diffFiles.isNotEmpty) {
          final candidatePaths = <String>{
            _normalizeDiffPath(path) ?? path,
            if (movePath != null && movePath.isNotEmpty)
              _normalizeDiffPath(movePath) ?? movePath,
          };
          final matches = diffFiles
              .where((file) => candidatePaths.contains(file.path))
              .toList(growable: false);
          final source = matches.isNotEmpty ? matches : diffFiles;
          return source.fold(
            const _DiffStat(),
            (sum, file) => _DiffStat(
              additions: sum.additions + file.additions,
              deletions: sum.deletions + file.deletions,
            ),
          );
        }
        return _signedLineCount(diff);
    }
  }

  String _synthesizeStructuredPatch({
    required String path,
    required _StructuredChangeKind kind,
    required String diff,
    required String? movePath,
  }) {
    final normalizedPath = path.trim();
    final normalizedMovePath = movePath?.trim();
    switch (kind) {
      case _StructuredChangeKind.add:
        final lines = _contentLines(diff);
        return <String>[
          'diff --git a/$normalizedPath b/$normalizedPath',
          'new file mode 100644',
          '--- /dev/null',
          '+++ b/$normalizedPath',
          '@@ -0,0 +1,${lines.length} @@',
          ...lines.map((line) => '+$line'),
        ].join('\n');
      case _StructuredChangeKind.delete:
        final lines = _contentLines(diff);
        return <String>[
          'diff --git a/$normalizedPath b/$normalizedPath',
          'deleted file mode 100644',
          '--- a/$normalizedPath',
          '+++ /dev/null',
          '@@ -1,${lines.length} +0,0 @@',
          ...lines.map((line) => '-$line'),
        ].join('\n');
      case _StructuredChangeKind.update:
        final destinationPath = normalizedMovePath ?? normalizedPath;
        final diffBody = diff.trim();
        final hasDiffHeader = diffBody.contains('diff --git ');
        final hasPathHeaders =
            diffBody.contains('--- ') || diffBody.contains('+++ ');
        final hasRenameHeaders =
            diffBody.contains('rename from ') ||
            diffBody.contains('rename to ');
        return <String>[
          if (!hasDiffHeader) 'diff --git a/$normalizedPath b/$destinationPath',
          if (normalizedMovePath != null &&
              normalizedMovePath.isNotEmpty &&
              !hasRenameHeaders) ...<String>[
            'rename from $normalizedPath',
            'rename to $destinationPath',
          ],
          if (!hasPathHeaders) ...<String>[
            '--- a/$normalizedPath',
            '+++ b/$destinationPath',
          ],
          if (diffBody.isNotEmpty) diffBody,
        ].join('\n');
    }
  }

  List<String> _contentLines(String content) {
    return const LineSplitter().convert(content);
  }

  int _contentLineCount(String content) {
    return _contentLines(content).length;
  }

  _DiffStat _signedLineCount(String diff) {
    var additions = 0;
    var deletions = 0;
    for (final line in diff.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('+') && !line.startsWith('+++')) {
        additions += 1;
      } else if (line.startsWith('-') && !line.startsWith('---')) {
        deletions += 1;
      }
    }
    return _DiffStat(additions: additions, deletions: deletions);
  }

  List<Object?> _asList(Object? value) {
    if (value is List<Object?>) {
      return value;
    }
    if (value is List) {
      return value.cast<Object?>();
    }
    return const <Object?>[];
  }

  String? _asNonEmptyString(Object? value) {
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
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

  _StructuredChangeKind? _structuredKind(Object? value) {
    final map = switch (value) {
      final Map<String, dynamic> typedMap => typedMap,
      final Map rawMap => Map<String, dynamic>.from(rawMap),
      _ => null,
    };
    final type = switch (value) {
      final String kindString => kindString,
      _ => _asNonEmptyString(map?['type']),
    };
    return switch (type) {
      'add' => _StructuredChangeKind.add,
      'delete' => _StructuredChangeKind.delete,
      'update' => _StructuredChangeKind.update,
      _ => null,
    };
  }

  String? _structuredMovePath(Object? value) {
    final map = switch (value) {
      final Map<String, dynamic> typedMap => typedMap,
      final Map rawMap => Map<String, dynamic>.from(rawMap),
      _ => null,
    };
    return _asNonEmptyString(map?['move_path']) ??
        _asNonEmptyString(map?['movePath']);
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

enum _StructuredChangeKind { add, delete, update }

class _StructuredChangedFile {
  const _StructuredChangedFile({required this.file, required this.patch});

  final CodexChangedFile file;
  final String patch;

  String get signature => '${file.path}\n$patch';
}
