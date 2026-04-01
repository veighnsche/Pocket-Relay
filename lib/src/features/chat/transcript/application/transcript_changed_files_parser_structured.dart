part of 'transcript_changed_files_parser.dart';

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

List<_StructuredChangedFile> _parseStructuredChangeList(List<Object?> changes) {
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
        file: TranscriptChangedFile(
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
          diffBody.contains('rename from ') || diffBody.contains('rename to ');
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
