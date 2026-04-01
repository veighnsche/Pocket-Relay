import 'package:pocket_relay/src/agent_adapters/agent_adapter_capabilities.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/agent_adapters/codex_agent_adapter_remote_runtime_delegate.dart';
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
    required this.description,
    required this.defaultCommand,
    required this.localConnectionLabel,
    required this.capabilities,
  });

  final AgentAdapterKind kind;
  final String label;
  final String description;
  final String defaultCommand;
  final String localConnectionLabel;
  final AgentAdapterCapabilities capabilities;
}

const AgentAdapterDefinition _codexAgentAdapterDefinition =
    AgentAdapterDefinition(
      kind: AgentAdapterKind.codex,
      label: 'Codex',
      description:
          'Runs local workspaces on desktop and remote workspaces over SSH.',
      defaultCommand: 'codex',
      localConnectionLabel: 'local Codex',
      capabilities: AgentAdapterCapabilities(
        supportsConversationHistory: true,
        supportsConversationRollback: true,
        supportsConversationForking: true,
        supportsLocalConnections: true,
        supportsModelCatalog: true,
        supportsModelCatalogRefresh: true,
        supportsReasoningEffort: true,
        supportsImageInput: true,
        supportsApprovals: true,
        supportsUserInput: true,
        supportsDynamicToolCalls: true,
        supportsRemoteConnections: true,
        supportsRemoteContinuity: true,
        supportsDangerouslyBypassSandbox: true,
        supportsEphemeralSessions: true,
      ),
    );

const List<AgentAdapterDefinition> _agentAdapterDefinitions =
    <AgentAdapterDefinition>[_codexAgentAdapterDefinition];

List<AgentAdapterDefinition> availableAgentAdapterDefinitions() {
  return _agentAdapterDefinitions;
}

AgentAdapterDefinition agentAdapterDefinitionFor(AgentAdapterKind kind) {
  for (final definition in _agentAdapterDefinitions) {
    if (definition.kind == kind) {
      return definition;
    }
  }

  throw StateError('Unknown agent adapter kind: $kind');
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

String agentAdapterDescription(AgentAdapterKind kind) {
  return agentAdapterDefinitionFor(kind).description;
}

AgentAdapterCapabilities agentAdapterCapabilitiesFor(AgentAdapterKind kind) {
  return agentAdapterDefinitionFor(kind).capabilities;
}

String localConnectionLabelForAgentAdapter(AgentAdapterKind kind) {
  return agentAdapterDefinitionFor(kind).localConnectionLabel;
}

String defaultCommandForAgentAdapter(AgentAdapterKind kind) {
  return agentAdapterDefinitionFor(kind).defaultCommand;
}

AgentAdapterRemoteRuntimeDelegate
createDefaultAgentAdapterRemoteRuntimeDelegate(
  AgentAdapterKind kind, {
  CodexRemoteAppServerHostProbe remoteHostProbe =
      const CodexSshRemoteAppServerHostProbe(),
  CodexRemoteAppServerOwnerInspector remoteOwnerInspector =
      const CodexSshRemoteAppServerOwnerInspector(),
  CodexRemoteAppServerOwnerControl remoteOwnerControl =
      const CodexSshRemoteAppServerOwnerControl(),
}) {
  return switch (kind) {
    AgentAdapterKind.codex => CodexAgentAdapterRemoteRuntimeDelegate(
      hostProbe: remoteHostProbe,
      ownerInspector: remoteOwnerInspector,
      ownerControl: remoteOwnerControl,
    ),
  };
}

ConnectionModelCatalog referenceModelCatalogForAgentAdapter(
  AgentAdapterKind kind, {
  String connectionId = 'reference',
  DateTime? fetchedAt,
}) {
  return switch (kind) {
    AgentAdapterKind.codex => codexReferenceModelCatalog(
      connectionId: connectionId,
      fetchedAt: fetchedAt,
    ),
  };
}
