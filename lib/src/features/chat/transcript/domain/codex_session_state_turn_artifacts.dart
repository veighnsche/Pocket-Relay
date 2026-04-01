part of 'transcript_session_state.dart';

Iterable<String> transcriptUiBlockIds(
  Iterable<TranscriptUiBlock> blocks,
) sync* {
  for (final block in blocks) {
    yield block.id;
    if (block case TranscriptWorkLogGroupBlock(:final entries)) {
      for (final entry in entries) {
        yield entry.id;
      }
    }
  }
}

Iterable<String> transcriptTurnArtifactIds(
  Iterable<TranscriptTurnArtifact> artifacts,
) sync* {
  for (final artifact in artifacts) {
    yield artifact.id;
    if (artifact case TranscriptTurnWorkArtifact(:final entries)) {
      for (final entry in entries) {
        yield entry.id;
      }
    }
    if (artifact case TranscriptTurnChangedFilesArtifact(:final entries)) {
      for (final entry in entries) {
        yield entry.id;
      }
    }
  }
}

sealed class TranscriptTurnArtifact {
  const TranscriptTurnArtifact({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;
}

final class TranscriptTurnTextArtifact extends TranscriptTurnArtifact {
  const TranscriptTurnTextArtifact({
    required super.id,
    required super.createdAt,
    required this.kind,
    required this.title,
    required this.body,
    this.itemId,
    this.isStreaming = false,
  });

  final TranscriptUiBlockKind kind;
  final String title;
  final String body;
  final String? itemId;
  final bool isStreaming;
}

final class TranscriptTurnWorkArtifact extends TranscriptTurnArtifact {
  const TranscriptTurnWorkArtifact({
    required super.id,
    required super.createdAt,
    this.entries = const <TranscriptWorkLogEntry>[],
  });

  final List<TranscriptWorkLogEntry> entries;
}

final class TranscriptTurnPlanArtifact extends TranscriptTurnArtifact {
  const TranscriptTurnPlanArtifact({
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

final class TranscriptTurnChangedFilesArtifact extends TranscriptTurnArtifact {
  const TranscriptTurnChangedFilesArtifact({
    required super.id,
    required super.createdAt,
    required this.title,
    String? itemId,
    List<TranscriptChangedFile>? files,
    String? unifiedDiff,
    this.entries = const <TranscriptChangedFilesEntry>[],
    this.isStreaming = false,
  }) : _itemId = itemId,
       _files = files,
       _unifiedDiff = unifiedDiff;

  final String title;
  final String? _itemId;
  final List<TranscriptChangedFile>? _files;
  final String? _unifiedDiff;
  final List<TranscriptChangedFilesEntry> entries;
  final bool isStreaming;

  String? get itemId => _itemId ?? entries.lastOrNull?.itemId;

  List<TranscriptChangedFile> get files {
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

final class TranscriptChangedFilesEntry {
  const TranscriptChangedFilesEntry({
    required this.id,
    required this.itemId,
    required this.createdAt,
    this.files = const <TranscriptChangedFile>[],
    this.unifiedDiff,
    this.isRunning = false,
  });

  final String id;
  final String itemId;
  final DateTime createdAt;
  final List<TranscriptChangedFile> files;
  final String? unifiedDiff;
  final bool isRunning;

  TranscriptChangedFilesEntry copyWith({
    List<TranscriptChangedFile>? files,
    String? unifiedDiff,
    bool? isRunning,
  }) {
    return TranscriptChangedFilesEntry(
      id: id,
      itemId: itemId,
      createdAt: createdAt,
      files: files ?? this.files,
      unifiedDiff: unifiedDiff ?? this.unifiedDiff,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

List<TranscriptChangedFile> _mergedChangedFiles(
  Iterable<TranscriptChangedFilesEntry> entries,
) {
  final mergedByPath = <String, TranscriptChangedFile>{};

  for (final entry in entries) {
    for (final file in entry.files) {
      mergedByPath[file.path] = file;
    }
  }

  return mergedByPath.values.toList(growable: false);
}

String? _mergedUnifiedDiff(Iterable<TranscriptChangedFilesEntry> entries) {
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

final class TranscriptTurnBlockArtifact extends TranscriptTurnArtifact {
  TranscriptTurnBlockArtifact({required this.block})
    : super(id: block.id, createdAt: block.createdAt);

  final TranscriptUiBlock block;
}

final class TranscriptTurnDiffSnapshot {
  const TranscriptTurnDiffSnapshot({
    required this.turnId,
    required this.createdAt,
    required this.unifiedDiff,
  });

  final String turnId;
  final DateTime createdAt;
  final String unifiedDiff;

  TranscriptTurnDiffSnapshot copyWith({
    DateTime? createdAt,
    String? unifiedDiff,
  }) {
    return TranscriptTurnDiffSnapshot(
      turnId: turnId,
      createdAt: createdAt ?? this.createdAt,
      unifiedDiff: unifiedDiff ?? this.unifiedDiff,
    );
  }
}
