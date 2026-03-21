import 'dart:convert';

import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';

part 'transcript_changed_files_parser_diff.dart';
part 'transcript_changed_files_parser_fallback.dart';
part 'transcript_changed_files_parser_structured.dart';

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
