import 'package:pocket_relay/src/core/models/connection_models.dart';

enum CodexRemoteAppServerCapabilityIssue { tmuxMissing, codexMissing }

class CodexRemoteAppServerHostCapabilities {
  const CodexRemoteAppServerHostCapabilities({
    this.issues = const <CodexRemoteAppServerCapabilityIssue>{},
    this.detail,
  });

  final Set<CodexRemoteAppServerCapabilityIssue> issues;
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

abstract interface class CodexRemoteAppServerOwnerControl {
  Future<CodexRemoteAppServerHostCapabilities> probeHostCapabilities({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  });

  Future<CodexRemoteAppServerOwnerSnapshot> inspectOwner({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    required String ownerId,
    required String workspaceDir,
  });

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
