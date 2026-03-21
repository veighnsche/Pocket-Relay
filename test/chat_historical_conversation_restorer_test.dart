import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/application/chat_historical_conversation_restorer.dart';
import 'package:pocket_relay/src/features/chat/application/codex_historical_conversation.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

void main() {
  const restorer = ChatHistoricalConversationRestorer();

  test('restores a normalized conversation into transcript state', () {
    final conversation = CodexHistoricalConversation(
      threadId: 'thread_saved',
      createdAt: DateTime(2026, 3, 20, 10),
      threadName: 'Saved conversation',
      sourceKind: 'app-server',
      turns: <CodexHistoricalTurn>[
        CodexHistoricalTurn(
          id: 'turn_saved',
          threadId: 'thread_saved',
          createdAt: DateTime(2026, 3, 20, 10, 1),
          completedAt: DateTime(2026, 3, 20, 10, 2),
          state: CodexRuntimeTurnState.completed,
          model: 'gpt-5.4',
          effort: 'high',
          entries: <CodexHistoricalEntry>[
            CodexHistoricalEntry(
              id: 'item_user',
              threadId: 'thread_saved',
              turnId: 'turn_saved',
              createdAt: DateTime(2026, 3, 20, 10, 1),
              itemType: CodexCanonicalItemType.userMessage,
              status: CodexRuntimeItemStatus.completed,
              title: 'You',
              detail: 'Restore this',
              snapshot: const <String, dynamic>{
                'type': 'user_message',
                'content': <Object>[
                  <String, Object?>{'text': 'Restore this'},
                ],
              },
            ),
            CodexHistoricalEntry(
              id: 'item_assistant',
              threadId: 'thread_saved',
              turnId: 'turn_saved',
              createdAt: DateTime(2026, 3, 20, 10, 2),
              itemType: CodexCanonicalItemType.assistantMessage,
              status: CodexRuntimeItemStatus.completed,
              title: 'Codex',
              detail: 'Restored answer',
              snapshot: const <String, dynamic>{
                'type': 'agent_message',
                'content': <Object>[
                  <String, Object?>{'text': 'Restored answer'},
                ],
              },
            ),
          ],
        ),
      ],
    );

    final restoredState = restorer.restore(conversation);

    expect(restoredState.rootThreadId, 'thread_saved');
    expect(restoredState.selectedThreadId, 'thread_saved');
    expect(restoredState.headerMetadata.model, 'gpt-5.4');
    expect(restoredState.headerMetadata.reasoningEffort, 'high');
    expect(
      restoredState.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .single
          .text,
      'Restore this',
    );
    expect(
      restoredState.transcriptBlocks.whereType<CodexTextBlock>().single.body,
      'Restored answer',
    );
  });
}
