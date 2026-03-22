part of 'connection_workspace_controller.dart';

Future<void> _initializeWorkspaceController(
  ConnectionWorkspaceController controller,
) async {
  final catalog = await controller._connectionRepository.loadCatalog();
  final recoveryState = await controller._recoveryStore.load();
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

  final restoredConnectionId = recoveryState?.connectionId;
  final firstConnectionId =
      restoredConnectionId != null &&
          catalog.connectionForId(restoredConnectionId) != null
      ? restoredConnectionId
      : catalog.orderedConnectionIds.first;
  final firstBinding = await _loadWorkspaceLaneBinding(
    controller,
    firstConnectionId,
    initialDraftText: recoveryState?.connectionId == firstConnectionId
        ? recoveryState?.draftText
        : null,
  );
  if (controller._isDisposed) {
    firstBinding.dispose();
    return;
  }

  controller._liveBindingsByConnectionId[firstConnectionId] = firstBinding;
  controller._registerLiveBinding(firstConnectionId, firstBinding);
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
  await firstBinding.sessionController.initialize();
  if (controller._isDisposed ||
      recoveryState?.connectionId != firstConnectionId ||
      recoveryState?.selectedThreadId == null) {
    return;
  }

  await firstBinding.sessionController.selectConversationForResume(
    recoveryState!.selectedThreadId!,
  );
}

Future<void> _instantiateWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final binding = await _loadWorkspaceLaneBinding(controller, connectionId);
  if (controller._isDisposed) {
    binding.dispose();
    return;
  }
  controller._liveBindingsByConnectionId[connectionId] = binding;
  controller._registerLiveBinding(connectionId, binding);
  final nextLiveConnectionIds = _orderWorkspaceLiveConnectionIds(
    controller,
    controller._liveBindingsByConnectionId.keys,
  );
  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      liveConnectionIds: nextLiveConnectionIds,
      selectedConnectionId: connectionId,
      viewport: ConnectionWorkspaceViewport.liveLane,
      reconnectRequiredConnectionIds: _sanitizeWorkspaceReconnectRequiredIds(
        catalog: controller._state.catalog,
        liveConnectionIds: nextLiveConnectionIds,
        reconnectRequiredConnectionIds:
            controller._state.reconnectRequiredConnectionIds,
      ),
    ),
  );
  await binding.sessionController.initialize();
  if (controller._isDisposed) {
    return;
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

  final preservedLaneState = _preservedWorkspaceLaneState(previousBinding);
  final nextBinding = await _loadWorkspaceLaneBinding(
    controller,
    connectionId,
    initialDraftText: preservedLaneState.draftText,
  );
  if (controller._isDisposed) {
    nextBinding.dispose();
    return;
  }

  controller._liveBindingsByConnectionId[connectionId] = nextBinding;
  controller._unregisterLiveBinding(connectionId);
  controller._registerLiveBinding(connectionId, nextBinding);
  previousBinding.dispose();
  controller._applyState(
    controller._state.copyWith(
      reconnectRequiredConnectionIds: _sanitizeWorkspaceReconnectRequiredIds(
        catalog: controller._state.catalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        reconnectRequiredConnectionIds: <String>{
          for (final reconnectConnectionId
              in controller._state.reconnectRequiredConnectionIds)
            if (reconnectConnectionId != connectionId) reconnectConnectionId,
        },
      ),
    ),
  );
  await nextBinding.sessionController.initialize();
  if (controller._isDisposed) {
    return;
  }
  if (preservedLaneState.threadId != null) {
    await nextBinding.sessionController.selectConversationForResume(
      preservedLaneState.threadId!,
    );
    return;
  }
}

