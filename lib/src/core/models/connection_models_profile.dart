part of 'connection_models.dart';

class ConnectionProfile {
  ConnectionProfile({
    required this.label,
    required this.host,
    required this.port,
    required this.username,
    required this.workspaceDir,
    AgentAdapterKind agentAdapter = AgentAdapterKind.codex,
    @Deprecated('Use agentAdapter instead.') HostKind? hostKind,
    String? agentCommand,
    @Deprecated('Use agentCommand instead.') String? hostCommand,
    @Deprecated('Use hostCommand instead.') String? codexPath,
    required this.authMode,
    required this.hostFingerprint,
    required this.dangerouslyBypassSandbox,
    required this.ephemeralSession,
    this.model = '',
    this.reasoningEffort,
    this.connectionMode = ConnectionMode.remote,
  }) : agentAdapter = hostKind ?? agentAdapter,
       agentCommand =
           agentCommand ??
           hostCommand ??
           codexPath ??
           (hostKind ?? agentAdapter).defaultCommand;

  final String label;
  final String host;
  final int port;
  final String username;
  final String workspaceDir;
  final AgentAdapterKind agentAdapter;
  final String agentCommand;
  final AuthMode authMode;
  final String hostFingerprint;
  final bool dangerouslyBypassSandbox;
  final bool ephemeralSession;
  final String model;
  final AgentAdapterReasoningEffort? reasoningEffort;
  final ConnectionMode connectionMode;

  factory ConnectionProfile.defaults() {
    return ConnectionProfile(
      label: 'Developer Box',
      host: '',
      port: 22,
      username: '',
      workspaceDir: '',
      agentAdapter: AgentAdapterKind.codex,
      agentCommand: 'codex',
      authMode: AuthMode.password,
      hostFingerprint: '',
      dangerouslyBypassSandbox: false,
      ephemeralSession: false,
      model: '',
      reasoningEffort: null,
      connectionMode: ConnectionMode.remote,
    );
  }

  bool get isRemote => connectionMode == ConnectionMode.remote;
  bool get isLocal => connectionMode == ConnectionMode.local;
  @Deprecated('Use agentAdapter instead.')
  HostKind get hostKind => agentAdapter;
  @Deprecated('Use agentCommand instead.')
  String get hostCommand => agentCommand;
  @Deprecated('Use hostCommand instead.')
  String get codexPath => agentCommand;
  String? get remoteHostIdentityKey {
    if (!isRemote) {
      return null;
    }

    final normalizedHost = host.trim().toLowerCase();
    if (normalizedHost.isEmpty) {
      return null;
    }

    return '$normalizedHost:$port';
  }

  bool get isReady => switch (connectionMode) {
    ConnectionMode.remote =>
      host.trim().isNotEmpty &&
          username.trim().isNotEmpty &&
          workspaceDir.trim().isNotEmpty &&
          agentCommand.trim().isNotEmpty,
    ConnectionMode.local =>
      workspaceDir.trim().isNotEmpty && agentCommand.trim().isNotEmpty,
  };

