import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_remote_owner_ssh.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';

Future<ConnectionRemoteRuntimeState> probeConnectionSettingsRemoteRuntime({
  required ConnectionSettingsSubmitPayload payload,
  String? ownerId,
  CodexRemoteAppServerHostProbe hostProbe =
      const CodexSshRemoteAppServerHostProbe(),
  CodexRemoteAppServerOwnerInspector ownerInspector =
      const CodexSshRemoteAppServerOwnerInspector(),
}) async {
  if (payload.profile.connectionMode != ConnectionMode.remote) {
    return const ConnectionRemoteRuntimeState.unknown();
  }

  final hostCapabilities = await hostProbe.probeHostCapabilities(
    profile: payload.profile,
    secrets: payload.secrets,
  );

  final serverState = hostCapabilities.supportsContinuity && ownerId != null
      ? (await ownerInspector.inspectOwner(
          profile: payload.profile,
          secrets: payload.secrets,
          ownerId: ownerId,
          workspaceDir: payload.profile.workspaceDir,
        )).toConnectionState()
      : const ConnectionRemoteServerState.unknown();

  return ConnectionRemoteRuntimeState(
    hostCapability: hostCapabilities.toConnectionState(),
    server: serverState,
  );
}
