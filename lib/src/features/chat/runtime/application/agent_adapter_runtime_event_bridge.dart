import 'package:pocket_relay/src/features/chat/runtime/domain/agent_adapter_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';

CodexRuntimeEvent codexRuntimeEventFromAgentAdapter(
  AgentAdapterRuntimeEvent event,
) {
  if (event is CodexRuntimeEvent) {
    return event;
  }
  throw UnsupportedError(
    'Unsupported agent adapter runtime event type: ${event.runtimeType}',
  );
}
