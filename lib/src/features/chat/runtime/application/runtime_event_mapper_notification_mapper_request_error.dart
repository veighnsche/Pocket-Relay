part of 'runtime_event_mapper.dart';

List<CodexRuntimeEvent>? _mapRequestOrErrorNotificationEvent(
  AgentAdapterNotificationEvent event,
  DateTime now, {
  required Map<String, dynamic>? payload,
  required Map<String, _PendingRequestInfo> pendingRequests,
}) {
  switch (event.method) {
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
      return null;
  }
}
