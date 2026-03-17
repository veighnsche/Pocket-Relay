enum AuthMode { password, privateKey }

enum ConnectionMode { remote, local }

class ConnectionProfile {
  const ConnectionProfile({
    required this.label,
    required this.host,
    required this.port,
    required this.username,
    required this.workspaceDir,
    required this.codexPath,
    required this.authMode,
    required this.hostFingerprint,
    required this.dangerouslyBypassSandbox,
    required this.ephemeralSession,
    this.connectionMode = ConnectionMode.remote,
  });

  final String label;
  final String host;
  final int port;
  final String username;
  final String workspaceDir;
  final String codexPath;
  final AuthMode authMode;
  final String hostFingerprint;
  final bool dangerouslyBypassSandbox;
  final bool ephemeralSession;
  final ConnectionMode connectionMode;

  factory ConnectionProfile.defaults() {
    return const ConnectionProfile(
      label: 'Developer Box',
      host: '',
      port: 22,
      username: '',
      workspaceDir: '/home/vince/Projects',
      codexPath: 'codex',
      authMode: AuthMode.password,
      hostFingerprint: '',
      dangerouslyBypassSandbox: false,
      ephemeralSession: false,
      connectionMode: ConnectionMode.remote,
    );
  }

  bool get isRemote => connectionMode == ConnectionMode.remote;
  bool get isLocal => connectionMode == ConnectionMode.local;

  bool get isReady => switch (connectionMode) {
    ConnectionMode.remote =>
      host.trim().isNotEmpty &&
          username.trim().isNotEmpty &&
          workspaceDir.trim().isNotEmpty &&
          codexPath.trim().isNotEmpty,
    ConnectionMode.local =>
      workspaceDir.trim().isNotEmpty && codexPath.trim().isNotEmpty,
  };

  ConnectionProfile copyWith({
    String? label,
    String? host,
    int? port,
    String? username,
    String? workspaceDir,
    String? codexPath,
    AuthMode? authMode,
    String? hostFingerprint,
    bool? dangerouslyBypassSandbox,
    bool? ephemeralSession,
    ConnectionMode? connectionMode,
  }) {
    return ConnectionProfile(
      label: label ?? this.label,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      workspaceDir: workspaceDir ?? this.workspaceDir,
      codexPath: codexPath ?? this.codexPath,
      authMode: authMode ?? this.authMode,
      hostFingerprint: hostFingerprint ?? this.hostFingerprint,
      dangerouslyBypassSandbox:
          dangerouslyBypassSandbox ?? this.dangerouslyBypassSandbox,
      ephemeralSession: ephemeralSession ?? this.ephemeralSession,
      connectionMode: connectionMode ?? this.connectionMode,
    );
  }

  factory ConnectionProfile.fromJson(Map<String, dynamic> json) {
    final defaults = ConnectionProfile.defaults();

    return ConnectionProfile(
      label: json['label'] as String? ?? defaults.label,
      host: json['host'] as String? ?? '',
      port: (json['port'] as num?)?.toInt() ?? 22,
      username: json['username'] as String? ?? '',
      workspaceDir: json['workspaceDir'] as String? ?? defaults.workspaceDir,
      codexPath: json['codexPath'] as String? ?? defaults.codexPath,
      authMode: _authModeFromName(
        json['authMode'] as String?,
        fallback: defaults.authMode,
      ),
      hostFingerprint: json['hostFingerprint'] as String? ?? '',
      dangerouslyBypassSandbox:
          json['dangerouslyBypassSandbox'] as bool? ?? false,
      ephemeralSession: json['ephemeralSession'] as bool? ?? false,
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
      'codexPath': codexPath,
      'authMode': authMode.name,
      'hostFingerprint': hostFingerprint,
      'dangerouslyBypassSandbox': dangerouslyBypassSandbox,
      'ephemeralSession': ephemeralSession,
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
        other.codexPath == codexPath &&
        other.authMode == authMode &&
        other.hostFingerprint == hostFingerprint &&
        other.dangerouslyBypassSandbox == dangerouslyBypassSandbox &&
        other.ephemeralSession == ephemeralSession &&
        other.connectionMode == connectionMode;
  }

  @override
  int get hashCode => Object.hash(
    label,
    host,
    port,
    username,
    workspaceDir,
    codexPath,
    authMode,
    hostFingerprint,
    dangerouslyBypassSandbox,
    ephemeralSession,
    connectionMode,
  );
}

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

class SavedProfile {
  const SavedProfile({required this.profile, required this.secrets});

  final ConnectionProfile profile;
  final ConnectionSecrets secrets;

  SavedProfile copyWith({
    ConnectionProfile? profile,
    ConnectionSecrets? secrets,
  }) {
    return SavedProfile(
      profile: profile ?? this.profile,
      secrets: secrets ?? this.secrets,
    );
  }
}

AuthMode _authModeFromName(String? value, {required AuthMode fallback}) {
  for (final mode in AuthMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }

  return fallback;
}

ConnectionMode _connectionModeFromName(
  String? value, {
  required ConnectionMode fallback,
}) {
  for (final mode in ConnectionMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }

  return fallback;
}
