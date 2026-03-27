part of 'connection_models.dart';

class WorkspaceProfile {
  const WorkspaceProfile({
    required this.label,
    required this.connectionMode,
    required this.workspaceDir,
    required this.codexPath,
    required this.dangerouslyBypassSandbox,
    required this.ephemeralSession,
    this.systemId,
    this.model = '',
    this.reasoningEffort,
  });

  final String label;
  final ConnectionMode connectionMode;
  final String? systemId;
  final String workspaceDir;
  final String codexPath;
  final bool dangerouslyBypassSandbox;
  final bool ephemeralSession;
  final String model;
  final CodexReasoningEffort? reasoningEffort;

  factory WorkspaceProfile.defaults() {
    return const WorkspaceProfile(
      label: 'Workspace',
      connectionMode: ConnectionMode.remote,
      systemId: null,
      workspaceDir: '',
      codexPath: 'codex',
      dangerouslyBypassSandbox: false,
      ephemeralSession: false,
      model: '',
      reasoningEffort: null,
    );
  }

  bool get isRemote => connectionMode == ConnectionMode.remote;
  bool get isLocal => connectionMode == ConnectionMode.local;

  bool get isReady => switch (connectionMode) {
    ConnectionMode.remote =>
      (systemId?.trim().isNotEmpty ?? false) &&
          workspaceDir.trim().isNotEmpty &&
          codexPath.trim().isNotEmpty,
    ConnectionMode.local =>
      workspaceDir.trim().isNotEmpty && codexPath.trim().isNotEmpty,
  };

  WorkspaceProfile copyWith({
    String? label,
    ConnectionMode? connectionMode,
    Object? systemId = _workspaceSentinel,
    String? workspaceDir,
    String? codexPath,
    bool? dangerouslyBypassSandbox,
    bool? ephemeralSession,
    String? model,
    Object? reasoningEffort = _workspaceSentinel,
  }) {
    return WorkspaceProfile(
      label: label ?? this.label,
      connectionMode: connectionMode ?? this.connectionMode,
      systemId: identical(systemId, _workspaceSentinel)
          ? this.systemId
          : systemId as String?,
      workspaceDir: workspaceDir ?? this.workspaceDir,
      codexPath: codexPath ?? this.codexPath,
      dangerouslyBypassSandbox:
          dangerouslyBypassSandbox ?? this.dangerouslyBypassSandbox,
      ephemeralSession: ephemeralSession ?? this.ephemeralSession,
      model: model ?? this.model,
      reasoningEffort: identical(reasoningEffort, _workspaceSentinel)
          ? this.reasoningEffort
          : reasoningEffort as CodexReasoningEffort?,
    );
  }

