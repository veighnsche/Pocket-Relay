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
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: nextCatalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
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
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: nextCatalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
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
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: nextCatalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
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

Future<void> _deleteWorkspaceDormantConnection(
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

  await _deleteDormantWorkspaceConnection(controller, normalizedConnectionId);
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
