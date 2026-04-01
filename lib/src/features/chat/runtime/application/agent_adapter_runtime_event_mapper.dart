import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_models.dart';

abstract interface class AgentAdapterRuntimeEventMapper {
  List<CodexRuntimeEvent> mapEvent(CodexAppServerEvent event);
}
