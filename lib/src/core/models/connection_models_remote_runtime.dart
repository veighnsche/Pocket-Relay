part of 'connection_models.dart';

enum ConnectionRemoteHostCapabilityStatus {
  unknown,
  checking,
  probeFailed,
  supported,
  unsupported,
}

enum ConnectionRemoteHostCapabilityIssue {
  tmuxMissing,
  workspaceUnavailable,
  codexMissing,
}

@immutable
class ConnectionRemoteHostCapabilityState {
  const ConnectionRemoteHostCapabilityState({
    required this.status,
    this.issues = const <ConnectionRemoteHostCapabilityIssue>{},
    this.detail,
  });

  const ConnectionRemoteHostCapabilityState.unknown()
    : status = ConnectionRemoteHostCapabilityStatus.unknown,
      issues = const <ConnectionRemoteHostCapabilityIssue>{},
      detail = null;

  const ConnectionRemoteHostCapabilityState.checking()
    : status = ConnectionRemoteHostCapabilityStatus.checking,
      issues = const <ConnectionRemoteHostCapabilityIssue>{},
      detail = null;

  const ConnectionRemoteHostCapabilityState.probeFailed({this.detail})
    : status = ConnectionRemoteHostCapabilityStatus.probeFailed,
      issues = const <ConnectionRemoteHostCapabilityIssue>{};

  const ConnectionRemoteHostCapabilityState.supported({this.detail})
    : status = ConnectionRemoteHostCapabilityStatus.supported,
      issues = const <ConnectionRemoteHostCapabilityIssue>{};

  const ConnectionRemoteHostCapabilityState.unsupported({
    required this.issues,
    this.detail,
  }) : status = ConnectionRemoteHostCapabilityStatus.unsupported;

  final ConnectionRemoteHostCapabilityStatus status;
  final Set<ConnectionRemoteHostCapabilityIssue> issues;
  final String? detail;

  bool get isSupported =>
      status == ConnectionRemoteHostCapabilityStatus.supported;

  bool get isUnsupported =>
      status == ConnectionRemoteHostCapabilityStatus.unsupported;

  bool get didProbeFail =>
      status == ConnectionRemoteHostCapabilityStatus.probeFailed;

  @override
  bool operator ==(Object other) {
    return other is ConnectionRemoteHostCapabilityState &&
        other.status == status &&
        setEquals(other.issues, issues) &&
        other.detail == detail;
  }

  @override
  int get hashCode =>
      Object.hash(status, Object.hashAllUnordered(issues), detail);
}

enum ConnectionRemoteServerStatus {
  unknown,
  checking,
  notRunning,
  unhealthy,
  running,
}

@immutable
class ConnectionRemoteServerState {
  const ConnectionRemoteServerState({
    required this.status,
    this.ownerId,
    this.sessionName,
    this.port,
    this.detail,
  });

  const ConnectionRemoteServerState.unknown()
    : status = ConnectionRemoteServerStatus.unknown,
      ownerId = null,
      sessionName = null,
      port = null,
      detail = null;

  const ConnectionRemoteServerState.checking({
    this.ownerId,
    this.sessionName,
    this.detail,
  }) : status = ConnectionRemoteServerStatus.checking,
       port = null;

  const ConnectionRemoteServerState.notRunning({
    this.ownerId,
    this.sessionName,
    this.detail,
  }) : status = ConnectionRemoteServerStatus.notRunning,
       port = null;

  const ConnectionRemoteServerState.unhealthy({
    this.ownerId,
    this.sessionName,
    this.port,
    this.detail,
  }) : status = ConnectionRemoteServerStatus.unhealthy;

  const ConnectionRemoteServerState.running({
    this.ownerId,
    this.sessionName,
    required this.port,
    this.detail,
  }) : status = ConnectionRemoteServerStatus.running;

  final ConnectionRemoteServerStatus status;
  final String? ownerId;
  final String? sessionName;
  final int? port;
  final String? detail;

  bool get isConnectable =>
      status == ConnectionRemoteServerStatus.running && port != null;

  @override
  bool operator ==(Object other) {
    return other is ConnectionRemoteServerState &&
        other.status == status &&
        other.ownerId == ownerId &&
        other.sessionName == sessionName &&
        other.port == port &&
        other.detail == detail;
  }

  @override
  int get hashCode => Object.hash(status, ownerId, sessionName, port, detail);
}

@immutable
class ConnectionRemoteRuntimeState {
  const ConnectionRemoteRuntimeState({
    required this.hostCapability,
    required this.server,
  });

  const ConnectionRemoteRuntimeState.unknown()
    : hostCapability = const ConnectionRemoteHostCapabilityState.unknown(),
      server = const ConnectionRemoteServerState.unknown();

  final ConnectionRemoteHostCapabilityState hostCapability;
  final ConnectionRemoteServerState server;

  ConnectionRemoteRuntimeState copyWith({
    ConnectionRemoteHostCapabilityState? hostCapability,
    ConnectionRemoteServerState? server,
  }) {
    return ConnectionRemoteRuntimeState(
      hostCapability: hostCapability ?? this.hostCapability,
      server: server ?? this.server,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionRemoteRuntimeState &&
        other.hostCapability == hostCapability &&
        other.server == server;
  }

  @override
  int get hashCode => Object.hash(hostCapability, server);
}
