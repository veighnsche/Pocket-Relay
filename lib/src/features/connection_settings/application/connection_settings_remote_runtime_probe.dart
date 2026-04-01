import 'package:pocket_relay/src/agent_adapters/agent_adapter_registry.dart';
import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';

Future<ConnectionRemoteRuntimeState> probeConnectionSettingsRemoteRuntime({
  required ConnectionSettingsSubmitPayload payload,
  String? ownerId,
  AgentAdapterRemoteRuntimeDelegate? remoteRuntimeDelegate,
  AgentAdapterRemoteRuntimeDelegateFactory? remoteRuntimeDelegateFactory,
  @Deprecated('Use remoteRuntimeDelegate instead.')
  CodexRemoteAppServerHostProbe hostProbe =
      const CodexSshRemoteAppServerHostProbe(),
  @Deprecated('Use remoteRuntimeDelegate instead.')
  CodexRemoteAppServerOwnerInspector ownerInspector =
      const CodexSshRemoteAppServerOwnerInspector(),
}) async {
  final resolvedDelegate =
      remoteRuntimeDelegate ??
      remoteRuntimeDelegateFactory?.call(payload.profile.agentAdapter) ??
      createDefaultAgentAdapterRemoteRuntimeDelegate(
        payload.profile.agentAdapter,
        remoteHostProbe: hostProbe,
        remoteOwnerInspector: ownerInspector,
      );

  return resolvedDelegate.probeRemoteRuntime(
    profile: payload.profile,
    secrets: payload.secrets,
    ownerId: ownerId,
  );
}
