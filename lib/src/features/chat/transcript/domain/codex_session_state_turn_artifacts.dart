part of 'codex_session_state.dart';

Iterable<String> codexUiBlockIds(Iterable<CodexUiBlock> blocks) sync* {
  for (final block in blocks) {
    yield block.id;
    if (block case CodexWorkLogGroupBlock(:final entries)) {
      for (final entry in entries) {
        yield entry.id;
      }
    }
  }
}

Iterable<String> codexTurnArtifactIds(
  Iterable<CodexTurnArtifact> artifacts,
) sync* {
  for (final artifact in artifacts) {
    yield artifact.id;
    if (artifact case CodexTurnWorkArtifact(:final entries)) {
      for (final entry in entries) {
        yield entry.id;
      }
    }
  }
}

sealed class CodexTurnArtifact {
  const CodexTurnArtifact({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;
}

final class CodexTurnTextArtifact extends CodexTurnArtifact {
  const CodexTurnTextArtifact({
    required super.id,
    required super.createdAt,
    required this.kind,
    required this.title,
    required this.body,
    this.itemId,
    this.isStreaming = false,
  });

  final CodexUiBlockKind kind;
  final String title;
  final String body;
  final String? itemId;
  final bool isStreaming;
}

final class CodexTurnWorkArtifact extends CodexTurnArtifact {
  const CodexTurnWorkArtifact({
    required super.id,
    required super.createdAt,
    this.entries = const <CodexWorkLogEntry>[],
  });

  final List<CodexWorkLogEntry> entries;
}

final class CodexTurnPlanArtifact extends CodexTurnArtifact {
  const CodexTurnPlanArtifact({
    required super.id,
    required super.createdAt,
    required this.title,
    required this.markdown,
    this.itemId,
    this.isStreaming = false,
  });

  final String title;
  final String markdown;
  final String? itemId;
  final bool isStreaming;
}

final class CodexTurnChangedFilesArtifact extends CodexTurnArtifact {
  const CodexTurnChangedFilesArtifact({
    required super.id,
    required super.createdAt,
    required this.title,
    String? itemId,
    List<CodexChangedFile>? files,
    String? unifiedDiff,
    this.entries = const <CodexChangedFilesEntry>[],
    this.isStreaming = false,
  }) : _itemId = itemId,
       _files = files,
       _unifiedDiff = unifiedDiff;

  final String title;
  final String? _itemId;
  final List<CodexChangedFile>? _files;
  final String? _unifiedDiff;
  final List<CodexChangedFilesEntry> entries;
  final bool isStreaming;

  String? get itemId => _itemId ?? entries.lastOrNull?.itemId;

  List<CodexChangedFile> get files {
    final explicitFiles = _files;
    if (explicitFiles != null) {
      return explicitFiles;
    }

    return _mergedChangedFiles(entries);
  }

  String? get unifiedDiff {
    final explicitUnifiedDiff = _unifiedDiff;
    if (explicitUnifiedDiff != null) {
      return explicitUnifiedDiff;
    }

    return _mergedUnifiedDiff(entries);
  }
}

final class CodexChangedFilesEntry {
  const CodexChangedFilesEntry({
    required this.id,
    required this.itemId,
    required this.createdAt,
    this.files = const <CodexChangedFile>[],
    this.unifiedDiff,
    this.isRunning = false,
  });

  final String id;
  final String itemId;
  final DateTime createdAt;
  final List<CodexChangedFile> files;
  final String? unifiedDiff;
  final bool isRunning;

  CodexChangedFilesEntry copyWith({
    List<CodexChangedFile>? files,
    String? unifiedDiff,
    bool? isRunning,
  }) {
    return CodexChangedFilesEntry(
      id: id,
      itemId: itemId,
      createdAt: createdAt,
      files: files ?? this.files,
      unifiedDiff: unifiedDiff ?? this.unifiedDiff,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

List<CodexChangedFile> _mergedChangedFiles(
  Iterable<CodexChangedFilesEntry> entries,
) {
  final mergedByPath = <String, CodexChangedFile>{};

  for (final entry in entries) {
    for (final file in entry.files) {
      mergedByPath[file.path] = file;
    }
  }

  return mergedByPath.values.toList(growable: false);
}

String? _mergedUnifiedDiff(Iterable<CodexChangedFilesEntry> entries) {
  final parts = entries
      .map((entry) => entry.unifiedDiff?.trim())
      .whereType<String>()
      .where((diff) => diff.isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) {
    return null;
  }

  return parts.join('\n');
}

final class CodexTurnBlockArtifact extends CodexTurnArtifact {
  CodexTurnBlockArtifact({required this.block})
    : super(id: block.id, createdAt: block.createdAt);

  final CodexUiBlock block;
}

final class CodexTurnDiffSnapshot {
  const CodexTurnDiffSnapshot({
    required this.turnId,
    required this.createdAt,
    required this.unifiedDiff,
  });

  final String turnId;
  final DateTime createdAt;
  final String unifiedDiff;

  CodexTurnDiffSnapshot copyWith({DateTime? createdAt, String? unifiedDiff}) {
    return CodexTurnDiffSnapshot(
      turnId: turnId,
      createdAt: createdAt ?? this.createdAt,
      unifiedDiff: unifiedDiff ?? this.unifiedDiff,
    );
  }
}
