import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/transcript_memory_budget.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';

void main() {
  const budget = TranscriptMemoryBudget();

  test('sanitizes work-log snapshots down to relevant bounded fields', () {
    final snapshot = budget.retainWorkLogSnapshot(
      CodexCanonicalItemType.mcpToolCall,
      <String, dynamic>{
        'server': 'filesystem',
        'tool': 'write_file',
        'arguments': <String, Object?>{
          'path': 'README.md',
          'content': 'x' * 3000,
        },
        'result': <String, Object?>{
          'content': <Object?>[
            <String, Object?>{'text': 'ok'},
            <String, Object?>{'text': 'ignored'},
          ],
        },
        'aggregatedOutput': 'y' * 5000,
      },
    );

    expect(snapshot?['server'], 'filesystem');
    expect(snapshot?['tool'], 'write_file');
    expect(
      (snapshot?['arguments'] as Map<String, dynamic>)['path'],
      'README.md',
    );
    expect(
      (snapshot?['arguments'] as Map<String, dynamic>)['content'],
      endsWith('[truncated]'),
    );
    expect(snapshot?.containsKey('aggregatedOutput'), isFalse);
  });

  test('caps retained unified diff size', () {
    final diff = List<String>.generate(
      1500,
      (index) => '+line $index ${'x' * 80}',
    ).join('\n');

    final retained = budget.retainUnifiedDiff(diff);

    expect(retained, isNotNull);
    expect('\n'.allMatches(retained!).length + 1, lessThanOrEqualTo(1200));
    expect(retained.length, lessThanOrEqualTo(120000));
  });
}
