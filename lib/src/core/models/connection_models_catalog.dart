part of 'connection_models.dart';

ConnectionCatalogState resolvedConnectionCatalogFromWorkspaces({
  required WorkspaceCatalogState workspaceCatalog,
  required SystemCatalogState systemCatalog,
}) {
  return ConnectionCatalogState(
    orderedConnectionIds: List<String>.from(
      workspaceCatalog.orderedWorkspaceIds,
    ),
    connectionsById: <String, SavedConnectionSummary>{
      for (final workspaceId in workspaceCatalog.orderedWorkspaceIds)
        if (workspaceCatalog.workspaceForId(workspaceId) case final workspace?)
          workspaceId: resolvedConnectionForWorkspace(
            workspaceId: workspaceId,
            workspace: workspace.profile,
            system: _resolvedSystemForWorkspace(
              workspace.profile,
              systemCatalog: systemCatalog,
            ),
          ).toSummary(),
    },
  );
}

SavedSystem? _resolvedSystemForWorkspace(
  WorkspaceProfile workspace, {
  required SystemCatalogState systemCatalog,
}) {
  final systemId = workspace.systemId?.trim();
  if (systemId == null || systemId.isEmpty) {
    return null;
  }

  final summary = systemCatalog.systemForId(systemId);
  if (summary == null) {
    return null;
  }
  return SavedSystem(
    id: summary.id,
    profile: summary.profile,
    secrets: const ConnectionSecrets(),
  );
}

class ConnectionCatalogState {
  const ConnectionCatalogState({
    required this.orderedConnectionIds,
    required this.connectionsById,
  });

  const ConnectionCatalogState.empty()
    : orderedConnectionIds = const <String>[],
      connectionsById = const <String, SavedConnectionSummary>{};

  final List<String> orderedConnectionIds;
  final Map<String, SavedConnectionSummary> connectionsById;

  bool get isEmpty => orderedConnectionIds.isEmpty;
  bool get isNotEmpty => orderedConnectionIds.isNotEmpty;
  int get length => orderedConnectionIds.length;

  SavedConnectionSummary? connectionForId(String connectionId) {
    return connectionsById[connectionId];
  }

  List<SavedConnectionSummary> get orderedConnections {
    return <SavedConnectionSummary>[
      for (final connectionId in orderedConnectionIds)
        if (connectionsById[connectionId] != null)
          connectionsById[connectionId]!,
    ];
  }

  ConnectionCatalogState copyWith({
    List<String>? orderedConnectionIds,
    Map<String, SavedConnectionSummary>? connectionsById,
  }) {
    return ConnectionCatalogState(
      orderedConnectionIds: orderedConnectionIds ?? this.orderedConnectionIds,
      connectionsById: connectionsById ?? this.connectionsById,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionCatalogState &&
        listEquals(other.orderedConnectionIds, orderedConnectionIds) &&
        mapEquals(other.connectionsById, connectionsById);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(orderedConnectionIds),
    Object.hashAll(
      connectionsById.entries.map<Object>(
        (entry) => Object.hash(entry.key, entry.value),
      ),
    ),
  );
}
