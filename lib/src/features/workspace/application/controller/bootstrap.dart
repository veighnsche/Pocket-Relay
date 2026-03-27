part of '../connection_workspace_controller.dart';

Future<void> _initializeWorkspaceController(
  ConnectionWorkspaceController controller,
) async {
  final catalog = await controller._connectionRepository.loadCatalog();
  ConnectionWorkspaceRecoveryState? recoveryState;
  PocketUserFacingError? recoveryLoadWarning;
  try {
    recoveryState = await controller._recoveryStore.load();
  } catch (error) {
    recoveryLoadWarning =
        ConnectionWorkspaceRecoveryErrors.recoveryStateLoadFailed(error: error);
  }
  controller._lastPersistedRecoveryState = recoveryState;
  if (catalog.isEmpty) {
    controller._applyState(
      const ConnectionWorkspaceState(
        isLoading: false,
        catalog: ConnectionCatalogState.empty(),
        liveConnectionIds: <String>[],
        selectedConnectionId: null,
        viewport: ConnectionWorkspaceViewport.savedConnections,
        recoveryLoadWarning: null,
        deviceContinuityWarnings: ConnectionWorkspaceDeviceContinuityWarnings(),
        savedSettingsReconnectRequiredConnectionIds: <String>{},
        transportReconnectRequiredConnectionIds: <String>{},
        transportRecoveryPhasesByConnectionId:
            <String, ConnectionWorkspaceTransportRecoveryPhase>{},
        liveReattachPhasesByConnectionId:
            <String, ConnectionWorkspaceLiveReattachPhase>{},
        recoveryDiagnosticsByConnectionId:
            <String, ConnectionWorkspaceRecoveryDiagnostics>{},
        remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{},
      ).copyWith(recoveryLoadWarning: recoveryLoadWarning),
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
      recoveryLoadWarning: recoveryLoadWarning,
      deviceContinuityWarnings:
          const ConnectionWorkspaceDeviceContinuityWarnings(),
      savedSettingsReconnectRequiredConnectionIds: const <String>{},
      transportReconnectRequiredConnectionIds: const <String>{},
      transportRecoveryPhasesByConnectionId:
          const <String, ConnectionWorkspaceTransportRecoveryPhase>{},
      liveReattachPhasesByConnectionId:
          const <String, ConnectionWorkspaceLiveReattachPhase>{},
      recoveryDiagnosticsByConnectionId: _initialWorkspaceRecoveryDiagnostics(
        connectionId: firstConnectionId,
        recoveryState: recoveryState,
      ),
      remoteRuntimeByConnectionId:
          const <String, ConnectionRemoteRuntimeState>{},
    ),
  );
  await firstBinding.sessionController.initialize();
  if (controller._isDisposed ||
      recoveryState?.connectionId != firstConnectionId ||
      recoveryState?.selectedThreadId == null) {
    return;
  }

  controller._beginRecoveryAttempt(
    firstConnectionId,
    startedAt: controller._now(),
    origin: ConnectionWorkspaceRecoveryOrigin.coldStart,
  );
  controller._applyState(
    controller._state.copyWith(
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds: <String>{
              ...controller._state.transportReconnectRequiredConnectionIds,
              firstConnectionId,
            },
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                <String, ConnectionWorkspaceTransportRecoveryPhase>{
                  ...controller._state.transportRecoveryPhasesByConnectionId,
                  firstConnectionId:
                      ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
                },
          ),
      liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
        catalog: controller._state.catalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        liveReattachPhasesByConnectionId:
            <String, ConnectionWorkspaceLiveReattachPhase>{
              ...controller._state.liveReattachPhasesByConnectionId,
              firstConnectionId:
                  ConnectionWorkspaceLiveReattachPhase.reconnecting,
            },
      ),
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: controller._state.catalog,
        liveConnectionIds: controller._state.liveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
      ),
    ),
  );
  try {
    await _connectWorkspaceBindingTransport(firstBinding);
  } on CodexRemoteAppServerAttachException catch (error) {
    if (!controller._isDisposed) {
      _applyWorkspaceRemoteAttachRuntime(
        controller,
        connectionId: firstConnectionId,
        snapshot: error.snapshot,
      );
      controller._recordFallbackTransportConnectFailure(
        firstConnectionId,
        occurredAt: controller._now(),
        error: error,
      );
      controller._setLiveReattachPhase(
        firstConnectionId,
        switch (error.snapshot.status) {
          CodexRemoteAppServerOwnerStatus.missing ||
          CodexRemoteAppServerOwnerStatus.stopped =>
            ConnectionWorkspaceLiveReattachPhase.ownerMissing,
          CodexRemoteAppServerOwnerStatus.unhealthy ||
          CodexRemoteAppServerOwnerStatus.running =>
            ConnectionWorkspaceLiveReattachPhase.ownerUnhealthy,
        },
      );
      controller._setTransportRecoveryPhase(
        firstConnectionId,
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      controller._completeRecoveryAttempt(
        firstConnectionId,
        completedAt: controller._now(),
        outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
      );
    }
    return;
  } catch (error) {
    if (!controller._isDisposed) {
      controller._recordFallbackTransportConnectFailure(
        firstConnectionId,
        occurredAt: controller._now(),
        error: error,
      );
      controller._clearLiveReattachPhase(firstConnectionId);
      controller._setTransportRecoveryPhase(
        firstConnectionId,
        ConnectionWorkspaceTransportRecoveryPhase.unavailable,
      );
      controller._completeRecoveryAttempt(
        firstConnectionId,
        completedAt: controller._now(),
        outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
      );
    }
    return;
  }

  await _recoverWorkspaceConversationAfterTransportReconnect(
    controller,
    firstConnectionId,
    firstBinding,
    threadId: recoveryState!.selectedThreadId!,
    hadVisibleConversationState: false,
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
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: nextLiveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.savedSettingsReconnectRequiredConnectionIds,
          ),
      transportReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: nextLiveConnectionIds,
            reconnectRequiredConnectionIds:
                controller._state.transportReconnectRequiredConnectionIds,
          ),
      transportRecoveryPhasesByConnectionId:
          _sanitizeWorkspaceTransportRecoveryPhases(
            catalog: controller._state.catalog,
            liveConnectionIds: nextLiveConnectionIds,
            transportRecoveryPhasesByConnectionId:
                controller._state.transportRecoveryPhasesByConnectionId,
          ),
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: controller._state.catalog,
        liveConnectionIds: nextLiveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
      ),
    ),
  );
  await binding.sessionController.initialize();
  if (controller._isDisposed) {
    return;
  }
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

Map<String, ConnectionWorkspaceRecoveryDiagnostics>
_initialWorkspaceRecoveryDiagnostics({
  required String connectionId,
  required ConnectionWorkspaceRecoveryState? recoveryState,
}) {
  if (recoveryState?.connectionId != connectionId) {
    return const <String, ConnectionWorkspaceRecoveryDiagnostics>{};
  }

  final diagnostics = ConnectionWorkspaceRecoveryDiagnostics(
    lastBackgroundedAt: recoveryState?.backgroundedAt,
    lastBackgroundedLifecycleState: recoveryState?.backgroundedLifecycleState,
  );
  if (diagnostics == const ConnectionWorkspaceRecoveryDiagnostics()) {
    return const <String, ConnectionWorkspaceRecoveryDiagnostics>{};
  }

  return <String, ConnectionWorkspaceRecoveryDiagnostics>{
    connectionId: diagnostics,
  };
}
