import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_item_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';

void main() {
  const support = TranscriptItemSupport();

  test('maps content stream kinds to canonical item types', () {
    expect(
      support.itemTypeFromStreamKind(
        TranscriptRuntimeContentStreamKind.assistantText,
      ),
      TranscriptCanonicalItemType.assistantMessage,
    );
    expect(
      support.itemTypeFromStreamKind(
        TranscriptRuntimeContentStreamKind.reasoningSummaryText,
      ),
      TranscriptCanonicalItemType.reasoning,
    );
    expect(
      support.itemTypeFromStreamKind(
        TranscriptRuntimeContentStreamKind.fileChangeOutput,
      ),
      TranscriptCanonicalItemType.fileChange,
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
    expect(
      support.extractTextFromSnapshot(const <String, Object?>{
        'summary': <Object?>[
          <String, Object?>{'type': 'summary_text', 'text': 'step one'},
          <String, Object?>{'type': 'summary_text', 'text': 'step two'},
        ],
      }),
      'step one\nstep two',
    );
    expect(
      support.extractTextFromSnapshot(const <String, Object?>{
        'content': <Object?>[
          <String, Object?>{'type': 'reasoning_text', 'text': 'raw trace'},
        ],
      }),
      'raw trace',
    );
  });

  test('provides default lifecycle body text only for status-like items', () {
    expect(
      support.defaultLifecycleBody(TranscriptCanonicalItemType.reviewEntered),
      'Codex entered review mode.',
    );
    expect(
      support.defaultLifecycleBody(
        TranscriptCanonicalItemType.contextCompaction,
      ),
      'Codex compacted the current thread context.',
    );
    expect(
      support.defaultLifecycleBody(
        TranscriptCanonicalItemType.assistantMessage,
      ),
      isNull,
    );
  });
}
