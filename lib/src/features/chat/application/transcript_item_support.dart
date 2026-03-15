import 'package:pocket_relay/src/features/chat/application/transcript_policy_support.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';

class TranscriptItemSupport {
  const TranscriptItemSupport({
    TranscriptPolicySupport support = const TranscriptPolicySupport(),
  }) : _support = support;

  final TranscriptPolicySupport _support;

  CodexCanonicalItemType itemTypeFromStreamKind(
    CodexRuntimeContentStreamKind streamKind,
  ) {
    return switch (streamKind) {
      CodexRuntimeContentStreamKind.assistantText =>
        CodexCanonicalItemType.assistantMessage,
      CodexRuntimeContentStreamKind.reasoningText ||
      CodexRuntimeContentStreamKind.reasoningSummaryText =>
        CodexCanonicalItemType.reasoning,
      CodexRuntimeContentStreamKind.planText => CodexCanonicalItemType.plan,
      CodexRuntimeContentStreamKind.commandOutput =>
        CodexCanonicalItemType.commandExecution,
      CodexRuntimeContentStreamKind.fileChangeOutput =>
        CodexCanonicalItemType.fileChange,
      _ => CodexCanonicalItemType.unknown,
    };
  }

  String? extractTextFromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null) {
      return null;
    }

    final result = snapshot['result'];
    final nestedResult = result is Map<String, dynamic> ? result : null;
    return _support.stringFromCandidates(<Object?>[
      snapshot['aggregatedOutput'],
      snapshot['aggregated_output'],
      snapshot['text'],
      _textFromStructuredEntries(snapshot['summary']),
      _textFromStructuredEntries(snapshot['content']),
      snapshot['summary'],
      snapshot['review'],
      snapshot['revisedPrompt'],
      snapshot['patch'],
      snapshot['result'],
      nestedResult?['output'],
      nestedResult?['text'],
      nestedResult?['path'],
      _textFromStructuredEntries(nestedResult?['content']),
    ]);
  }

  String? defaultLifecycleBody(CodexCanonicalItemType itemType) {
    return switch (itemType) {
      CodexCanonicalItemType.reviewEntered => 'Codex entered review mode.',
      CodexCanonicalItemType.reviewExited => 'Codex exited review mode.',
      CodexCanonicalItemType.contextCompaction =>
        'Codex compacted the current thread context.',
      _ => null,
    };
  }

  String? _textFromStructuredEntries(Object? value) {
    if (value is! List) {
      return null;
    }

    final textParts = <String>[];
    for (final entry in value) {
      if (entry is String && entry.isNotEmpty) {
        textParts.add(entry);
        continue;
      }

      if (entry is! Map) {
        continue;
      }

      final object = Map<String, dynamic>.from(entry);
      final text = _support.stringFromCandidates(<Object?>[
        object['text'],
        (object['content'] as Map?)?['text'],
      ]);
      if (text != null && text.isNotEmpty) {
        textParts.add(text);
      }
    }

    if (textParts.isEmpty) {
      return null;
    }
    return textParts.join('\n');
  }
}
