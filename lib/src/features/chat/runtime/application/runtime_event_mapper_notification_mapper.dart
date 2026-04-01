part of 'runtime_event_mapper.dart';

typedef _ItemLifecycleEventBuilder =
    TranscriptRuntimeItemLifecycleEvent Function({
      required DateTime createdAt,
      required TranscriptCanonicalItemType itemType,
      required String threadId,
      required String turnId,
      required String itemId,
      required TranscriptRuntimeItemStatus status,
      required String rawMethod,
      required Object? rawPayload,
      required String? title,
      required String? detail,
      required Map<String, dynamic>? snapshot,
      required TranscriptRuntimeCollabAgentToolCall? collaboration,
    });

List<TranscriptRuntimeEvent> _mapRuntimeNotificationEvent(
  AgentAdapterNotificationEvent event,
  DateTime now, {
  required Map<String, _PendingRequestInfo> pendingRequests,
}) {
  final payload = _asObject(event.params);

  final sessionOrThreadEvents = _mapSessionOrThreadNotificationEvent(
    event,
    now,
    payload: payload,
    pendingRequests: pendingRequests,
  );
  if (sessionOrThreadEvents != null) {
    return sessionOrThreadEvents;
  }

  final turnOrItemEvents = _mapTurnOrItemNotificationEvent(
    event,
    now,
    payload: payload,
  );
  if (turnOrItemEvents != null) {
    return turnOrItemEvents;
  }

  final requestOrErrorEvents = _mapRequestOrErrorNotificationEvent(
    event,
    now,
    payload: payload,
    pendingRequests: pendingRequests,
  );
  if (requestOrErrorEvents != null) {
    return requestOrErrorEvents;
  }

  return const <TranscriptRuntimeEvent>[];
}

TranscriptRuntimeItemUpdatedEvent? _mapMcpToolProgress(
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

  return TranscriptRuntimeItemUpdatedEvent(
    createdAt: now,
    itemType: TranscriptCanonicalItemType.mcpToolCall,
    threadId: threadId,
    turnId: turnId,
    itemId: itemId,
    status: TranscriptRuntimeItemStatus.inProgress,
    rawMethod: rawMethod,
    rawPayload: rawPayload,
    title: _itemTitle(TranscriptCanonicalItemType.mcpToolCall),
    detail: message,
  );
}

TranscriptRuntimeItemLifecycleEvent? _mapItemLifecycle(
  Map<String, dynamic>? payload,
  DateTime now, {
  required String rawMethod,
  required Object? rawPayload,
  required TranscriptRuntimeItemStatus fallbackStatus,
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
    collaboration: _collaborationDetails(itemType, item),
  );
}

TranscriptRuntimeItemUpdatedEvent? _mapPartialItemUpdate(
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
    'item/reasoning/summaryPartAdded' => TranscriptCanonicalItemType.reasoning,
    'item/commandExecution/terminalInteraction' =>
      TranscriptCanonicalItemType.commandExecution,
    _ => TranscriptCanonicalItemType.unknown,
  };

  final detail = switch (rawMethod) {
    'item/reasoning/summaryPartAdded' => null,
    'item/commandExecution/terminalInteraction' =>
      _asString(payload?['stdin']) ?? _asString(payload?['processId']),
    _ => null,
  };

  return TranscriptRuntimeItemUpdatedEvent(
    createdAt: now,
    itemType: itemType,
    threadId: threadId,
    turnId: turnId,
    itemId: itemId,
    status: TranscriptRuntimeItemStatus.inProgress,
    rawMethod: rawMethod,
    rawPayload: rawPayload,
    title: _itemTitle(itemType),
    detail: detail,
    snapshot: payload,
  );
}
