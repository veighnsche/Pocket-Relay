part of 'runtime_event_mapper.dart';

typedef _ItemLifecycleEventBuilder =
    CodexRuntimeItemLifecycleEvent Function({
      required DateTime createdAt,
      required CodexCanonicalItemType itemType,
      required String threadId,
      required String turnId,
      required String itemId,
      required CodexRuntimeItemStatus status,
      required String rawMethod,
      required Object? rawPayload,
      required String? title,
      required String? detail,
      required Map<String, dynamic>? snapshot,
    });

List<CodexRuntimeEvent> _mapRuntimeNotificationEvent(
  CodexAppServerNotificationEvent event,
  DateTime now, {
  required Map<String, _PendingRequestInfo> pendingRequests,
}) {
  final payload = _asObject(event.params);

  switch (event.method) {
    case 'session/connecting':
      return <CodexRuntimeEvent>[
        CodexRuntimeSessionStateChangedEvent(
          createdAt: now,
          state: CodexRuntimeSessionState.starting,
          reason: _eventReason(payload) ?? 'Starting app-server session.',
          rawMethod: event.method,
          rawPayload: event.params,
        ),
      ];
    case 'session/ready':
      return <CodexRuntimeEvent>[
        CodexRuntimeSessionStateChangedEvent(
          createdAt: now,
          state: CodexRuntimeSessionState.ready,
          reason: _eventReason(payload),
          rawMethod: event.method,
          rawPayload: event.params,
        ),
      ];
    case 'session/exited':
    case 'session/closed':
      pendingRequests.clear();
      return <CodexRuntimeEvent>[
        CodexRuntimeSessionExitedEvent(
          createdAt: now,
          exitKind: event.method == 'session/closed'
              ? CodexRuntimeSessionExitKind.graceful
              : CodexRuntimeSessionExitKind.error,
          exitCode: _asInt(payload?['exitCode']),
          reason: _eventReason(payload),
          rawMethod: event.method,
          rawPayload: event.params,
        ),
      ];
    case 'thread/started':
      final thread = _asObject(payload?['thread']);
      final providerThreadId =
          _asString(thread?['id']) ?? _asString(payload?['threadId']);
      if (providerThreadId == null || providerThreadId.isEmpty) {
        return const <CodexRuntimeEvent>[];
      }

      return <CodexRuntimeEvent>[
        CodexRuntimeThreadStartedEvent(
          createdAt: now,
          threadId: providerThreadId,
          providerThreadId: providerThreadId,
          rawMethod: event.method,
          rawPayload: event.params,
        ),
      ];
    case 'thread/status/changed':
    case 'thread/archived':
    case 'thread/unarchived':
    case 'thread/closed':
    case 'thread/compacted':
      final threadId = _asString(payload?['threadId']);
      return <CodexRuntimeEvent>[
        CodexRuntimeThreadStateChangedEvent(
          createdAt: now,
          threadId: threadId,
          state: _threadStateFor(event.method, payload),
          detail: event.params,
          rawMethod: event.method,
          rawPayload: event.params,
        ),
      ];
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
          effort: _asString(turn?['effort']),
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
    case 'serverRequest/resolved':
      final requestId = _requestTokenFromRaw(payload?['requestId']);
      if (requestId == null) {
        return const <CodexRuntimeEvent>[];
      }

      final pending = pendingRequests.remove(requestId);
      final requestType =
          pending?.requestType ?? _requestTypeFromResolvedPayload(payload);
      return <CodexRuntimeEvent>[
        CodexRuntimeRequestResolvedEvent(
          createdAt: now,
          threadId: _asString(payload?['threadId']) ?? pending?.threadId,
          turnId: pending?.turnId,
          itemId: pending?.itemId,
          requestId: requestId,
          rawMethod: event.method,
          rawPayload: event.params,
          requestType: requestType,
          resolution: payload?['resolution'] ?? event.params,
        ),
      ];
    case 'thread/tokenUsage/updated':
      return <CodexRuntimeEvent>[
        CodexRuntimeStatusEvent(
          createdAt: now,
          threadId: _asString(payload?['threadId']),
          turnId: _asString(payload?['turnId']),
          rawMethod: event.method,
          rawPayload: event.params,
          title: 'Thread token usage',
          message: _threadTokenUsageMessage(payload),
        ),
      ];
    case 'item/tool/requestUserInput/answered':
    case 'tool/requestUserInput/answered':
      final requestId = _requestTokenFromRaw(payload?['requestId']);
      if (requestId != null) {
        pendingRequests.remove(requestId);
      }
      return <CodexRuntimeEvent>[
        CodexRuntimeUserInputResolvedEvent(
          createdAt: now,
          threadId: _asString(payload?['threadId']),
          turnId: _asString(payload?['turnId']),
          itemId: _asString(payload?['itemId']),
          requestId: requestId,
          rawMethod: event.method,
          rawPayload: event.params,
          answers: _toUserInputAnswers(_asObject(payload?['answers'])),
        ),
      ];
    case 'error':
      final message = _asString(payload?['message']) ?? 'Codex runtime error.';
      return <CodexRuntimeEvent>[
        CodexRuntimeErrorEvent(
          createdAt: now,
          threadId: _asString(payload?['threadId']),
          turnId: _asString(payload?['turnId']),
          itemId: _asString(payload?['itemId']),
          rawMethod: event.method,
          rawPayload: event.params,
          message: message,
          errorClass: CodexRuntimeErrorClass.providerError,
          detail: event.params,
        ),
      ];
    case 'configWarning':
      final summary =
          _asString(payload?['summary']) ?? 'Configuration warning.';
      final details = _stringFromCandidates(<Object?>[
        payload?['details'],
        payload?['path'],
      ]);
      return <CodexRuntimeEvent>[
        CodexRuntimeWarningEvent(
          createdAt: now,
          rawMethod: event.method,
          rawPayload: event.params,
          summary: summary,
          details: details,
        ),
      ];
    case 'deprecationNotice':
      final summary = _asString(payload?['summary']) ?? 'Deprecation notice.';
      return <CodexRuntimeEvent>[
        CodexRuntimeWarningEvent(
          createdAt: now,
          rawMethod: event.method,
          rawPayload: event.params,
          summary: summary,
          details: _asString(payload?['details']),
        ),
      ];
    default:
      return const <CodexRuntimeEvent>[];
  }
}

