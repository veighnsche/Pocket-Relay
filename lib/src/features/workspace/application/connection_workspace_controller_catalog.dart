part of 'connection_workspace_controller.dart';

Future<SavedConnection> _loadWorkspaceSavedConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);
  return controller._connectionRepository.loadConnection(
    normalizedConnectionId,
  );
}

Future<String> _createWorkspaceConnection(
  ConnectionWorkspaceController controller, {
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  await controller.initialize();
  final connection = await controller._connectionRepository.createConnection(
    profile: profile,
    secrets: secrets,
  );
  final nextCatalog = await controller._connectionRepository.loadCatalog();
  if (controller._isDisposed) {
    return connection.id;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.savedSettingsReconnectRequiredConnectionIds,
          ),
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.transportReconnectRequiredConnectionIds,
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                controller._state.transportRecoveryPhasesByConnectionId,
          ),
      liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
        catalog: nextCatalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        liveReattachPhasesByConnectionId:
            controller._state.liveReattachPhasesByConnectionId,
      ),
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: nextCatalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
      ),
      remoteRuntimeByConnectionId: _sanitizeWorkspaceRemoteRuntimes(
        catalog: nextCatalog,
        remoteRuntimeByConnectionId:
            controller._state.remoteRuntimeByConnectionId,
      ),
    ),
  );
  return connection.id;
}

Future<void> _saveWorkspaceDormantConnection(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);
  if (controller._state.isConnectionLive(normalizedConnectionId)) {
    throw StateError(
      'Cannot save dormant connection settings for a live lane: '
      '$normalizedConnectionId',
    );
  }

  await controller._connectionRepository.saveConnection(
    SavedConnection(
      id: normalizedConnectionId,
      profile: profile,
      secrets: secrets,
    ),
  );

  final nextCatalog = await controller._connectionRepository.loadCatalog();
  final nextRemoteRuntimeByConnectionId =
      Map<String, ConnectionRemoteRuntimeState>.from(
        controller._state.remoteRuntimeByConnectionId,
      );
  if (profile.isLocal) {
    nextRemoteRuntimeByConnectionId.remove(normalizedConnectionId);
    controller._remoteRuntimeRefreshGenerationByConnectionId.remove(
      normalizedConnectionId,
    );
  }
  if (controller._isDisposed) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.savedSettingsReconnectRequiredConnectionIds,
          ),
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.transportReconnectRequiredConnectionIds,
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                controller._state.transportRecoveryPhasesByConnectionId,
          ),
      liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
        catalog: nextCatalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        liveReattachPhasesByConnectionId:
            controller._state.liveReattachPhasesByConnectionId,
      ),
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: nextCatalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
      ),
      remoteRuntimeByConnectionId: _sanitizeWorkspaceRemoteRuntimes(
        catalog: nextCatalog,
        remoteRuntimeByConnectionId: nextRemoteRuntimeByConnectionId,
      ),
    ),
  );
}

Future<void> _saveWorkspaceLiveConnectionEdits(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);
  if (!controller._state.isConnectionLive(normalizedConnectionId)) {
    throw StateError(
      'Cannot stage live connection edits for a dormant connection: '
      '$normalizedConnectionId',
    );
  }

  await controller._connectionRepository.saveConnection(
    SavedConnection(
      id: normalizedConnectionId,
      profile: profile,
      secrets: secrets,
    ),
  );

  final nextCatalog = await controller._connectionRepository.loadCatalog();
  final liveBinding =
      controller._liveBindingsByConnectionId[normalizedConnectionId];
  final shouldRequireReconnect =
      liveBinding == null ||
      liveBinding.sessionController.profile != profile ||
      liveBinding.sessionController.secrets != secrets;
  final nextReconnectRequiredConnectionIds = <String>{
    for (final connectionId
        in controller._state.savedSettingsReconnectRequiredConnectionIds)
      if (connectionId != normalizedConnectionId) connectionId,
    if (shouldRequireReconnect) normalizedConnectionId,
  };
  final nextRemoteRuntimeByConnectionId =
      Map<String, ConnectionRemoteRuntimeState>.from(
        controller._state.remoteRuntimeByConnectionId,
      );
  if (profile.isLocal) {
    nextRemoteRuntimeByConnectionId.remove(normalizedConnectionId);
    controller._remoteRuntimeRefreshGenerationByConnectionId.remove(
      normalizedConnectionId,
    );
  }
  if (controller._isDisposed) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds: nextReconnectRequiredConnectionIds,
          ),
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.transportReconnectRequiredConnectionIds,
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                controller._state.transportRecoveryPhasesByConnectionId,
          ),
      liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
        catalog: nextCatalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        liveReattachPhasesByConnectionId:
            controller._state.liveReattachPhasesByConnectionId,
      ),
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: nextCatalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
      ),
      remoteRuntimeByConnectionId: _sanitizeWorkspaceRemoteRuntimes(
        catalog: nextCatalog,
        remoteRuntimeByConnectionId: nextRemoteRuntimeByConnectionId,
      ),
    ),
  );
}

