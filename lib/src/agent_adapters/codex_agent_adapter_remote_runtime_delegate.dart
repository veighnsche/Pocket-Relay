import 'package:pocket_relay/src/agent_adapters/agent_adapter_remote_runtime_delegate.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';

class CodexAgentAdapterRemoteRuntimeDelegate
    implements AgentAdapterRemoteRuntimeDelegate {
  const CodexAgentAdapterRemoteRuntimeDelegate({
    this.hostProbe = const CodexSshRemoteAppServerHostProbe(),
    this.ownerInspector = const CodexSshRemoteAppServerOwnerInspector(),
    this.ownerControl = const CodexSshRemoteAppServerOwnerControl(),
  });

  final CodexRemoteAppServerHostProbe hostProbe;
  final CodexRemoteAppServerOwnerInspector ownerInspector;
  final CodexRemoteAppServerOwnerControl ownerControl;

  @override
  Future<ConnectionRemoteRuntimeState> probeRemoteRuntime({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    String? ownerId,
  }) async {
    if (profile.connectionMode != ConnectionMode.remote) {
      return const ConnectionRemoteRuntimeState.unknown();
    }

    final hostCapabilities = await hostProbe.probeHostCapabilities(
      profile: profile,
      secrets: secrets,
    );

    final serverState = hostCapabilities.supportsContinuity && ownerId != null
        ? (await ownerInspector.inspectOwner(
            profile: profile,
            secrets: secrets,
            ownerId: ownerId,
            workspaceDir: profile.workspaceDir,
          )).toConnectionState()
        : const ConnectionRemoteServerState.unknown();

    return ConnectionRemoteRuntimeState(
      hostCapability: hostCapabilities.toConnectionState(),
      server: serverState,
    );
  }

  @override
  Future<void> startRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  }) async {
    await ownerControl.startOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: profile.workspaceDir,
    );
  }

  @override
  Future<void> stopRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  }) async {
    await ownerControl.stopOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: profile.workspaceDir,
    );
  }

  @override
  Future<void> restartRemoteServer({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
  }) async {
    await ownerControl.restartOwner(
      profile: profile,
      secrets: secrets,
      ownerId: ownerId,
      workspaceDir: profile.workspaceDir,
    );
  }
}
