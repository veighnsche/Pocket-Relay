part of 'connection_workspace_controller.dart';

Future<void> _initializeWorkspaceController(
  ConnectionWorkspaceController controller,
) async {
  final catalog = await controller._connectionRepository.loadCatalog();
  if (catalog.isEmpty) {
    controller._applyState(
      const ConnectionWorkspaceState(
        isLoading: false,
        catalog: ConnectionCatalogState.empty(),
        liveConnectionIds: <String>[],
        selectedConnectionId: null,
        viewport: ConnectionWorkspaceViewport.dormantRoster,
        reconnectRequiredConnectionIds: <String>{},
      ),
    );
    return;
  }

  final firstConnectionId = catalog.orderedConnectionIds.first;
  final firstBinding = await _loadWorkspaceLaneBinding(
    controller,
    firstConnectionId,
  );
  if (controller._isDisposed) {
    firstBinding.dispose();
    return;
  }

  controller._liveBindingsByConnectionId[firstConnectionId] = firstBinding;
  controller._applyState(
    ConnectionWorkspaceState(
      isLoading: false,
      catalog: catalog,
      liveConnectionIds: <String>[firstConnectionId],
      selectedConnectionId: firstConnectionId,
      viewport: ConnectionWorkspaceViewport.liveLane,
      reconnectRequiredConnectionIds: const <String>{},
    ),
  );
}

Future<void> _instantiateWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId, {
  bool activatePersistedConversation = false,
}) async {
  final binding = await _loadWorkspaceLaneBinding(controller, connectionId);
  if (controller._isDisposed) {
    binding.dispose();
    return;
  }
  controller._liveBindingsByConnectionId[connectionId] = binding;
  final nextLiveConnectionIds = controller._orderLiveConnectionIds(
    controller._liveBindingsByConnectionId.keys,
  );
  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      liveConnectionIds: nextLiveConnectionIds,
      selectedConnectionId: connectionId,
      viewport: ConnectionWorkspaceViewport.liveLane,
      reconnectRequiredConnectionIds: controller
          ._sanitizeReconnectRequiredConnectionIds(
            catalog: controller._state.catalog,
            liveConnectionIds: nextLiveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.reconnectRequiredConnectionIds,
          ),
    ),
  );
  if (activatePersistedConversation) {
    await binding.activatePersistedConversation();
    if (controller._isDisposed) {
      return;
    }
  }
}

Future<void> _reconnectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final previousBinding = controller._liveBindingsByConnectionId[connectionId];
  if (previousBinding == null) {
    return;
  }

  final nextBinding = await _loadWorkspaceLaneBinding(controller, connectionId);
  if (controller._isDisposed) {
    nextBinding.dispose();
    return;
  }

  controller._liveBindingsByConnectionId[connectionId] = nextBinding;
  previousBinding.dispose();
  controller._applyState(
    controller._state.copyWith(
      reconnectRequiredConnectionIds: controller
          ._sanitizeReconnectRequiredConnectionIds(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds: <String>{
              for (final reconnectConnectionId
                  in controller._state.reconnectRequiredConnectionIds)
                if (reconnectConnectionId != connectionId)
                  reconnectConnectionId,
            },
          ),
    ),
  );
  await nextBinding.initializeSession();
}

Future<void> _resumeWorkspaceConversation(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required bool activatePersistedConversation,
}) async {
  if (controller._state.isConnectionLive(connectionId)) {
    final previousBinding =
        controller._liveBindingsByConnectionId[connectionId];
    if (previousBinding == null) {
      return;
    }

    final nextBinding = await _loadWorkspaceLaneBinding(
      controller,
      connectionId,
    );
    if (controller._isDisposed) {
      nextBinding.dispose();
      return;
    }
    controller._liveBindingsByConnectionId[connectionId] = nextBinding;
    controller._applyState(
      controller._state.copyWith(
        selectedConnectionId: connectionId,
        viewport: ConnectionWorkspaceViewport.liveLane,
        reconnectRequiredConnectionIds: controller
            ._sanitizeReconnectRequiredConnectionIds(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              reconnectRequiredConnectionIds: <String>{
                for (final reconnectConnectionId
                    in controller._state.reconnectRequiredConnectionIds)
                  if (reconnectConnectionId != connectionId)
                    reconnectConnectionId,
              },
            ),
      ),
    );
    previousBinding.dispose();
    await nextBinding.activatePersistedConversation();
    return;
  }

  await _instantiateWorkspaceConnection(
    controller,
    connectionId,
    activatePersistedConversation: activatePersistedConversation,
  );
}

Future<void> _deleteDormantWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  await controller._connectionConversationStateStore.deleteState(connectionId);
  await controller._connectionRepository.deleteConnection(connectionId);
  final nextCatalog = await controller._connectionRepository.loadCatalog();
  if (controller._isDisposed) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      reconnectRequiredConnectionIds: controller
          ._sanitizeReconnectRequiredConnectionIds(
            catalog: nextCatalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.reconnectRequiredConnectionIds,
          ),
    ),
  );
}

Future<ConnectionLaneBinding> _loadWorkspaceLaneBinding(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  return controller._laneBindingFactory(
    connectionId: connectionId,
    connection: await controller._connectionRepository.loadConnection(
      connectionId,
    ),
  );
}
