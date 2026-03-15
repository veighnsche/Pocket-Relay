import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/application/runtime_event_mapper.dart';

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
    expect(connectedEvents[0], isA<CodexRuntimeSessionStateChangedEvent>());
    expect(
      (connectedEvents[0] as CodexRuntimeSessionStateChangedEvent).state,
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
      (leadingSpace.single as CodexRuntimeContentDeltaEvent).delta,
      ' shell',
    );
    expect((spaceOnly.single as CodexRuntimeContentDeltaEvent).delta, ' ');
  });

  test('maps official user, review, and image item types correctly', () {
    final mapper = CodexRuntimeEventMapper();

    final userItem = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'item': <String, Object?>{
            'id': 'item_user',
            'type': 'userMessage',
            'status': 'completed',
            'content': <Object>[
              <String, Object?>{'type': 'text', 'text': 'Ship the fix'},
            ],
          },
        },
      ),
    );
    final reviewItem = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'item': <String, Object?>{
            'id': 'item_review',
            'type': 'enteredReviewMode',
            'status': 'completed',
            'review': 'Checking the patch set',
          },
        },
      ),
    );
    final imageItem = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/completed',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'item': <String, Object?>{
            'id': 'item_image',
            'type': 'imageGeneration',
            'status': 'completed',
            'revisedPrompt': 'Diagram of the new architecture',
          },
        },
      ),
    );

    final userEvent = userItem.single as CodexRuntimeItemCompletedEvent;
    final reviewEvent = reviewItem.single as CodexRuntimeItemCompletedEvent;
    final imageEvent = imageItem.single as CodexRuntimeItemCompletedEvent;

    expect(userEvent.itemType, CodexCanonicalItemType.userMessage);
    expect(userEvent.detail, 'Ship the fix');
    expect(reviewEvent.itemType, CodexCanonicalItemType.reviewEntered);
    expect(reviewEvent.detail, 'Checking the patch set');
    expect(imageEvent.itemType, CodexCanonicalItemType.imageGeneration);
    expect(imageEvent.detail, 'Diagram of the new architecture');
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

  test('maps mcp elicitation requests into canonical request events', () {
    final mapper = CodexRuntimeEventMapper();

    final requestOpened = mapper.mapEvent(
      const CodexAppServerRequestEvent(
        requestId: 's:elicitation-1',
        method: 'mcpServer/elicitation/request',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'serverName': 'filesystem',
          'message': 'Choose a directory',
          'mode': 'form',
        },
      ),
    );

    final openedEvent = requestOpened.single as CodexRuntimeRequestOpenedEvent;
    expect(
      openedEvent.requestType,
      CodexCanonicalRequestType.mcpServerElicitation,
    );
    expect(openedEvent.detail, 'Choose a directory');
  });

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

  test('maps progress and token-usage notifications', () {
    final mapper = CodexRuntimeEventMapper();

    final progress = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'item/mcpToolCall/progress',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'itemId': 'item_mcp',
          'message': 'Fetching repository metadata',
        },
      ),
    );
    final tokenUsage = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'thread/tokenUsage/updated',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'tokenUsage': <String, Object?>{
            'last': <String, Object?>{
              'inputTokens': 10,
              'cachedInputTokens': 2,
              'outputTokens': 4,
              'reasoningOutputTokens': 1,
              'totalTokens': 17,
            },
            'total': <String, Object?>{
              'inputTokens': 20,
              'cachedInputTokens': 3,
              'outputTokens': 8,
              'reasoningOutputTokens': 1,
              'totalTokens': 32,
            },
            'modelContextWindow': 200000,
          },
        },
      ),
    );

    final progressEvent = progress.single as CodexRuntimeItemUpdatedEvent;
    final usageEvent = tokenUsage.single as CodexRuntimeStatusEvent;

    expect(progressEvent.itemType, CodexCanonicalItemType.mcpToolCall);
    expect(progressEvent.detail, 'Fetching repository metadata');
    expect(usageEvent.title, 'Thread token usage');
    expect(usageEvent.message, contains('Context window: 200000'));
  });

  test('maps warnings and drops unknown notifications', () {
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

  test('maps unpinned host key transport events into runtime events', () {
    final mapper = CodexRuntimeEventMapper();

    final events = mapper.mapEvent(
      const CodexAppServerUnpinnedHostKeyEvent(
        host: '192.168.1.10',
        port: 22,
        keyType: 'ssh-ed25519',
        fingerprint: '7a:9f:d7:dc:2e:f2',
      ),
    );

    expect(events.single, isA<CodexRuntimeUnpinnedHostKeyEvent>());
    final event = events.single as CodexRuntimeUnpinnedHostKeyEvent;
    expect(event.host, '192.168.1.10');
    expect(event.port, 22);
    expect(event.keyType, 'ssh-ed25519');
    expect(event.fingerprint, '7a:9f:d7:dc:2e:f2');
  });

  test('maps turn plan notifications into runtime events', () {
    final mapper = CodexRuntimeEventMapper();

    final planUpdated = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'turn/plan/updated',
        params: <String, Object?>{
          'threadId': 'thread_123',
          'turnId': 'turn_123',
          'explanation': 'Implement the migration in phases.',
          'plan': <Object>[
            <String, Object?>{
              'step': 'Wire the transport',
              'status': 'completed',
            },
            <String, Object?>{
              'step': 'Render proposed plans',
              'status': 'inProgress',
            },
          ],
        },
      ),
    );
    final planEvent = planUpdated.single as CodexRuntimeTurnPlanUpdatedEvent;

    expect(planEvent.explanation, 'Implement the migration in phases.');
    expect(planEvent.steps, hasLength(2));
    expect(planEvent.steps.first.status, CodexRuntimePlanStepStatus.completed);
    expect(planEvent.steps.last.status, CodexRuntimePlanStepStatus.inProgress);
  });

  test(
    'maps partial item update notifications without embedded item snapshots',
    () {
      final mapper = CodexRuntimeEventMapper();

      final reasoningUpdate = mapper.mapEvent(
        const CodexAppServerNotificationEvent(
          method: 'item/reasoning/summaryPartAdded',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_123',
            'itemId': 'item_123',
            'summaryIndex': 2,
          },
        ),
      );
      final terminalInteraction = mapper.mapEvent(
        const CodexAppServerNotificationEvent(
          method: 'item/commandExecution/terminalInteraction',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_123',
            'itemId': 'item_456',
            'processId': 'proc_1',
            'stdin': 'y\n',
          },
        ),
      );

      final reasoningEvent =
          reasoningUpdate.single as CodexRuntimeItemUpdatedEvent;
      final terminalEvent =
          terminalInteraction.single as CodexRuntimeItemUpdatedEvent;

      expect(reasoningEvent.itemType, CodexCanonicalItemType.reasoning);
      expect(reasoningEvent.itemId, 'item_123');
      expect(reasoningEvent.detail, isNull);
      expect(terminalEvent.itemType, CodexCanonicalItemType.commandExecution);
      expect(terminalEvent.itemId, 'item_456');
      expect(terminalEvent.detail, 'y\n');
    },
  );

  test('clears stale pending requests after disconnect', () {
    final mapper = CodexRuntimeEventMapper();

    mapper.mapEvent(
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
    mapper.mapEvent(const CodexAppServerDisconnectedEvent(exitCode: 1));

    final resolved = mapper.mapEvent(
      const CodexAppServerNotificationEvent(
        method: 'serverRequest/resolved',
        params: <String, Object?>{'threadId': 'thread_123', 'requestId': 99},
      ),
    );

    final resolvedEvent = resolved.single as CodexRuntimeRequestResolvedEvent;
    expect(resolvedEvent.requestType, CodexCanonicalRequestType.unknown);
  });
}
