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
      snapshot['summary'],
      snapshot['review'],
      snapshot['revisedPrompt'],
      snapshot['patch'],
      snapshot['result'],
      nestedResult?['output'],
      nestedResult?['text'],
      nestedResult?['path'],
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
}
