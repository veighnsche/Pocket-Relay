import 'package:pocket_relay/src/core/models/connection_models.dart';

import 'codex_app_server_models.dart';

class CodexRemoteAppServerHostCapabilities {
  const CodexRemoteAppServerHostCapabilities({
    this.issues = const <ConnectionRemoteHostCapabilityIssue>{},
    this.detail,
  });

  final Set<ConnectionRemoteHostCapabilityIssue> issues;
  final String? detail;

  bool get supportsContinuity => issues.isEmpty;
}

class CodexRemoteAppServerEndpoint {
  const CodexRemoteAppServerEndpoint({required this.host, required this.port});

  final String host;
  final int port;
}

enum CodexRemoteAppServerOwnerStatus { missing, stopped, running, unhealthy }

class CodexRemoteAppServerOwnerSnapshot {
  const CodexRemoteAppServerOwnerSnapshot({
    required this.ownerId,
    required this.workspaceDir,
    required this.status,
    this.sessionName,
    this.pid,
    this.endpoint,
    this.detail,
  });

  final String ownerId;
  final String workspaceDir;
  final CodexRemoteAppServerOwnerStatus status;
  final String? sessionName;
  final int? pid;
  final CodexRemoteAppServerEndpoint? endpoint;
  final String? detail;

  bool get isConnectable =>
      status == CodexRemoteAppServerOwnerStatus.running && endpoint != null;
}

class CodexRemoteAppServerAttachException extends CodexAppServerException {
  const CodexRemoteAppServerAttachException({
    required this.snapshot,
    required String message,
  }) : super(message);

  final CodexRemoteAppServerOwnerSnapshot snapshot;
}

extension CodexRemoteAppServerHostCapabilitiesMapping
    on CodexRemoteAppServerHostCapabilities {
  ConnectionRemoteHostCapabilityState toConnectionState() {
    if (issues.isEmpty) {
      return ConnectionRemoteHostCapabilityState.supported(detail: detail);
    }
    return ConnectionRemoteHostCapabilityState.unsupported(
      issues: issues,
      detail: detail,
    );
  }
}

extension CodexRemoteAppServerOwnerSnapshotMapping
    on CodexRemoteAppServerOwnerSnapshot {
  ConnectionRemoteServerState toConnectionState() {
    return switch (status) {
      CodexRemoteAppServerOwnerStatus.missing ||
      CodexRemoteAppServerOwnerStatus.stopped =>
        ConnectionRemoteServerState.notRunning(
          ownerId: ownerId,
          sessionName: sessionName,
          detail: detail,
        ),
      CodexRemoteAppServerOwnerStatus.unhealthy =>
        ConnectionRemoteServerState.unhealthy(
          ownerId: ownerId,
          sessionName: sessionName,
          port: endpoint?.port,
          detail: detail,
        ),
      CodexRemoteAppServerOwnerStatus.running =>
        endpoint == null
            ? ConnectionRemoteServerState.unhealthy(
                ownerId: ownerId,
                sessionName: sessionName,
                detail:
                    detail ??
                    'Remote Pocket Relay server reported running without a websocket endpoint.',
              )
            : ConnectionRemoteServerState.running(
                ownerId: ownerId,
                sessionName: sessionName,
                port: endpoint!.port,
                detail: detail,
              ),
    };
  }
}

abstract interface class CodexRemoteAppServerHostProbe {
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  });
}

abstract interface class CodexRemoteAppServerOwnerInspector
    implements CodexRemoteAppServerHostProbe {
  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  });
}

abstract interface class CodexRemoteAppServerOwnerControl
    implements CodexRemoteAppServerOwnerInspector {
  Future<CodexRemoteAppServerOwnerSnapshot> startOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  });

  Future<CodexRemoteAppServerOwnerSnapshot> stopOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  });

  Future<CodexRemoteAppServerOwnerSnapshot> restartOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  });
}
