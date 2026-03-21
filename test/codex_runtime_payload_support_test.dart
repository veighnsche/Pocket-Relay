import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/codex_runtime_payload_support.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';

void main() {
  const support = CodexRuntimePayloadSupport();

  test('canonicalizes item types across upstream naming variants', () {
    expect(
      support.canonicalItemType('agentMessage'),
      CodexCanonicalItemType.assistantMessage,
    );
    expect(
      support.canonicalItemType('file_change'),
      CodexCanonicalItemType.fileChange,
    );
    expect(
      support.canonicalItemType('enteredReviewMode'),
      CodexCanonicalItemType.reviewEntered,
    );
    expect(
      support.canonicalItemType('collab_tool_call'),
      CodexCanonicalItemType.collabAgentToolCall,
    );
  });

  test('extracts item detail from item snapshots and payload fallbacks', () {
    expect(
      support.itemDetail(const <String, dynamic>{
        'content': <Object?>[
          <String, Object?>{'type': 'output_text', 'text': 'first line'},
          <String, Object?>{'type': 'output_text', 'text': 'second line'},
        ],
      }),
      'first line\nsecond line',
    );
    expect(
      support.itemDetail(const <String, dynamic>{
        'result': <String, Object?>{'text': 'nested'},
      }),
      'nested',
    );
    expect(
      support.itemDetail(
        const <String, dynamic>{'status': 'completed'},
        payload: const <String, dynamic>{'message': 'payload fallback'},
      ),
      'payload fallback',
    );
  });

  test(
    'parses collaboration payloads into canonical collaboration details',
    () {
      final details = support.collaborationDetails(
        CodexCanonicalItemType.collabAgentToolCall,
        const <String, dynamic>{
          'senderThreadId': 'thread_parent',
          'receiverThreadIds': <String>['thread_child'],
          'tool': 'wait',
          'status': 'completed',
          'prompt': 'Wait for the worker',
          'model': 'gpt-5.4',
          'reasoningEffort': 'high',
          'agentsStates': <String, Object?>{
            'thread_child': <String, Object?>{
              'status': 'completed',
              'message': 'Done',
            },
          },
        },
      );

      expect(details, isNotNull);
      expect(details?.tool, CodexRuntimeCollabAgentTool.wait);
      expect(details?.status, CodexRuntimeCollabAgentToolCallStatus.completed);
      expect(details?.senderThreadId, 'thread_parent');
      expect(details?.receiverThreadIds, <String>['thread_child']);
      expect(
        details?.agentsStates['thread_child']?.status,
        CodexRuntimeCollabAgentStatus.completed,
      );
      expect(details?.agentsStates['thread_child']?.message, 'Done');
    },
  );

  test('normalizes turn usage, item status, and thread source kind', () {
    final usage = support.turnUsage(const <String, dynamic>{
      'input_tokens': 12,
      'cachedInputTokens': 3,
      'outputTokens': 5,
    });

    expect(usage?.inputTokens, 12);
    expect(usage?.cachedInputTokens, 3);
    expect(usage?.outputTokens, 5);
    expect(
      support.itemStatus('running', CodexRuntimeItemStatus.completed),
      CodexRuntimeItemStatus.inProgress,
    );
    expect(support.turnState('failed'), CodexRuntimeTurnState.failed);
    expect(
      support.threadSourceKind(const <String, dynamic>{'source': 'app-server'}),
      'app-server',
    );
    expect(
      support.threadSourceKind(const <String, dynamic>{
        'source': <String, Object?>{'kind': 'resume'},
      }),
      'resume',
    );
  });
}
