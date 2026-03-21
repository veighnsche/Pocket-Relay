part of 'transcript_changed_files_parser.dart';

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
