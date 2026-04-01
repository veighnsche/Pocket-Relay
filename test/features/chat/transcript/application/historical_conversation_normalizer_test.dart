import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/application/codex_historical_conversation_normalizer.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_thread_read_decoder.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';

void main() {
  const decoder = CodexAppServerThreadReadDecoder();
  const normalizer = CodexHistoricalConversationNormalizer();

  test('normalizes thread/read history into canonical conversation snapshot', () {
    final thread = decoder.decodeHistoryResponse(
      _loadFixture(
        'test/features/chat/transport/app_server/fixtures/thread_read/reference_nested_history.json',
      ),
      fallbackThreadId: 'thread_nested',
    );

    final conversation = normalizer.normalize(thread);

    expect(conversation.threadId, 'thread_nested');
    expect(conversation.threadName, 'Saved thread');
    expect(conversation.sourceKind, 'app-server');
    expect(conversation.agentNickname, 'builder');
    expect(conversation.agentRole, 'worker');
    expect(conversation.turns, hasLength(1));

    final turn = conversation.turns.single;
    expect(turn.id, 'turn_saved');
    expect(turn.threadId, 'thread_nested');
    expect(turn.state, TranscriptRuntimeTurnState.completed);
    expect(turn.entries, hasLength(2));

    final userEntry = turn.entries.first;
    expect(userEntry.itemType, TranscriptCanonicalItemType.userMessage);
    expect(userEntry.title, 'You');
    expect(userEntry.detail, 'Restore this');

    final assistantEntry = turn.entries.last;
    expect(
      assistantEntry.itemType,
      TranscriptCanonicalItemType.assistantMessage,
    );
    expect(assistantEntry.title, 'Codex');
    expect(assistantEntry.detail, 'Restored answer');
  });

  test(
    'normalizes captured live thread/read history into canonical conversation snapshot',
    () {
      final thread = decoder.decodeHistoryResponse(
        _loadFixture(
          'test/features/chat/transport/app_server/fixtures/thread_read/live_capture_001.json',
        ),
        fallbackThreadId: 'thread_live',
      );

      final conversation = normalizer.normalize(thread);

      expect(conversation.threadId, '<thread_1>');
      expect(conversation.turns, hasLength(1));

      final turn = conversation.turns.single;
      expect(turn.id, '<turn_1>');
      expect(turn.entries, hasLength(10));

      final userEntry = turn.entries.first;
      expect(userEntry.itemType, TranscriptCanonicalItemType.userMessage);
      expect(userEntry.detail, '<text_1>');

      final assistantEntries = turn.entries
          .where(
            (entry) =>
                entry.itemType == TranscriptCanonicalItemType.assistantMessage,
          )
          .toList(growable: false);
      expect(assistantEntries, hasLength(9));
      expect(assistantEntries.first.detail, '<text_2>');
      expect(assistantEntries.last.detail, '<text_10>');
    },
  );
}

Map<String, dynamic> _loadFixture(String path) {
  final text = File(path).readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}
