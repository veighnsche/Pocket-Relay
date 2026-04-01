import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/runtime/domain/agent_adapter_runtime_event.dart';

part 'codex_runtime_event_enums.dart';
part 'codex_runtime_event_models.dart';
part 'codex_runtime_event_events_requests.dart';
part 'codex_runtime_event_events_session.dart';
part 'codex_runtime_event_events_status.dart';

sealed class TranscriptRuntimeEvent extends AgentAdapterRuntimeEvent {
  const TranscriptRuntimeEvent({
    required super.createdAt,
    super.threadId,
    super.turnId,
    super.itemId,
    super.requestId,
    super.rawMethod,
    super.rawPayload,
  });
}
