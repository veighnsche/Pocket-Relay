import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/services/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/services/codex_runtime_event_mapper.dart';

void main() {
  test('maps transport connect and disconnect into session runtime events', () {
    final mapper = CodexRuntimeEventMapper();

    final connectedEvents = mapper.mapEvent(
      const CodexAppServerConnectedEvent(userAgent: 'codex-cli/0.114.0'),
    );
    final disconnectedEvents = mapper.mapEvent(
      const CodexAppServerDisconnectedEvent(exitCode: 0),
    );

    expect(connectedEvents, hasLength(2));
    expect(connectedEvents[0], isA<CodexRuntimeSessionStartedEvent>());
    expect(connectedEvents[1], isA<CodexRuntimeSessionStateChangedEvent>());
    expect(
      (connectedEvents[1] as CodexRuntimeSessionStateChangedEvent).state,
      CodexRuntimeSessionState.ready,
    );

    expect(disconnectedEvents.single, isA<CodexRuntimeSessionExitedEvent>());
    expect(
      (disconnectedEvents.single as CodexRuntimeSessionExitedEvent).exitKind,
      CodexRuntimeSessionExitKind.graceful,
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

    final threadEvent = threadStarted.single as CodexRuntimeThreadStartedEvent;
    final turnEvent = turnStarted.single as CodexRuntimeTurnStartedEvent;
    final itemEvent = itemStarted.single as CodexRuntimeItemStartedEvent;
    final deltaEvent = delta.single as CodexRuntimeContentDeltaEvent;

    expect(threadEvent.providerThreadId, 'thread_123');
    expect(turnEvent.turnId, 'turn_123');
    expect(turnEvent.model, 'gpt-5.3-codex');
    expect(itemEvent.itemType, CodexCanonicalItemType.assistantMessage);
    expect(itemEvent.status, CodexRuntimeItemStatus.inProgress);
    expect(itemEvent.detail, 'Draft response');
    expect(deltaEvent.streamKind, CodexRuntimeContentStreamKind.assistantText);
    expect(deltaEvent.delta, 'Hello');
  });

  test(
    'maps request approval and serverRequest/resolved into canonical request events',
    () {
      final mapper = CodexRuntimeEventMapper();

      final requestOpened = mapper.mapEvent(
        const CodexAppServerRequestEvent(
          requestId: 'i:99',
          method: 'item/fileChange/requestApproval',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_123',
            'itemId': 'item_123',
            'reason': 'Write files',
          },
        ),
      );
      final requestResolved = mapper.mapEvent(
        const CodexAppServerNotificationEvent(
          method: 'serverRequest/resolved',
          params: <String, Object?>{'threadId': 'thread_123', 'requestId': 99},
        ),
      );

      final openedEvent =
          requestOpened.single as CodexRuntimeRequestOpenedEvent;
      final resolvedEvent =
          requestResolved.single as CodexRuntimeRequestResolvedEvent;

      expect(
        openedEvent.requestType,
        CodexCanonicalRequestType.fileChangeApproval,
      );
      expect(openedEvent.detail, 'Write files');
      expect(resolvedEvent.requestId, 'i:99');
      expect(
        resolvedEvent.requestType,
        CodexCanonicalRequestType.fileChangeApproval,
      );
    },
  );

  test('maps user input requests and answered notifications', () {
    final mapper = CodexRuntimeEventMapper();

    final requested = mapper.mapEvent(
      const CodexAppServerRequestEvent(
        requestId: 's:user-input-1',
        method: 'item/tool/requestUserInput',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'questions': <Object>[
            <String, Object?>{
              'id': 'q1',
              'header': 'Name',
              'question': 'What is your name?',
              'options': <Object>[
                <String, Object?>{
                  'label': 'Vince',
                  'description': 'Use the saved profile name.',
                },
              ],
            },
          ],
        },
      ),
    );
    final answered = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/tool/requestUserInput/answered',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_123',
          'requestId': 'user-input-1',
          'answers': <String, Object?>{
            'q1': <String, Object?>{
              'answers': <String>['Vince'],
            },
          },
        },
      ),
    );

    final requestedEvent =
        requested.single as CodexRuntimeUserInputRequestedEvent;
    final answeredEvent = answered.single as CodexRuntimeUserInputResolvedEvent;

    expect(requestedEvent.requestId, 's:user-input-1');
    expect(requestedEvent.questions, hasLength(1));
    expect(requestedEvent.questions.single.id, 'q1');
    expect(answeredEvent.requestId, 's:user-input-1');
    expect(answeredEvent.answers['q1'], <String>['Vince']);
  });

  test('maps warnings and drops unknown methods', () {
    final mapper = CodexRuntimeEventMapper();

    final warning = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'configWarning',
        params: <String, Object?>{
          'summary': 'Config warning',
          'details': 'Bad config value',
        },
      ),
    );
    final unknown = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'unknown/method',
        params: <String, Object?>{'x': 1},
      ),
    );

    expect(warning.single, isA<CodexRuntimeWarningEvent>());
    expect(
      (warning.single as CodexRuntimeWarningEvent).summary,
      'Config warning',
    );
    expect(unknown, isEmpty);
  });
}
