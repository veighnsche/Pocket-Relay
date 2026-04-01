part of 'runtime_event_mapper.dart';

List<TranscriptRuntimeEvent> _mapRuntimeRequestEvent(
  AgentAdapterRequestEvent event,
  DateTime now, {
  required Map<String, _PendingRequestInfo> pendingRequests,
}) {
  final payload = _asObject(event.params);
  final threadId = _asString(payload?['threadId']);
  final turnId = _asString(payload?['turnId']);
  final itemId = _asString(payload?['itemId']);
  final requestType = _requestTypeFromMethod(event.method);

  pendingRequests[event.requestId] = _PendingRequestInfo(
    requestType: requestType,
    threadId: threadId,
    turnId: turnId,
    itemId: itemId,
  );

  if (event.method == 'item/tool/requestUserInput' ||
      event.method == 'tool/requestUserInput') {
    final questions = _toUserInputQuestions(payload);
    if (questions.isEmpty) {
      return const <TranscriptRuntimeEvent>[];
    }

    return <TranscriptRuntimeEvent>[
      TranscriptRuntimeUserInputRequestedEvent(
        createdAt: now,
        threadId: threadId,
        turnId: turnId,
        itemId: itemId,
        requestId: event.requestId,
        rawMethod: event.method,
        rawPayload: event.params,
        questions: questions,
      ),
    ];
  }

  return <TranscriptRuntimeEvent>[
    TranscriptRuntimeRequestOpenedEvent(
      createdAt: now,
      threadId: threadId,
      turnId: turnId,
      itemId: itemId,
      requestId: event.requestId,
      rawMethod: event.method,
      rawPayload: event.params,
      requestType: requestType,
      detail: _requestDetail(payload),
      args: event.params,
    ),
  ];
}
