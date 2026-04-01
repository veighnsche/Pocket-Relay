import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/agent_adapter_runtime_event_bridge.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/agent_adapter_runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/runtime/domain/agent_adapter_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';

void main() {
  test(
    'agent adapter runtime mappers expose transcript-owned runtime events',
    () {
      final AgentAdapterRuntimeEventMapper mapper = CodexRuntimeEventMapper();

      final events = mapper.mapEvent(
        const CodexAppServerConnectedEvent(userAgent: 'codex-cli/test'),
      );

      expect(events, hasLength(1));
      expect(events.single, isA<AgentAdapterRuntimeEvent>());
      expect(
        transcriptRuntimeEventFromAgentAdapter(events.single),
        isA<TranscriptRuntimeSessionStateChangedEvent>(),
      );
    },
  );

  test(
    'bridge rejects unsupported non-transcript runtime event implementations',
    () {
      expect(
        () => transcriptRuntimeEventFromAgentAdapter(
          _UnknownAgentAdapterRuntimeEvent(createdAt: DateTime(2026, 4, 1)),
        ),
        throwsA(isA<UnsupportedError>()),
      );
    },
  );
}

final class _UnknownAgentAdapterRuntimeEvent extends AgentAdapterRuntimeEvent {
  const _UnknownAgentAdapterRuntimeEvent({required super.createdAt});
}