Future<ConnectionModelCatalog?> _loadWorkspaceConnectionModelCatalog(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);
  return controller._modelCatalogStore.load(normalizedConnectionId);
}

Future<void> _saveWorkspaceConnectionModelCatalog(
  ConnectionWorkspaceController controller,
  ConnectionModelCatalog catalog,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(
    catalog.connectionId,
  );
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);
  await controller._modelCatalogStore.save(
    ConnectionModelCatalog(
      connectionId: normalizedConnectionId,
      fetchedAt: catalog.fetchedAt,
      models: catalog.models,
    ),
  );
}

Future<ConnectionModelCatalog?> _loadWorkspaceLastKnownConnectionModelCatalog(
  ConnectionWorkspaceController controller,
) async {
  await controller.initialize();
  return controller._modelCatalogStore.loadLastKnown();
}

Future<void> _saveWorkspaceLastKnownConnectionModelCatalog(
  ConnectionWorkspaceController controller,
  ConnectionModelCatalog catalog,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(
    catalog.connectionId,
  );
  await controller.initialize();
  await controller._modelCatalogStore.saveLastKnown(
    ConnectionModelCatalog(
      connectionId: normalizedConnectionId,
      fetchedAt: catalog.fetchedAt,
      models: catalog.models,
    ),
  );
}

Future<void> _deleteWorkspaceSavedConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);
  if (controller._state.isConnectionLive(normalizedConnectionId)) {
    throw StateError(
      'Cannot delete a live connection. Close the lane first: '
      '$normalizedConnectionId',
    );
  }

  await _deleteWorkspaceSavedConnectionImpl(controller, normalizedConnectionId);
}

String _normalizeWorkspaceConnectionId(String connectionId) {
  final normalizedConnectionId = connectionId.trim();
  if (normalizedConnectionId.isEmpty) {
    throw ArgumentError.value(
      connectionId,
      'connectionId',
      'Connection id must not be empty.',
    );
  }
  return normalizedConnectionId;
}

void _requireKnownWorkspaceConnectionId(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  if (controller._state.catalog.connectionForId(connectionId) == null) {
    throw StateError('Unknown saved connection: $connectionId');
  }
}

Set<String> _sanitizeWorkspaceReconnectRequiredIds({
  required ConnectionCatalogState catalog,
  required List<String> liveConnectionIds,
  required Set<String> reconnectRequiredConnectionIds,
}) {
  final liveConnectionIdSet = liveConnectionIds.toSet();
  return <String>{
    for (final connectionId in reconnectRequiredConnectionIds)
      if (catalog.connectionForId(connectionId) != null &&
          liveConnectionIdSet.contains(connectionId))
        connectionId,
  };
}

Map<String, ConnectionWorkspaceTransportRecoveryPhase>
_sanitizeWorkspaceTransportRecoveryPhases({
  required ConnectionCatalogState catalog,
  required List<String> liveConnectionIds,
  required Map<String, ConnectionWorkspaceTransportRecoveryPhase>
  transportRecoveryPhasesByConnectionId,
}) {
  final liveConnectionIdSet = liveConnectionIds.toSet();
  return <String, ConnectionWorkspaceTransportRecoveryPhase>{
    for (final entry in transportRecoveryPhasesByConnectionId.entries)
      if (catalog.connectionForId(entry.key) != null &&
          liveConnectionIdSet.contains(entry.key))
        entry.key: entry.value,
  };
}

Map<String, ConnectionWorkspaceLiveReattachPhase>
_sanitizeWorkspaceLiveReattachPhases({
  required ConnectionCatalogState catalog,
  required List<String> liveConnectionIds,
  required Map<String, ConnectionWorkspaceLiveReattachPhase>
  liveReattachPhasesByConnectionId,
}) {
  final liveConnectionIdSet = liveConnectionIds.toSet();
  return <String, ConnectionWorkspaceLiveReattachPhase>{
    for (final entry in liveReattachPhasesByConnectionId.entries)
      if (catalog.connectionForId(entry.key) != null &&
          liveConnectionIdSet.contains(entry.key))
        entry.key: entry.value,
  };
}

Map<String, ConnectionWorkspaceRecoveryDiagnostics>
_sanitizeWorkspaceRecoveryDiagnostics({
  required ConnectionCatalogState catalog,
  required List<String> liveConnectionIds,
  required Map<String, ConnectionWorkspaceRecoveryDiagnostics>
  recoveryDiagnosticsByConnectionId,
}) {
  final liveConnectionIdSet = liveConnectionIds.toSet();
  return <String, ConnectionWorkspaceRecoveryDiagnostics>{
    for (final entry in recoveryDiagnosticsByConnectionId.entries)
      if (catalog.connectionForId(entry.key) != null &&
          liveConnectionIdSet.contains(entry.key))
        entry.key: entry.value,
  };
}

Map<String, ConnectionRemoteRuntimeState> _sanitizeWorkspaceRemoteRuntimes({
  required ConnectionCatalogState catalog,
  required Map<String, ConnectionRemoteRuntimeState>
  remoteRuntimeByConnectionId,
}) {
  return <String, ConnectionRemoteRuntimeState>{
    for (final entry in remoteRuntimeByConnectionId.entries)
      if (catalog.connectionForId(entry.key) != null) entry.key: entry.value,
  };
}