  ConnectionProfile copyWith({
    String? label,
    String? host,
    int? port,
    String? username,
    String? workspaceDir,
    AgentAdapterKind? agentAdapter,
    @Deprecated('Use agentAdapter instead.') HostKind? hostKind,
    String? agentCommand,
    @Deprecated('Use agentCommand instead.') String? hostCommand,
    @Deprecated('Use hostCommand instead.') String? codexPath,
    AuthMode? authMode,
    String? hostFingerprint,
    bool? dangerouslyBypassSandbox,
    bool? ephemeralSession,
    String? model,
    Object? reasoningEffort = _sentinel,
    ConnectionMode? connectionMode,
  }) {
    return ConnectionProfile(
      label: label ?? this.label,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      workspaceDir: workspaceDir ?? this.workspaceDir,
      agentAdapter: agentAdapter ?? hostKind ?? this.agentAdapter,
      agentCommand:
          agentCommand ?? hostCommand ?? codexPath ?? this.agentCommand,
      authMode: authMode ?? this.authMode,
      hostFingerprint: hostFingerprint ?? this.hostFingerprint,
      dangerouslyBypassSandbox:
          dangerouslyBypassSandbox ?? this.dangerouslyBypassSandbox,
      ephemeralSession: ephemeralSession ?? this.ephemeralSession,
      model: model ?? this.model,
      reasoningEffort: identical(reasoningEffort, _sentinel)
          ? this.reasoningEffort
          : reasoningEffort as AgentAdapterReasoningEffort?,
      connectionMode: connectionMode ?? this.connectionMode,
    );
  }

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) {
    final defaults = ConnectionProfile.defaults();
    final resolvedAgentAdapter = _agentAdapterKindFromName(
      json['agentAdapter'] as String? ?? json['hostKind'] as String?,
      fallback: defaults.agentAdapter,
    );

    return ConnectionProfile(
      label: json['label'] as String? ?? defaults.label,
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 22,
      username: json['username'] as String? ?? '',
      workspaceDir: json['workspaceDir'] as String? ?? defaults.workspaceDir,
      agentAdapter: resolvedAgentAdapter,
      agentCommand:
          json['agentCommand'] as String? ??
          json['hostCommand'] as String? ??
          json['codexPath'] as String? ??
          defaultAgentAdapterCommandForKind(resolvedAgentAdapter),
      authMode: _authModeFromName(
        json['authMode'] as String?,
        fallback: defaults.authMode,
      ),
      hostFingerprint: json['hostFingerprint'] as String? ?? '',
      dangerouslyBypassSandbox:
          json['dangerouslyBypassSandbox'] as bool? ?? false,
      ephemeralSession: json['ephemeralSession'] as bool? ?? false,
      model: json['model'] as String? ?? '',
      reasoningEffort: agentAdapterReasoningEffortFromWireValue(
        json['reasoningEffort'] as String?,
      ),
      connectionMode: _connectionModeFromName(
        json['connectionMode'] as String?,
        fallback: defaults.connectionMode,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label,
      'host': host,
      'port': port,
      'username': username,
      'workspaceDir': workspaceDir,
      'agentAdapter': agentAdapter.name,
      'hostKind': agentAdapter.name,
      'agentCommand': agentCommand,
      'hostCommand': agentCommand,
      'codexPath': agentCommand,
      'authMode': authMode.name,
      'hostFingerprint': hostFingerprint,
      'dangerouslyBypassSandbox': dangerouslyBypassSandbox,
      'ephemeralSession': ephemeralSession,
      'model': model,
      'reasoningEffort': reasoningEffort?.name,
      'connectionMode': connectionMode.name,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionProfile &&
        other.label == label &&
        other.host == host &&
        other.port == port &&
        other.username == username &&
        other.workspaceDir == workspaceDir &&
        other.agentAdapter == agentAdapter &&
        other.agentCommand == agentCommand &&
        other.authMode == authMode &&
        other.hostFingerprint == hostFingerprint &&
        other.dangerouslyBypassSandbox == dangerouslyBypassSandbox &&
        other.ephemeralSession == ephemeralSession &&
        other.model == model &&
        other.reasoningEffort == reasoningEffort &&
        other.connectionMode == connectionMode;
  }

  @override
  int get hashCode => Object.hash(
    label,
    host,
    port,
    username,
    workspaceDir,
    agentAdapter,
    agentCommand,
    authMode,
    hostFingerprint,
    dangerouslyBypassSandbox,
    ephemeralSession,
    model,
    reasoningEffort,
    connectionMode,
  );
}

const Object _sentinel = Object();

class ConnectionSecrets {
  const ConnectionSecrets({
    this.password = '',
    this.privateKeyPem = '',
    this.privateKeyPassphrase = '',
  });

  final String password;
  final String privateKeyPem;
  final String privateKeyPassphrase;

  bool get hasPassword => password.trim().isNotEmpty;
  bool get hasPrivateKey => privateKeyPem.trim().isNotEmpty;

  ConnectionSecrets copyWith({
    String? password,
    String? privateKeyPem,
    String? privateKeyPassphrase,
  }) {
    return ConnectionSecrets(
      password: password ?? this.password,
      privateKeyPem: privateKeyPem ?? this.privateKeyPem,
      privateKeyPassphrase: privateKeyPassphrase ?? this.privateKeyPassphrase,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionSecrets &&
        other.password == password &&
        other.privateKeyPem == privateKeyPem &&
        other.privateKeyPassphrase == privateKeyPassphrase;
  }

  @override
  int get hashCode =>
      Object.hash(password, privateKeyPem, privateKeyPassphrase);
}
