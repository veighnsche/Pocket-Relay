part of 'runtime_event_mapper.dart';

List<CodexRuntimeEvent> _mapRuntimeThreadHistory(
  CodexAppServerThreadHistory thread,
) {
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
    final threadId = turn.threadId ?? thread.id;
    final turnCreatedAt = _eventTimestamp(
      turn.raw,
      fallback: fallbackCreatedAt,
    );
    events.add(
      CodexRuntimeTurnStartedEvent(
        createdAt: turnCreatedAt,
        threadId: threadId,
        turnId: turn.id,
        rawMethod: 'thread/read(turn)',
        rawPayload: turn.raw,
        model: turn.model,
        effort: turn.effort,
      ),
    );

    for (final item in turn.items) {
      final event = _mapHistoricalItemLifecycleEvent(
        item.raw,
        threadId: threadId,
        turnId: turn.id,
        fallbackCreatedAt: turnCreatedAt,
      );
      if (event != null) {
        events.add(event);
      }
    }

    events.add(
      CodexRuntimeTurnCompletedEvent(
        createdAt: _eventTimestamp(turn.raw, fallback: turnCreatedAt),
        threadId: threadId,
        turnId: turn.id,
        rawMethod: 'thread/read(turn)',
        rawPayload: turn.raw,
        state: _turnState(turn.status),
        stopReason: turn.stopReason,
        usage: _toTurnUsage(turn.usage),
        modelUsage: turn.modelUsage,
        totalCostUsd: turn.totalCostUsd,
        errorMessage: _asString(turn.error?['message']),
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