Future<ConnectionRemoteRuntimeState> _refreshWorkspaceRemoteRuntime(
  ConnectionWorkspaceController controller,
  String connectionId, {
  ConnectionProfile? profile,
  ConnectionSecrets? secrets,
}) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);

  ConnectionProfile resolvedProfile;
  ConnectionSecrets resolvedSecrets;
  if (profile != null && secrets != null) {
    resolvedProfile = profile;
    resolvedSecrets = secrets;
  } else {
    final savedConnection = await controller._connectionRepository
        .loadConnection(normalizedConnectionId);
    resolvedProfile = profile ?? savedConnection.profile;
    resolvedSecrets = secrets ?? savedConnection.secrets;
  }

  final refreshGeneration =
      (controller
              ._remoteRuntimeRefreshGenerationByConnectionId[normalizedConnectionId] ??
          0) +
      1;
  controller
          ._remoteRuntimeRefreshGenerationByConnectionId[normalizedConnectionId] =
      refreshGeneration;

  if (resolvedProfile.isLocal) {
    final nextRemoteRuntimeByConnectionId =
        Map<String, ConnectionRemoteRuntimeState>.from(
          controller._state.remoteRuntimeByConnectionId,
        )..remove(normalizedConnectionId);
    if (_canApplyWorkspaceRemoteRuntime(
      controller,
      connectionId: normalizedConnectionId,
      refreshGeneration: refreshGeneration,
    )) {
      controller._applyState(
        controller._state.copyWith(
          remoteRuntimeByConnectionId: _sanitizeWorkspaceRemoteRuntimes(
            catalog: controller._state.catalog,
            remoteRuntimeByConnectionId: nextRemoteRuntimeByConnectionId,
          ),
        ),
      );
    }
    return const ConnectionRemoteRuntimeState.unknown();
  }

  const checkingRuntime = ConnectionRemoteRuntimeState(
    hostCapability: ConnectionRemoteHostCapabilityState.checking(),
    server: ConnectionRemoteServerState.unknown(),
  );
  if (_canApplyWorkspaceRemoteRuntime(
    controller,
    connectionId: normalizedConnectionId,
    refreshGeneration: refreshGeneration,
  )) {
    controller._applyState(
      controller._state.copyWith(
        remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{
          ...controller._state.remoteRuntimeByConnectionId,
          normalizedConnectionId: checkingRuntime,
        },
      ),
    );
  }

  final nextRuntime = await _probeWorkspaceRemoteRuntime(
    controller,
    connectionId: normalizedConnectionId,
    profile: resolvedProfile,
    secrets: resolvedSecrets,
  );
  if (_canApplyWorkspaceRemoteRuntime(
    controller,
    connectionId: normalizedConnectionId,
    refreshGeneration: refreshGeneration,
  )) {
    controller._applyState(
      controller._state.copyWith(
        remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{
          ...controller._state.remoteRuntimeByConnectionId,
          normalizedConnectionId: nextRuntime,
        },
      ),
    );
  }
  return nextRuntime;
}

bool _canApplyWorkspaceRemoteRuntime(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required int refreshGeneration,
}) {
  return !controller._isDisposed &&
      controller._state.catalog.connectionForId(connectionId) != null &&
      controller._remoteRuntimeRefreshGenerationByConnectionId[connectionId] ==
          refreshGeneration;
}

Future<ConnectionRemoteRuntimeState> _probeWorkspaceRemoteRuntime(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  try {
    return await probeConnectionSettingsRemoteRuntime(
      payload: ConnectionSettingsSubmitPayload(
        profile: profile,
        secrets: secrets,
      ),
      ownerId: connectionId,
      hostProbe: controller._remoteAppServerHostProbe,
      ownerInspector: controller._remoteAppServerOwnerInspector,
    );
  } catch (error) {
    return ConnectionRemoteRuntimeState(
      hostCapability: ConnectionRemoteHostCapabilityState.probeFailed(
        detail: '$error',
      ),
      server: const ConnectionRemoteServerState.unknown(),
    );
  }
}

void _applyWorkspaceRemoteAttachRuntime(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required CodexRemoteAppServerOwnerSnapshot snapshot,
}) {
  final currentRuntime = controller._state.remoteRuntimeFor(connectionId);
  final currentHostCapability = currentRuntime?.hostCapability;
  final nextHostCapability = switch (currentHostCapability?.status) {
    null || ConnectionRemoteHostCapabilityStatus.checking =>
      const ConnectionRemoteHostCapabilityState.unknown(),
    _ => currentHostCapability!,
  };

  controller._applyState(
    controller._state.copyWith(
      remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{
        ...controller._state.remoteRuntimeByConnectionId,
        connectionId: ConnectionRemoteRuntimeState(
          hostCapability: nextHostCapability,
          server: snapshot.toConnectionState(),
        ),
      },
    ),
  );
}
