import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/agent_adapter_runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/runtime/application/runtime_event_mapper.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/agent_adapter_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_connection_scoped_transport.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';

class AgentAdapterDefinition {
  const AgentAdapterDefinition({
    required this.kind,
    required this.label,
    required this.defaultCommand,
    required this.localConnectionLabel,
  });

  final AgentAdapterKind kind;
  final String label;
  final String defaultCommand;
  final String localConnectionLabel;
}

const AgentAdapterDefinition _codexAgentAdapterDefinition =
    AgentAdapterDefinition(
      kind: AgentAdapterKind.codex,
      label: 'Codex',
      defaultCommand: 'codex',
      localConnectionLabel: 'local Codex',
    );

AgentAdapterDefinition agentAdapterDefinitionFor(AgentAdapterKind kind) {
  return switch (kind) {
    AgentAdapterKind.codex => _codexAgentAdapterDefinition,
  };
}

AgentAdapterRuntimeEventMapper createAgentAdapterRuntimeEventMapper(
  AgentAdapterKind kind,
) {
  return switch (kind) {
    AgentAdapterKind.codex => CodexRuntimeEventMapper(),
  };
}

AgentAdapterClient createDefaultAgentAdapterClient({
  required ConnectionProfile profile,
  String? ownerId,
  CodexRemoteAppServerOwnerInspector remoteOwnerInspector =
      const CodexSshRemoteAppServerOwnerInspector(),
}) {
  return switch ((profile.agentAdapter, profile.connectionMode)) {
    (AgentAdapterKind.codex, ConnectionMode.local) => CodexAppServerClient(),
    (AgentAdapterKind.codex, ConnectionMode.remote) => () {
      final normalizedOwnerId = ownerId?.trim();
      if (normalizedOwnerId == null || normalizedOwnerId.isEmpty) {
        throw const CodexAppServerException(
          'Remote agent adapter sessions require a managed owner id.',
        );
      }
      return CodexAppServerClient(
        transportOpener: buildConnectionScopedCodexAppServerTransportOpener(
          ownerId: normalizedOwnerId,
          remoteOwnerInspector: remoteOwnerInspector,
        ),
      );
    }(),
  };
}

String agentAdapterLabel(AgentAdapterKind kind) {
  return agentAdapterDefinitionFor(kind).label;
}

String localConnectionLabelForAgentAdapter(AgentAdapterKind kind) {
  return agentAdapterDefinitionFor(kind).localConnectionLabel;
}

String defaultCommandForAgentAdapter(AgentAdapterKind kind) {
  return agentAdapterDefinitionFor(kind).defaultCommand;
}
