part of 'runtime_event_mapper.dart';

List<CodexRuntimeEvent>? _mapTurnOrItemNotificationEvent(
  CodexAppServerNotificationEvent event,
  DateTime now, {
  required Map<String, dynamic>? payload,
}) {
  switch (event.method) {
    case 'turn/started':
      final threadId = _asString(payload?['threadId']);
      final turn = _asObject(payload?['turn']);
      final turnId = _asString(turn?['id']) ?? _asString(payload?['turnId']);
      return <CodexRuntimeEvent>[
        CodexRuntimeTurnStartedEvent(
          createdAt: now,
          threadId: threadId,
          turnId: turnId,
          rawMethod: event.method,
          rawPayload: event.params,
          model: _asString(turn?['model']),
          effort: _reasoningEffortFromPayload(turn),
        ),
      ];
    case 'turn/completed':
      final threadId = _asString(payload?['threadId']);
      final turn = _asObject(payload?['turn']);
      final turnId = _asString(turn?['id']) ?? _asString(payload?['turnId']);
      final turnError = _asObject(turn?['error']);
      return <CodexRuntimeEvent>[
        CodexRuntimeTurnCompletedEvent(
          createdAt: now,
          threadId: threadId,
          turnId: turnId,
          rawMethod: event.method,
          rawPayload: event.params,
          state: _turnState(_asString(turn?['status'])),
          stopReason: _asString(turn?['stopReason']),
          usage: _toTurnUsage(_asObject(turn?['usage'])),
          modelUsage: _asObject(turn?['modelUsage']),
          totalCostUsd: _asDouble(turn?['totalCostUsd']),
          errorMessage: _asString(turnError?['message']),
        ),
      ];
    case 'turn/aborted':
      return <CodexRuntimeEvent>[
        CodexRuntimeTurnAbortedEvent(
          createdAt: now,
          threadId: _asString(payload?['threadId']),
          turnId: _asString(payload?['turnId']),
          rawMethod: event.method,
          rawPayload: event.params,
          reason: _eventReason(payload) ?? 'Turn aborted.',
        ),
      ];
    case 'turn/plan/updated':
      return <CodexRuntimeEvent>[
        CodexRuntimeTurnPlanUpdatedEvent(
          createdAt: now,
          threadId: _asString(payload?['threadId']),
          turnId: _asString(payload?['turnId']),
          rawMethod: event.method,
          rawPayload: event.params,
          explanation: _asString(payload?['explanation']),
          steps: _toPlanSteps(_asList(payload?['plan'])),
        ),
      ];
    case 'item/started':
      final itemEvent = _mapItemLifecycle(
        payload,
        now,
        rawMethod: event.method,
        rawPayload: event.params,
        fallbackStatus: CodexRuntimeItemStatus.inProgress,
        builder:
            ({
              required createdAt,
              required itemType,
              required threadId,
              required turnId,
              required itemId,
              required status,
              required rawMethod,
              required rawPayload,
              required title,
              required detail,
              required snapshot,
              required collaboration,
            }) => CodexRuntimeItemStartedEvent(
              createdAt: createdAt,
              itemType: itemType,
              threadId: threadId,
              turnId: turnId,
              itemId: itemId,
              status: status,
              rawMethod: rawMethod,
              rawPayload: rawPayload,
              title: title,
              detail: detail,
              snapshot: snapshot,
              collaboration: collaboration,
            ),
      );
      return itemEvent == null
          ? const <CodexRuntimeEvent>[]
          : <CodexRuntimeEvent>[itemEvent];
    case 'item/completed':
      final itemEvent = _mapItemLifecycle(
        payload,
        now,
        rawMethod: event.method,
        rawPayload: event.params,
        fallbackStatus: CodexRuntimeItemStatus.completed,
        builder:
            ({
              required createdAt,
              required itemType,
              required threadId,
              required turnId,
              required itemId,
              required status,
              required rawMethod,
              required rawPayload,
              required title,
              required detail,
              required snapshot,
              required collaboration,
            }) => CodexRuntimeItemCompletedEvent(
              createdAt: createdAt,
              itemType: itemType,
              threadId: threadId,
              turnId: turnId,
              itemId: itemId,
              status: status,
              rawMethod: rawMethod,
              rawPayload: rawPayload,
              title: title,
              detail: detail,
              snapshot: snapshot,
              collaboration: collaboration,
            ),
      );
      return itemEvent == null
          ? const <CodexRuntimeEvent>[]
          : <CodexRuntimeEvent>[itemEvent];
    case 'item/reasoning/summaryPartAdded':
    case 'item/commandExecution/terminalInteraction':
    case 'item/mcpToolCall/progress':
      final itemEvent = event.method == 'item/mcpToolCall/progress'
          ? _mapMcpToolProgress(
              payload,
              now,
              rawMethod: event.method,
              rawPayload: event.params,
            )
          : _mapItemLifecycle(
                  payload,
                  now,
                  rawMethod: event.method,
                  rawPayload: event.params,
                  fallbackStatus: CodexRuntimeItemStatus.inProgress,
                  builder:
                      ({
                        required createdAt,
                        required itemType,
                        required threadId,
                        required turnId,
                        required itemId,
                        required status,
                        required rawMethod,
                        required rawPayload,
                        required title,
                        required detail,
                        required snapshot,
                        required collaboration,
                      }) => CodexRuntimeItemUpdatedEvent(
                        createdAt: createdAt,
                        itemType: itemType,
                        threadId: threadId,
                        turnId: turnId,
                        itemId: itemId,
                        status: status,
                        rawMethod: rawMethod,
                        rawPayload: rawPayload,
                        title: title,
                        detail: detail,
                        snapshot: snapshot,
                        collaboration: collaboration,
                      ),
                ) ??
                _mapPartialItemUpdate(
                  payload,
                  now,
                  rawMethod: event.method,
                  rawPayload: event.params,
                );
      return itemEvent == null
          ? const <CodexRuntimeEvent>[]
          : <CodexRuntimeEvent>[itemEvent];
    case 'item/agentMessage/delta':
    case 'item/reasoning/textDelta':
    case 'item/reasoning/summaryTextDelta':
    case 'item/plan/delta':
    case 'item/commandExecution/outputDelta':
    case 'item/fileChange/outputDelta':
      final delta = _contentDelta(payload);
      final itemId = _asString(payload?['itemId']);
      final threadId = _asString(payload?['threadId']);
      final turnId = _asString(payload?['turnId']);
      if (delta == null ||
          delta.isEmpty ||
          itemId == null ||
          threadId == null ||
          turnId == null) {
        return const <CodexRuntimeEvent>[];
      }

      return <CodexRuntimeEvent>[
        CodexRuntimeContentDeltaEvent(
          createdAt: now,
          threadId: threadId,
          turnId: turnId,
          itemId: itemId,
          rawMethod: event.method,
          rawPayload: event.params,
          streamKind: _streamKindFromMethod(event.method),
          delta: delta,
          contentIndex: _asInt(payload?['contentIndex']),
          summaryIndex: _asInt(payload?['summaryIndex']),
        ),
      ];
    default:
      return null;
  }
}
