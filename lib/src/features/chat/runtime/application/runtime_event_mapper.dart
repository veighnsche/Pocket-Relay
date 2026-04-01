import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/agent_adapter_runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/codex_runtime_payload_support.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_json_rpc_codec.dart';

part 'runtime_event_mapper_transport_mapper.dart';
part 'runtime_event_mapper_notification_mapper.dart';
part 'runtime_event_mapper_notification_mapper_session_thread.dart';
part 'runtime_event_mapper_notification_mapper_turn_item.dart';
part 'runtime_event_mapper_notification_mapper_request_error.dart';
part 'runtime_event_mapper_request_mapper.dart';
part 'runtime_event_mapper_support.dart';

class CodexRuntimeEventMapper implements AgentAdapterRuntimeEventMapper {
  final _pendingRequests = <String, _PendingRequestInfo>{};

  @override
  List<TranscriptRuntimeEvent> mapEvent(AgentAdapterEvent event) {
    final now = DateTime.now();

    if (event is AgentAdapterConnectedEvent ||
        event is AgentAdapterDisconnectedEvent) {
      _pendingRequests.clear();
    }

    switch (event) {
      case AgentAdapterRequestEvent():
        return _mapRuntimeRequestEvent(
          event,
          now,
          pendingRequests: _pendingRequests,
        );
      case AgentAdapterNotificationEvent():
        return _mapRuntimeNotificationEvent(
          event,
          now,
          pendingRequests: _pendingRequests,
        );
      default:
        final transportEvents = _mapTransportRuntimeEvent(event, now);
        if (transportEvents != null) {
          return transportEvents;
        }
        throw StateError('Unhandled app-server event: $event');
    }
  }
}

class _PendingRequestInfo {
  const _PendingRequestInfo({
    required this.requestType,
    this.threadId,
    this.turnId,
    this.itemId,
  });

  final TranscriptCanonicalRequestType requestType;
  final String? threadId;
  final String? turnId;
  final String? itemId;
}
