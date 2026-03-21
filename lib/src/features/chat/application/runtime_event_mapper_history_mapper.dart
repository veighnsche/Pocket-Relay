part of 'runtime_event_mapper.dart';

List<CodexRuntimeEvent> _mapRuntimeThreadHistory(CodexAppServerThread thread) {
  final fallbackCreatedAt =
      thread.createdAt ?? thread.updatedAt ?? DateTime.now();
  final events = <CodexRuntimeEvent>[
    CodexRuntimeThreadStartedEvent(
      createdAt: fallbackCreatedAt,
      threadId: thread.id,
      providerThreadId: thread.id,
      rawMethod: 'thread/read(response)',
      threadName: thread.name,
      sourceKind: thread.sourceKind,
      agentNickname: thread.agentNickname,
      agentRole: thread.agentRole,
    ),
  ];

  for (final turn in thread.turns) {
    final turnId = _asString(turn['id']);
    if (turnId == null || turnId.isEmpty) {
      continue;
    }

    final threadId = _asString(turn['threadId']) ?? thread.id;
    final turnCreatedAt = _eventTimestamp(turn, fallback: fallbackCreatedAt);
    events.add(
      CodexRuntimeTurnStartedEvent(
        createdAt: turnCreatedAt,
        threadId: threadId,
        turnId: turnId,
        rawMethod: 'thread/read(turn)',
        rawPayload: turn,
        model: _asString(turn['model']),
        effort:
            _asString(turn['effort']) ??
            _asString(turn['reasoningEffort']) ??
            _asString(turn['reasoning_effort']),
      ),
    );

    final items =
        _asObjectList(turn['items']) ?? const <Map<String, dynamic>>[];
    for (final item in items) {
      final event = _mapHistoricalItemLifecycleEvent(
        item,
        threadId: threadId,
        turnId: turnId,
        fallbackCreatedAt: turnCreatedAt,
      );
      if (event != null) {
        events.add(event);
      }
    }

    final turnError = _asObject(turn['error']);
    events.add(
      CodexRuntimeTurnCompletedEvent(
        createdAt: _eventTimestamp(turn, fallback: turnCreatedAt),
        threadId: threadId,
        turnId: turnId,
        rawMethod: 'thread/read(turn)',
        rawPayload: turn,
        state: _turnState(_asString(turn['status'])),
        stopReason: _asString(turn['stopReason']),
        usage: _toTurnUsage(_asObject(turn['usage'])),
        modelUsage: _asObject(turn['modelUsage']),
        totalCostUsd: _asDouble(turn['totalCostUsd']),
        errorMessage: _asString(turnError?['message']),
      ),
    );
  }

  return events;
}

CodexRuntimeItemLifecycleEvent? _mapHistoricalItemLifecycleEvent(
  Map<String, dynamic> item, {
  required String threadId,
  required String turnId,
  required DateTime fallbackCreatedAt,
}) {
  final itemId = _asString(item['id']);
  if (itemId == null || itemId.isEmpty) {
    return null;
  }

  final payload = <String, Object?>{
    'threadId': threadId,
    'turnId': turnId,
    'itemId': itemId,
    'item': item,
  };
  final createdAt = _eventTimestamp(item, fallback: fallbackCreatedAt);
  final status = _itemStatus(item['status'], CodexRuntimeItemStatus.completed);
  if (status == CodexRuntimeItemStatus.inProgress) {
    return _mapItemLifecycle(
      payload,
      createdAt,
      rawMethod: 'thread/read(item)',
      rawPayload: payload,
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
  }

  return _mapItemLifecycle(
    payload,
    createdAt,
    rawMethod: 'thread/read(item)',
    rawPayload: payload,
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
}
