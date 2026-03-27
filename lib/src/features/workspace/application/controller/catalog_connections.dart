part of '../connection_workspace_controller.dart';

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
  final (nextCatalog, nextSystemCatalog) = await _loadWorkspaceCatalogState(
    controller,
  );
  if (controller._isDisposed) {
    return connection.id;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      systemCatalog: nextSystemCatalog,
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

Future<void> _saveWorkspaceSavedConnection(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required ConnectionProfile profile,
  required ConnectionSecrets secrets,
}) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);
  if (controller._state.isConnectionLive(normalizedConnectionId)) {
    return _saveWorkspaceLiveConnectionEdits(
      controller,
      connectionId: normalizedConnectionId,
      profile: profile,
      secrets: secrets,
    );
  }

  return _saveWorkspaceInactiveSavedConnection(
    controller,
    connectionId: normalizedConnectionId,
    profile: profile,
    secrets: secrets,
  );
}

Future<void> _saveWorkspaceInactiveSavedConnection(
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
      'Cannot apply inactive saved-connection settings to a live lane: '
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

  final (nextCatalog, nextSystemCatalog) = await _loadWorkspaceCatalogState(
    controller,
  );
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
      systemCatalog: nextSystemCatalog,
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

  if (!profile.isRemote || controller._isDisposed) {
    return;
  }

  await _refreshWorkspaceRemoteRuntime(
    controller,
    normalizedConnectionId,
    profile: profile,
    secrets: secrets,
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
      'Cannot stage live connection edits for a non-live saved connection: '
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

  final (nextCatalog, nextSystemCatalog) = await _loadWorkspaceCatalogState(
    controller,
  );
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
      systemCatalog: nextSystemCatalog,
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

  if (!profile.isRemote || controller._isDisposed) {
    return;
  }

  await _refreshWorkspaceRemoteRuntime(
    controller,
    normalizedConnectionId,
    profile: profile,
    secrets: secrets,
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
