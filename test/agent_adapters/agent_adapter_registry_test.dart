import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

void main() {
  test('Codex declares the expected shared agent adapter capabilities', () {
    final capabilities = agentAdapterCapabilitiesFor(AgentAdapterKind.codex);

    expect(capabilities.supportsConversationHistory, isTrue);
    expect(capabilities.supportsConversationRollback, isTrue);
    expect(capabilities.supportsConversationForking, isTrue);
    expect(capabilities.supportsModelCatalog, isTrue);
    expect(capabilities.supportsModelCatalogRefresh, isTrue);
    expect(capabilities.supportsReasoningEffort, isTrue);
    expect(capabilities.supportsImageInput, isTrue);
    expect(capabilities.supportsApprovals, isTrue);
    expect(capabilities.supportsUserInput, isTrue);
    expect(capabilities.supportsDynamicToolCalls, isTrue);
    expect(capabilities.supportsRemoteConnections, isTrue);
    expect(capabilities.supportsRemoteContinuity, isTrue);
    expect(capabilities.supportsDangerouslyBypassSandbox, isTrue);
    expect(capabilities.supportsEphemeralSessions, isTrue);
  });
}
