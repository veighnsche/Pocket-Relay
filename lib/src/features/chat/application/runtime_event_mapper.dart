import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_json_rpc_codec.dart';

part 'runtime_event_mapper_transport_mapper.dart';
part 'runtime_event_mapper_notification_mapper.dart';
part 'runtime_event_mapper_request_mapper.dart';
part 'runtime_event_mapper_history_mapper.dart';
part 'runtime_event_mapper_support.dart';

class CodexRuntimeEventMapper {
  final _pendingRequests = <String, _PendingRequestInfo>{};

  List<CodexRuntimeEvent> mapEvent(CodexAppServerEvent event) {
    final now = DateTime.now();

    if (event is CodexAppServerConnectedEvent ||
        event is CodexAppServerDisconnectedEvent) {
      _pendingRequests.clear();
    }

    switch (event) {
      case CodexAppServerRequestEvent():
        return _mapRuntimeRequestEvent(
          event,
          now,
          pendingRequests: _pendingRequests,
        );
      case CodexAppServerNotificationEvent():
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

  List<CodexRuntimeEvent> mapThreadHistory(CodexAppServerThreadHistory thread) {
    return _mapRuntimeThreadHistory(thread);
  }
}

class _PendingRequestInfo {
  const _PendingRequestInfo({
    required this.requestType,
    this.threadId,
    this.turnId,
    this.itemId,
  });

  final CodexCanonicalRequestType requestType;
  final String? threadId;
  final String? turnId;
  final String? itemId;
}
