import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/runtime_event_mapper.dart';

void main() {
  test('maps transport connect and disconnect into session runtime events', () {
    final mapper = CodexRuntimeEventMapper();

    final connectedEvents = mapper.mapEvent(
      const CodexAppServerConnectedEvent(userAgent: 'codex-cli/0.114.0'),
    );
    final disconnectedEvents = mapper.mapEvent(
      const CodexAppServerDisconnectedEvent(exitCode: 0),
    );

    expect(connectedEvents, hasLength(1));
    expect(
      connectedEvents[0],
      isA<TranscriptRuntimeSessionStateChangedEvent>(),
    );
    expect(
      (connectedEvents[0] as TranscriptRuntimeSessionStateChangedEvent).state,
      TranscriptRuntimeSessionState.ready,
    );

    expect(
      disconnectedEvents.single,
      isA<TranscriptRuntimeSessionExitedEvent>(),
    );
    expect(
      (disconnectedEvents.single as TranscriptRuntimeSessionExitedEvent)
          .exitKind,
      TranscriptRuntimeSessionExitKind.graceful,
    );
  });

  test('maps thread, turn, item, and content notifications', () {
    final mapper = CodexRuntimeEventMapper();

    final threadStarted = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'thread/started',
        params: <String, Object?>{
          'thread': <String, Object?>{'id': 'thread_123'},
        },
      ),
    );
    final turnStarted = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_123',
            'model': 'gpt-5.3-codex',
            'effort': 'high',
          },
        },
      ),
    );
    final itemStarted = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'item': <String, Object?>{
            'id': 'item_123',
            'type': 'agentMessage',
            'status': 'inProgress',
            'text': 'Draft response',
          },
        },
      ),
    );
    final delta = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/agentMessage/delta',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'delta': 'Hello',
        },
      ),
    );

    final threadEvent =
        threadStarted.single as TranscriptRuntimeThreadStartedEvent;
    final turnEvent = turnStarted.single as TranscriptRuntimeTurnStartedEvent;
    final itemEvent = itemStarted.single as TranscriptRuntimeItemStartedEvent;
    final deltaEvent = delta.single as TranscriptRuntimeContentDeltaEvent;

    expect(threadEvent.providerThreadId, 'thread_123');
    expect(turnEvent.turnId, 'turn_123');
    expect(turnEvent.model, 'gpt-5.3-codex');
    expect(itemEvent.itemType, TranscriptCanonicalItemType.assistantMessage);
    expect(itemEvent.status, TranscriptRuntimeItemStatus.inProgress);
    expect(itemEvent.detail, 'Draft response');
    expect(
      deltaEvent.streamKind,
      TranscriptRuntimeContentStreamKind.assistantText,
    );
    expect(deltaEvent.delta, 'Hello');
  });

  test('maps turn started effort from reasoning effort field variants', () {
    final mapper = CodexRuntimeEventMapper();

    final camelCaseEvent = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_camel',
            'model': 'gpt-5.4',
            'reasoningEffort': 'xhigh',
          },
        },
      ),
    );
    final snakeCaseEvent = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'turn/started',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turn': <String, Object?>{
            'id': 'turn_snake',
            'model': 'gpt-5.4',
            'reasoning_effort': 'high',
          },
        },
      ),
    );

    expect(
      (camelCaseEvent.single as TranscriptRuntimeTurnStartedEvent).effort,
      'xhigh',
    );
    expect(
      (snakeCaseEvent.single as TranscriptRuntimeTurnStartedEvent).effort,
      'high',
    );
  });

  test('preserves whitespace in streaming content deltas', () {
    final mapper = CodexRuntimeEventMapper();

    final leadingSpace = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/agentMessage/delta',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'delta': ' shell',
        },
      ),
    );
    final spaceOnly = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/agentMessage/delta',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'delta': ' ',
        },
      ),
    );

    expect(
      (leadingSpace.single as TranscriptRuntimeContentDeltaEvent).delta,
      ' shell',
    );
    expect((spaceOnly.single as TranscriptRuntimeContentDeltaEvent).delta, ' ');
  });
}