Future<void> _resumeWorkspaceConversation(
  ConnectionWorkspaceController controller,
  String connectionId, {
  required String threadId,
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
    controller._unregisterLiveBinding(connectionId);
    controller._registerLiveBinding(connectionId, nextBinding);
    final didNotifyStateChange = controller._applyState(
      controller._state.copyWith(
        selectedConnectionId: connectionId,
        viewport: ConnectionWorkspaceViewport.liveLane,
        reconnectRequiredConnectionIds: _sanitizeWorkspaceReconnectRequiredIds(
          catalog: controller._state.catalog,
          liveConnectionIds: controller._state.liveConnectionIds,
          reconnectRequiredConnectionIds: <String>{
            for (final reconnectConnectionId
                in controller._state.reconnectRequiredConnectionIds)
              if (reconnectConnectionId != connectionId) reconnectConnectionId,
          },
        ),
      ),
    );
    previousBinding.dispose();
    if (!didNotifyStateChange) {
      controller._notifyBindingChange();
    }
    await nextBinding.sessionController.initialize();
    if (controller._isDisposed) {
      return;
    }
    await nextBinding.sessionController.selectConversationForResume(threadId);
    return;
  }

  await _instantiateWorkspaceConnection(controller, connectionId);
  if (controller._isDisposed) {
    return;
  }

  final binding = controller._liveBindingsByConnectionId[connectionId];
  if (binding == null) {
    return;
  }

  await binding.sessionController.selectConversationForResume(threadId);
}

Future<void> _deleteDormantWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  await controller._connectionRepository.deleteConnection(connectionId);
  final nextCatalog = await controller._connectionRepository.loadCatalog();
  if (controller._isDisposed) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      catalog: nextCatalog,
      reconnectRequiredConnectionIds: _sanitizeWorkspaceReconnectRequiredIds(
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
  String connectionId, {
  String? initialDraftText,
}) async {
  final binding = controller._laneBindingFactory(
    connectionId: connectionId,
    connection: await controller._connectionRepository.loadConnection(
      connectionId,
    ),
  );
  if (initialDraftText != null && initialDraftText.isNotEmpty) {
    binding.restoreComposerDraft(initialDraftText);
  }
  return binding;
}

Future<void> _handleWorkspaceAppLifecycleState(
  ConnectionWorkspaceController controller,
  AppLifecycleState state,
) async {
  switch (state) {
    case AppLifecycleState.inactive:
      await controller._enqueueRecoveryPersistence(
        backgroundedAt: controller._now(),
      );
      return;
    case AppLifecycleState.hidden:
    case AppLifecycleState.paused:
      controller._backgroundReconnectPending =
          controller.selectedLaneBinding != null;
      await controller._enqueueRecoveryPersistence(
        backgroundedAt: controller._now(),
      );
      return;
    case AppLifecycleState.resumed:
      if (!controller._backgroundReconnectPending) {
        return;
      }
      if (controller._lifecycleReconnectFuture != null) {
        await controller._lifecycleReconnectFuture;
        return;
      }
      final future = _restoreWorkspaceAfterBackground(controller);
      controller._lifecycleReconnectFuture = future.whenComplete(() {
        controller._lifecycleReconnectFuture = null;
      });
      await controller._lifecycleReconnectFuture;
      return;
    case AppLifecycleState.detached:
      return;
  }
}

Future<void> _restoreWorkspaceAfterBackground(
  ConnectionWorkspaceController controller,
) async {
  controller._backgroundReconnectPending = false;
  final selectedConnectionId = controller._state.selectedConnectionId;
  final liveConnectionIds = controller._state.liveConnectionIds;
  if (selectedConnectionId == null || liveConnectionIds.isEmpty) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      reconnectRequiredConnectionIds: liveConnectionIds.toSet(),
    ),
  );

  if (!controller._state.isConnectionLive(selectedConnectionId)) {
    return;
  }

  await _reconnectWorkspaceConnection(controller, selectedConnectionId);
}

({String? threadId, String draftText}) _preservedWorkspaceLaneState(
  ConnectionLaneBinding binding,
) {
  return (
    threadId: _normalizedWorkspaceThreadId(
      binding.sessionController.sessionState.currentThreadId ??
          binding.sessionController.sessionState.rootThreadId ??
          binding
              .sessionController
              .historicalConversationRestoreState
              ?.threadId,
    ),
    draftText: binding.composerDraftHost.draft.text,
  );
}

String? _normalizedWorkspaceThreadId(String? value) {
  final normalizedValue = value?.trim();
  if (normalizedValue == null || normalizedValue.isEmpty) {
    return null;
  }
  return normalizedValue;
}
