import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_models.dart';

abstract interface class AgentAdapterRuntimeEventMapper {
  List<CodexRuntimeEvent> mapEvent(AgentAdapterEvent event);
}
