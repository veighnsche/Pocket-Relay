part of 'runtime_event_mapper.dart';

List<TranscriptRuntimeEvent>? _mapSessionOrThreadNotificationEvent(
  AgentAdapterNotificationEvent event,
  DateTime now, {
  required Map<String, dynamic>? payload,
  required Map<String, _PendingRequestInfo> pendingRequests,
}) {
  switch (event.method) {
    case 'session/connecting':
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeSessionStateChangedEvent(
          createdAt: now,
          state: TranscriptRuntimeSessionState.starting,
          reason: _eventReason(payload) ?? 'Starting app-server session.',
          rawMethod: event.method,
          rawPayload: event.params,
        ),
      ];
    case 'session/ready':
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeSessionStateChangedEvent(
          createdAt: now,
          state: TranscriptRuntimeSessionState.ready,
          reason: _eventReason(payload),
          rawMethod: event.method,
          rawPayload: event.params,
        ),
      ];
    case 'session/exited':
    case 'session/closed':
      pendingRequests.clear();
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeSessionExitedEvent(
          createdAt: now,
          exitKind: event.method == 'session/closed'
              ? TranscriptRuntimeSessionExitKind.graceful
              : TranscriptRuntimeSessionExitKind.error,
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
        return const <TranscriptRuntimeEvent>[];
      }

      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeThreadStartedEvent(
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
      return <TranscriptRuntimeEvent>[
        TranscriptRuntimeThreadStateChangedEvent(
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