  factory WorkspaceProfile.fromJson(Map<String, dynamic> json) {
    final defaults = WorkspaceProfile.defaults();
    final rawSystemId = json['systemId'] as String?;
    final normalizedSystemId = rawSystemId?.trim();
    return WorkspaceProfile(
      label: json['label'] as String? ?? defaults.label,
      connectionMode: _connectionModeFromName(
        json['connectionMode'] as String?,
        fallback: defaults.connectionMode,
      ),
      systemId: normalizedSystemId == null || normalizedSystemId.isEmpty
          ? null
          : normalizedSystemId,
      workspaceDir: json['workspaceDir'] as String? ?? defaults.workspaceDir,
      codexPath: json['codexPath'] as String? ?? defaults.codexPath,
      dangerouslyBypassSandbox:
          json['dangerouslyBypassSandbox'] as bool? ??
          defaults.dangerouslyBypassSandbox,
      ephemeralSession:
          json['ephemeralSession'] as bool? ?? defaults.ephemeralSession,
      model: json['model'] as String? ?? defaults.model,
      reasoningEffort: codexReasoningEffortFromWireValue(
        json['reasoningEffort'] as String?,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label,
      'connectionMode': connectionMode.name,
      'systemId': systemId,
      'workspaceDir': workspaceDir,
      'codexPath': codexPath,
      'dangerouslyBypassSandbox': dangerouslyBypassSandbox,
      'ephemeralSession': ephemeralSession,
      'model': model,
      'reasoningEffort': reasoningEffort?.name,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceProfile &&
        other.label == label &&
        other.connectionMode == connectionMode &&
        other.systemId == systemId &&
        other.workspaceDir == workspaceDir &&
        other.codexPath == codexPath &&
        other.dangerouslyBypassSandbox == dangerouslyBypassSandbox &&
        other.ephemeralSession == ephemeralSession &&
        other.model == model &&
        other.reasoningEffort == reasoningEffort;
  }

  @override
  int get hashCode => Object.hash(
    label,
    connectionMode,
    systemId,
    workspaceDir,
    codexPath,
    dangerouslyBypassSandbox,
    ephemeralSession,
    model,
    reasoningEffort,
  );
}

class SavedWorkspaceSummary {
  const SavedWorkspaceSummary({required this.id, required this.profile});

  final String id;
  final WorkspaceProfile profile;

  SavedWorkspaceSummary copyWith({String? id, WorkspaceProfile? profile}) {
    return SavedWorkspaceSummary(
      id: id ?? this.id,
      profile: profile ?? this.profile,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SavedWorkspaceSummary &&
        other.id == id &&
        other.profile == profile;
  }

  @override
  int get hashCode => Object.hash(id, profile);
}

class SavedWorkspace {
  const SavedWorkspace({required this.id, required this.profile});

  final String id;
  final WorkspaceProfile profile;

  SavedWorkspace copyWith({String? id, WorkspaceProfile? profile}) {
    return SavedWorkspace(id: id ?? this.id, profile: profile ?? this.profile);
  }

  SavedWorkspaceSummary toSummary() {
    return SavedWorkspaceSummary(id: id, profile: profile);
  }

  @override
  bool operator ==(Object other) {
    return other is SavedWorkspace &&
        other.id == id &&
        other.profile == profile;
  }

  @override
  int get hashCode => Object.hash(id, profile);
}

class WorkspaceCatalogState {
  const WorkspaceCatalogState({
    required this.orderedWorkspaceIds,
    required this.workspacesById,
  });

  const WorkspaceCatalogState.empty()
    : orderedWorkspaceIds = const <String>[],
      workspacesById = const <String, SavedWorkspaceSummary>{};

  final List<String> orderedWorkspaceIds;
  final Map<String, SavedWorkspaceSummary> workspacesById;

  bool get isEmpty => orderedWorkspaceIds.isEmpty;
  bool get isNotEmpty => orderedWorkspaceIds.isNotEmpty;
  int get length => orderedWorkspaceIds.length;

  SavedWorkspaceSummary? workspaceForId(String workspaceId) {
    return workspacesById[workspaceId];
  }

  List<SavedWorkspaceSummary> get orderedWorkspaces {
    return <SavedWorkspaceSummary>[
      for (final workspaceId in orderedWorkspaceIds)
        if (workspacesById[workspaceId] != null) workspacesById[workspaceId]!,
    ];
  }

  WorkspaceCatalogState copyWith({
    List<String>? orderedWorkspaceIds,
    Map<String, SavedWorkspaceSummary>? workspacesById,
  }) {
    return WorkspaceCatalogState(
      orderedWorkspaceIds: orderedWorkspaceIds ?? this.orderedWorkspaceIds,
      workspacesById: workspacesById ?? this.workspacesById,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceCatalogState &&
        listEquals(other.orderedWorkspaceIds, orderedWorkspaceIds) &&
        mapEquals(other.workspacesById, workspacesById);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(orderedWorkspaceIds),
    Object.hashAll(
      workspacesById.entries.map<Object>(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );
}

const Object _workspaceSentinel = Object();

WorkspaceProfile workspaceProfileFromConnectionProfile(
  ConnectionProfile profile, {
  required String? systemId,
}) {
  final normalizedSystemId = systemId?.trim();
  return WorkspaceProfile(
    label: profile.label,
    connectionMode: profile.connectionMode,
    systemId: normalizedSystemId == null || normalizedSystemId.isEmpty
        ? null
        : normalizedSystemId,
    workspaceDir: profile.workspaceDir,
    codexPath: profile.codexPath,
    dangerouslyBypassSandbox: profile.dangerouslyBypassSandbox,
    ephemeralSession: profile.ephemeralSession,
    model: profile.model,
    reasoningEffort: profile.reasoningEffort,
  );
}

SystemProfile systemProfileFromConnectionProfile(ConnectionProfile profile) {
  return SystemProfile(
    host: profile.host,
    port: profile.port,
    username: profile.username,
    authMode: profile.authMode,
    hostFingerprint: profile.hostFingerprint,
  );
}

ConnectionProfile connectionProfileFromWorkspace({
  required WorkspaceProfile workspace,
  SavedSystem? system,
}) {
  final systemProfile = system?.profile ?? SystemProfile.defaults();
  return ConnectionProfile(
    label: workspace.label,
    host: workspace.isRemote ? systemProfile.host : '',
    port: workspace.isRemote ? systemProfile.port : 22,
    username: workspace.isRemote ? systemProfile.username : '',
    workspaceDir: workspace.workspaceDir,
    codexPath: workspace.codexPath,
    authMode: workspace.isRemote ? systemProfile.authMode : AuthMode.password,
    hostFingerprint: workspace.isRemote ? systemProfile.hostFingerprint : '',
    dangerouslyBypassSandbox: workspace.dangerouslyBypassSandbox,
    ephemeralSession: workspace.ephemeralSession,
    model: workspace.model,
    reasoningEffort: workspace.reasoningEffort,
    connectionMode: workspace.connectionMode,
  );
}

SavedConnection resolvedConnectionForWorkspace({
  required String workspaceId,
  required WorkspaceProfile workspace,
  SavedSystem? system,
}) {
  return SavedConnection(
    id: workspaceId,
    profile: connectionProfileFromWorkspace(
      workspace: workspace,
      system: system,
    ),
    secrets: system?.secrets ?? const ConnectionSecrets(),
  );
}
