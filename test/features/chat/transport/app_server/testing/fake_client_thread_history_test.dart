import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/testing/fake_codex_app_server_client.dart';

void main() {
  test('returns summary and history thread contracts', () async {
    final client = FakeCodexAppServerClient();

    final summary = await client.readThread(threadId: 'thread_widgetbook');
    final history = await client.readThreadWithTurns(
      threadId: 'thread_widgetbook',
    );

    expect(summary, isNotNull);
    expect(summary.id, 'thread_widgetbook');
    expect(history, isNotNull);
    expect(history.id, 'thread_widgetbook');
    expect(history.turns, isEmpty);
  });

  test('preserves turns when a configured thread is already a history object', () async {
    final client = FakeCodexAppServerClient();
    client.threadsById['thread_saved'] = const CodexAppServerThreadHistory(
      id: 'thread_saved',
      turns: <CodexAppServerHistoryTurn>[
        CodexAppServerHistoryTurn(id: 'turn_saved', raw: <String, Object?>{}),
      ],
    );

    final history = await client.readThreadWithTurns(threadId: 'thread_saved');

    expect(history.turns, hasLength(1));
    expect(history.turns.single.id, 'turn_saved');
  });

  test('converts generic history turns when restoring configured thread history', () async {
    final client = FakeCodexAppServerClient();
    client.threadsById['thread_generic'] = const AgentAdapterThreadHistory(
      id: 'thread_generic',
      turns: <AgentAdapterHistoryTurn>[
        AgentAdapterHistoryTurn(
          id: 'turn_generic',
          items: <AgentAdapterHistoryItem>[
            AgentAdapterHistoryItem(
              id: 'item_generic',
              type: 'agent_message',
              status: 'completed',
              raw: <String, dynamic>{'text': 'Generic restore'},
            ),
          ],
          raw: <String, dynamic>{'id': 'turn_generic'},
        ),
      ],
    );

    final history = await client.readThreadWithTurns(threadId: 'thread_generic');

    expect(history.turns, hasLength(1));
    expect(history.turns.single.id, 'turn_generic');
    expect(history.turns.single.items, hasLength(1));
    expect(history.turns.single.items.single.id, 'item_generic');
  });
}
