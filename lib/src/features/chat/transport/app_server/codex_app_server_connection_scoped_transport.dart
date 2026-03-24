import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_local_process.dart';
import 'codex_app_server_models.dart';
import 'codex_app_server_remote_owner.dart';
import 'codex_app_server_remote_owner_ssh.dart';
import 'codex_app_server_ssh_forward.dart';
import 'codex_app_server_stdio_transport.dart';

typedef CodexRemoteContinuityTransportOpener =
    Future<CodexAppServerTransport> Function({
      required ConnectionProfile profile,
      required ConnectionSecrets secrets,
      required String remoteHost,
      required int remotePort,
      required void Function(CodexAppServerEvent event) emitEvent,
    });

CodexAppServerTransportOpener buildConnectionScopedCodexAppServerTransportOpener({
  required String ownerId,
  CodexRemoteAppServerOwnerInspector remoteOwnerInspector =
      const CodexSshRemoteAppServerOwnerInspector(),
  CodexRemoteContinuityTransportOpener remoteTransportOpener =
      openSshForwardedCodexAppServerWebSocketTransport,
  CodexAppServerProcessLauncher localLauncher = openLocalCodexAppServerProcess,
}) {
  return ({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required void Function(CodexAppServerEvent event) emitEvent,
  }) async {
    return switch (profile.connectionMode) {
      ConnectionMode.local => () async {
        final process = await localLauncher(
          profile: profile,
          secrets: secrets,
          emitEvent: emitEvent,
        );
        return CodexAppServerStdioTransport(process);
      }(),
      ConnectionMode.remote => () async {
        final snapshot = await remoteOwnerInspector.inspectOwner(
          profile: profile,
          secrets: secrets,
          ownerId: ownerId,
          workspaceDir: profile.workspaceDir,
        );
        final endpoint = snapshot.endpoint;
        if (!snapshot.isConnectable || endpoint == null) {
          throw _remoteAttachExceptionFor(snapshot);
        }
        return remoteTransportOpener(
          profile: profile,
          secrets: secrets,
          remoteHost: endpoint.host,
          remotePort: endpoint.port,
          emitEvent: emitEvent,
        );
      }(),
    };
  };
}

CodexRemoteAppServerAttachException _remoteAttachExceptionFor(
  CodexRemoteAppServerOwnerSnapshot snapshot,
) {
  final message = switch (snapshot.status) {
    CodexRemoteAppServerOwnerStatus.missing ||
    CodexRemoteAppServerOwnerStatus.stopped =>
      snapshot.detail ??
          'Remote Pocket Relay server is not running for this connection.',
    CodexRemoteAppServerOwnerStatus.unhealthy =>
      snapshot.detail ??
          'Remote Pocket Relay server is unhealthy and cannot accept websocket connections.',
    CodexRemoteAppServerOwnerStatus.running =>
      snapshot.detail ??
          'Remote Pocket Relay server reported running without a websocket endpoint.',
  };
  return CodexRemoteAppServerAttachException(
    snapshot: snapshot,
    message: message,
  );
}
