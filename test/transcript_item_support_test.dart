import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_item_support.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';

void main() {
  const support = TranscriptItemSupport();

  test('maps content stream kinds to canonical item types', () {
    expect(
      support.itemTypeFromStreamKind(
        CodexRuntimeContentStreamKind.assistantText,
      ),
      CodexCanonicalItemType.assistantMessage,
    );
    expect(
      support.itemTypeFromStreamKind(
        CodexRuntimeContentStreamKind.reasoningSummaryText,
      ),
      CodexCanonicalItemType.reasoning,
    );
    expect(
      support.itemTypeFromStreamKind(
        CodexRuntimeContentStreamKind.fileChangeOutput,
      ),
      CodexCanonicalItemType.fileChange,
    );
  });

  test('extracts item text from nested snapshot fields', () {
    expect(
      support.extractTextFromSnapshot(const <String, Object?>{
        'result': <String, Object?>{'output': 'nested output'},
      }),
      'nested output',
    );
    expect(
      support.extractTextFromSnapshot(const <String, Object?>{
        'aggregated_output': 'flat output',
      }),
      'flat output',
    );
  });

  test('provides default lifecycle body text only for status-like items', () {
    expect(
      support.defaultLifecycleBody(CodexCanonicalItemType.reviewEntered),
      'Codex entered review mode.',
    );
    expect(
      support.defaultLifecycleBody(CodexCanonicalItemType.contextCompaction),
      'Codex compacted the current thread context.',
    );
    expect(
      support.defaultLifecycleBody(CodexCanonicalItemType.assistantMessage),
      isNull,
    );
  });
}
