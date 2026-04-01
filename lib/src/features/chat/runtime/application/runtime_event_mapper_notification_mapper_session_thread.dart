part of 'runtime_event_mapper.dart';

List<CodexRuntimeEvent>? _mapSessionOrThreadNotificationEvent(
  AgentAdapterNotificationEvent event,
  DateTime now, {
  required Map<String, dynamic>? payload,
  required Map<String, _PendingRequestInfo> pendingRequests,
}) {
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
          threadName: _asString(thread?['name']),
          sourceKind: _threadSourceKind(thread),
          agentNickname: _asString(thread?['agentNickname']),
          agentRole: _asString(thread?['agentRole']),
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
    default:
      return null;
  }
}