CodexRuntimeItemUpdatedEvent? _mapMcpToolProgress(
  Map<String, dynamic>? payload,
  DateTime now, {
  required String rawMethod,
  required Object? rawPayload,
}) {
  final threadId = _asString(payload?['threadId']);
  final turnId = _asString(payload?['turnId']);
  final itemId = _asString(payload?['itemId']);
  final message = _asString(payload?['message'])?.trim();
  if (threadId == null ||
      turnId == null ||
      itemId == null ||
      message == null ||
      message.isEmpty) {
    return null;
  }

  return CodexRuntimeItemUpdatedEvent(
    createdAt: now,
    itemType: CodexCanonicalItemType.mcpToolCall,
    threadId: threadId,
    turnId: turnId,
    itemId: itemId,
    status: CodexRuntimeItemStatus.inProgress,
    rawMethod: rawMethod,
    rawPayload: rawPayload,
    title: _itemTitle(CodexCanonicalItemType.mcpToolCall),
    detail: message,
  );
}

CodexRuntimeItemLifecycleEvent? _mapItemLifecycle(
  Map<String, dynamic>? payload,
  DateTime now, {
  required String rawMethod,
  required Object? rawPayload,
  required CodexRuntimeItemStatus fallbackStatus,
  required _ItemLifecycleEventBuilder builder,
}) {
  final item = _asObject(payload?['item']);
  final threadId = _asString(payload?['threadId']);
  final turnId = _asString(payload?['turnId']);
  final itemId = _asString(item?['id']) ?? _asString(payload?['itemId']);
  if (item == null || threadId == null || turnId == null || itemId == null) {
    return null;
  }

  final itemType = _canonicalItemType(item['type'] ?? item['kind']);
  return builder(
    createdAt: now,
    itemType: itemType,
    threadId: threadId,
    turnId: turnId,
    itemId: itemId,
    status: _itemStatus(item['status'], fallbackStatus),
    rawMethod: rawMethod,
    rawPayload: rawPayload,
    title: _itemTitle(itemType),
    detail: _itemDetail(item, payload),
    snapshot: item,
  );
}

CodexRuntimeItemUpdatedEvent? _mapPartialItemUpdate(
  Map<String, dynamic>? payload,
  DateTime now, {
  required String rawMethod,
  required Object? rawPayload,
}) {
  final threadId = _asString(payload?['threadId']);
  final turnId = _asString(payload?['turnId']);
  final itemId = _asString(payload?['itemId']);
  if (threadId == null || turnId == null || itemId == null) {
    return null;
  }

  final itemType = switch (rawMethod) {
    'item/reasoning/summaryPartAdded' => CodexCanonicalItemType.reasoning,
    'item/commandExecution/terminalInteraction' =>
      CodexCanonicalItemType.commandExecution,
    _ => CodexCanonicalItemType.unknown,
  };

  final detail = switch (rawMethod) {
    'item/reasoning/summaryPartAdded' => null,
    'item/commandExecution/terminalInteraction' =>
      _asString(payload?['stdin']) ?? _asString(payload?['processId']),
    _ => null,
  };

  return CodexRuntimeItemUpdatedEvent(
    createdAt: now,
    itemType: itemType,
    threadId: threadId,
    turnId: turnId,
    itemId: itemId,
    status: CodexRuntimeItemStatus.inProgress,
    rawMethod: rawMethod,
    rawPayload: rawPayload,
    title: _itemTitle(itemType),
    detail: detail,
    snapshot: payload,
  );
}
