import 'package:pocket_relay/src/features/chat/runtime/domain/agent_adapter_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';

TranscriptRuntimeEvent transcriptRuntimeEventFromAgentAdapter(
  AgentAdapterRuntimeEvent event,
) {
  if (event is TranscriptRuntimeEvent) {
    return event;
  }
  throw UnsupportedError(
    'Unsupported agent adapter runtime event type: ${event.runtimeType}',
  );
}
