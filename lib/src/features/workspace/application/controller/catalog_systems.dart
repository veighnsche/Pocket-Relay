part of '../connection_workspace_controller.dart';

Future<(ConnectionCatalogState, SystemCatalogState)> _loadWorkspaceCatalogState(
  ConnectionWorkspaceController controller,
) async {
  final catalog = await controller._connectionRepository.loadCatalog();
  final systemCatalog = await controller._connectionRepository
      .loadSystemCatalog();
  return (catalog, systemCatalog);
}

Future<SavedSystem> _loadWorkspaceSavedSystem(
  ConnectionWorkspaceController controller,
  String systemId,
) async {
  final normalizedSystemId = _normalizeSavedSystemId(systemId);
  await controller.initialize();
  return controller._connectionRepository.loadSystem(normalizedSystemId);
}

Future<String> _createWorkspaceSystem(
  ConnectionWorkspaceController controller, {
  required SystemProfile profile,
  required ConnectionSecrets secrets,
}) async {
  await controller.initialize();
  final system = await controller._connectionRepository.createSystem(
    profile: profile,
    secrets: secrets,
  );
  final (nextCatalog, nextSystemCatalog) = await _loadWorkspaceCatalogState(
    controller,
  );
  if (controller._isDisposed) {
    return system.id;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      systemCatalog: nextSystemCatalog,
    ),
  );
  return system.id;
}

Future<void> _saveWorkspaceSavedSystem(
  ConnectionWorkspaceController controller, {
  required String systemId,
  required SystemProfile profile,
  required ConnectionSecrets secrets,
}) async {
  final normalizedSystemId = _normalizeSavedSystemId(systemId);
  await controller.initialize();
  await controller._connectionRepository.saveSystem(
    SavedSystem(id: normalizedSystemId, profile: profile, secrets: secrets),
  );
  final (nextCatalog, nextSystemCatalog) = await _loadWorkspaceCatalogState(
    controller,
  );
  if (controller._isDisposed) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      systemCatalog: nextSystemCatalog,
      remoteRuntimeByConnectionId: _sanitizeWorkspaceRemoteRuntimes(
        catalog: nextCatalog,
        remoteRuntimeByConnectionId:
            controller._state.remoteRuntimeByConnectionId,
      ),
    ),
  );
}

Future<void> _deleteWorkspaceSavedSystem(
  ConnectionWorkspaceController controller,
  String systemId,
) async {
  final normalizedSystemId = _normalizeSavedSystemId(systemId);
  await controller.initialize();
  await controller._connectionRepository.deleteSystem(normalizedSystemId);
  final (nextCatalog, nextSystemCatalog) = await _loadWorkspaceCatalogState(
    controller,
  );
  if (controller._isDisposed) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      systemCatalog: nextSystemCatalog,
      remoteRuntimeByConnectionId: _sanitizeWorkspaceRemoteRuntimes(
        catalog: nextCatalog,
        remoteRuntimeByConnectionId:
            controller._state.remoteRuntimeByConnectionId,
      ),
    ),
  );
}

void _showWorkspaceSavedSystems(ConnectionWorkspaceController controller) {
  if (controller._state.isShowingSavedSystems) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      viewport: ConnectionWorkspaceViewport.savedSystems,
    ),
  );
}

String _normalizeSavedSystemId(String systemId) {
  final normalizedSystemId = systemId.trim();
  if (normalizedSystemId.isEmpty) {
    throw ArgumentError.value(
      systemId,
      'systemId',
      'System id must not be empty.',
    );
  }
  return normalizedSystemId;
}
