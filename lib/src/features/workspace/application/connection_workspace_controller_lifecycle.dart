part of 'connection_workspace_controller.dart';

Future<void> _initializeWorkspaceController(
  ConnectionWorkspaceController controller,
) async {
  final catalog = await controller._connectionRepository.loadCatalog();
  final recoveryState = await controller._recoveryStore.load();
  controller._lastPersistedRecoveryState = recoveryState;
  if (catalog.isEmpty) {
    controller._applyState(
      const ConnectionWorkspaceState(
        isLoading: false,
        catalog: ConnectionCatalogState.empty(),
        liveConnectionIds: <String>[],
        selectedConnectionId: null,
        viewport: ConnectionWorkspaceViewport.savedConnections,
        savedSettingsReconnectRequiredConnectionIds: <String>{},
        transportReconnectRequiredConnectionIds: <String>{},
        transportRecoveryPhasesByConnectionId:
            <String, ConnectionWorkspaceTransportRecoveryPhase>{},
        liveReattachPhasesByConnectionId:
            <String, ConnectionWorkspaceLiveReattachPhase>{},
        recoveryDiagnosticsByConnectionId:
            <String, ConnectionWorkspaceRecoveryDiagnostics>{},
        remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{},
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
  } catch (_) {
    if (!controller._isDisposed) {
      controller._recordFallbackTransportConnectFailure(
        firstConnectionId,
        occurredAt: controller._now(),
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

Future<void> _reconnectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final previousBinding = controller._liveBindingsByConnectionId[connectionId];
  if (previousBinding == null) {
    return;
  }
  if (previousBinding.sessionController.sessionState.isBusy) {
    return;
  }

  final reconnectRequirement = controller._state.reconnectRequirementFor(
    connectionId,
  );
  if (reconnectRequirement == null) {
    return;
  }
  final shouldReconnectTransport =
      reconnectRequirement ==
          ConnectionWorkspaceReconnectRequirement.transport ||
      reconnectRequirement ==
          ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings;
  final shouldReplaceBinding =
      reconnectRequirement ==
          ConnectionWorkspaceReconnectRequirement.savedSettings ||
      reconnectRequirement ==
          ConnectionWorkspaceReconnectRequirement.transportWithSavedSettings;

  if (!shouldReplaceBinding) {
    final preservedLaneState = _preservedWorkspaceLaneState(previousBinding);
    controller._applyState(
      controller._state.copyWith(
        transportRecoveryPhasesByConnectionId: shouldReconnectTransport
            ? _sanitizeWorkspaceTransportRecoveryPhases(
                catalog: controller._state.catalog,
                liveConnectionIds: controller._state.liveConnectionIds,
                transportRecoveryPhasesByConnectionId:
                    <String, ConnectionWorkspaceTransportRecoveryPhase>{
                      ...controller
                          ._state
                          .transportRecoveryPhasesByConnectionId,
                      connectionId: ConnectionWorkspaceTransportRecoveryPhase
                          .reconnecting,
                    },
              )
            : controller._state.transportRecoveryPhasesByConnectionId,
        liveReattachPhasesByConnectionId: shouldReconnectTransport
            ? _sanitizeWorkspaceLiveReattachPhases(
                catalog: controller._state.catalog,
                liveConnectionIds: controller._state.liveConnectionIds,
                liveReattachPhasesByConnectionId:
                    <String, ConnectionWorkspaceLiveReattachPhase>{
                      ...controller._state.liveReattachPhasesByConnectionId,
                      connectionId:
                          ConnectionWorkspaceLiveReattachPhase.reconnecting,
                    },
              )
            : controller._state.liveReattachPhasesByConnectionId,
      ),
    );
    if (!shouldReconnectTransport) {
      return;
    }

    try {
      await _connectWorkspaceBindingTransport(previousBinding);
    } on CodexRemoteAppServerAttachException catch (error) {
      if (!controller._isDisposed) {
        _applyWorkspaceRemoteAttachRuntime(
          controller,
          connectionId: connectionId,
          snapshot: error.snapshot,
        );
        controller._recordFallbackTransportConnectFailure(
          connectionId,
          occurredAt: controller._now(),
        );
        controller._setLiveReattachPhase(
          connectionId,
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
          connectionId,
          ConnectionWorkspaceTransportRecoveryPhase.unavailable,
        );
        controller._completeRecoveryAttempt(
          connectionId,
          completedAt: controller._now(),
          outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
        );
      }
      return;
    } catch (_) {
      if (!controller._isDisposed) {
        controller._recordFallbackTransportConnectFailure(
          connectionId,
          occurredAt: controller._now(),
        );
        controller._clearLiveReattachPhase(connectionId);
        controller._setTransportRecoveryPhase(
          connectionId,
          ConnectionWorkspaceTransportRecoveryPhase.unavailable,
        );
        controller._completeRecoveryAttempt(
          connectionId,
          completedAt: controller._now(),
          outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
        );
      }
      return;
    }
    if (controller._isDisposed || preservedLaneState.threadId == null) {
      return;
    }

    await _recoverWorkspaceConversationAfterTransportReconnect(
      controller,
      connectionId,
      previousBinding,
      threadId: preservedLaneState.threadId!,
      hadVisibleConversationState:
          _workspaceLaneHasVisibleLiveConversationState(previousBinding),
    );
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
      savedSettingsReconnectRequiredConnectionIds:
          _sanitizeWorkspaceReconnectRequiredIds(
            catalog: controller._state.catalog,
            liveConnectionIds: controller._state.liveConnectionIds,
            reconnectRequiredConnectionIds: <String>{
              ...controller._state.savedSettingsReconnectRequiredConnectionIds,
            }..remove(connectionId),
          ),
      transportReconnectRequiredConnectionIds: shouldReconnectTransport
          ? controller._state.transportReconnectRequiredConnectionIds
          : _sanitizeWorkspaceReconnectRequiredIds(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              reconnectRequiredConnectionIds: <String>{
                ...controller._state.transportReconnectRequiredConnectionIds,
              }..remove(connectionId),
            ),
      transportRecoveryPhasesByConnectionId: shouldReconnectTransport
          ? _sanitizeWorkspaceTransportRecoveryPhases(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              transportRecoveryPhasesByConnectionId:
                  <String, ConnectionWorkspaceTransportRecoveryPhase>{
                    ...controller._state.transportRecoveryPhasesByConnectionId,
                    connectionId:
                        ConnectionWorkspaceTransportRecoveryPhase.reconnecting,
                  },
            )
          : _sanitizeWorkspaceTransportRecoveryPhases(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              transportRecoveryPhasesByConnectionId:
                  <String, ConnectionWorkspaceTransportRecoveryPhase>{
                    for (final entry
                        in controller
                            ._state
                            .transportRecoveryPhasesByConnectionId
                            .entries)
                      if (entry.key != connectionId) entry.key: entry.value,
                  },
            ),
      liveReattachPhasesByConnectionId: shouldReconnectTransport
          ? _sanitizeWorkspaceLiveReattachPhases(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              liveReattachPhasesByConnectionId:
                  <String, ConnectionWorkspaceLiveReattachPhase>{
                    ...controller._state.liveReattachPhasesByConnectionId,
                    connectionId:
                        ConnectionWorkspaceLiveReattachPhase.reconnecting,
                  },
            )
          : _sanitizeWorkspaceLiveReattachPhases(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              liveReattachPhasesByConnectionId:
                  <String, ConnectionWorkspaceLiveReattachPhase>{
                    for (final entry
                        in controller
                            ._state
                            .liveReattachPhasesByConnectionId
                            .entries)
                      if (entry.key != connectionId) entry.key: entry.value,
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
  await nextBinding.sessionController.initialize();
  if (controller._isDisposed) {
    return;
  }
  if (shouldReconnectTransport) {
    try {
      await _connectWorkspaceBindingTransport(nextBinding);
    } on CodexRemoteAppServerAttachException catch (error) {
      if (!controller._isDisposed) {
        _applyWorkspaceRemoteAttachRuntime(
          controller,
          connectionId: connectionId,
          snapshot: error.snapshot,
        );
        controller._recordFallbackTransportConnectFailure(
          connectionId,
          occurredAt: controller._now(),
        );
        controller._setLiveReattachPhase(
          connectionId,
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
          connectionId,
          ConnectionWorkspaceTransportRecoveryPhase.unavailable,
        );
        controller._completeRecoveryAttempt(
          connectionId,
          completedAt: controller._now(),
          outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
        );
      }
      return;
    } catch (_) {
      if (!controller._isDisposed) {
        controller._recordFallbackTransportConnectFailure(
          connectionId,
          occurredAt: controller._now(),
        );
        controller._clearLiveReattachPhase(connectionId);
        controller._setTransportRecoveryPhase(
          connectionId,
          ConnectionWorkspaceTransportRecoveryPhase.unavailable,
        );
        controller._completeRecoveryAttempt(
          connectionId,
          completedAt: controller._now(),
          outcome: ConnectionWorkspaceRecoveryOutcome.transportUnavailable,
        );
      }
      return;
    }
  }
  if (preservedLaneState.threadId != null) {
    if (shouldReconnectTransport) {
      await _recoverWorkspaceConversationAfterTransportReconnect(
        controller,
        connectionId,
        nextBinding,
        threadId: preservedLaneState.threadId!,
        hadVisibleConversationState: false,
      );
      return;
    }
    await nextBinding.sessionController.selectConversationForResume(
      preservedLaneState.threadId!,
    );
    if (!controller._isDisposed) {
      controller._completeConversationRecoveryAttempt(
        connectionId,
        nextBinding,
        completedAt: controller._now(),
      );
    }
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
    if (previousBinding.sessionController.sessionState.isBusy) {
      return;
    }

    final shouldReconnectTransport = controller._state
        .requiresTransportReconnect(connectionId);
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
        savedSettingsReconnectRequiredConnectionIds:
            _sanitizeWorkspaceReconnectRequiredIds(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              reconnectRequiredConnectionIds: <String>{
                ...controller
                    ._state
                    .savedSettingsReconnectRequiredConnectionIds,
              }..remove(connectionId),
            ),
        transportReconnectRequiredConnectionIds: shouldReconnectTransport
            ? controller._state.transportReconnectRequiredConnectionIds
            : _sanitizeWorkspaceReconnectRequiredIds(
                catalog: controller._state.catalog,
                liveConnectionIds: controller._state.liveConnectionIds,
                reconnectRequiredConnectionIds: <String>{
                  ...controller._state.transportReconnectRequiredConnectionIds,
                }..remove(connectionId),
              ),
        transportRecoveryPhasesByConnectionId: shouldReconnectTransport
            ? _sanitizeWorkspaceTransportRecoveryPhases(
                catalog: controller._state.catalog,
                liveConnectionIds: controller._state.liveConnectionIds,
                transportRecoveryPhasesByConnectionId:
                    <String, ConnectionWorkspaceTransportRecoveryPhase>{
                      ...controller
                          ._state
                          .transportRecoveryPhasesByConnectionId,
                      connectionId: ConnectionWorkspaceTransportRecoveryPhase
                          .reconnecting,
                    },
              )
            : _sanitizeWorkspaceTransportRecoveryPhases(
                catalog: controller._state.catalog,
                liveConnectionIds: controller._state.liveConnectionIds,
                transportRecoveryPhasesByConnectionId:
                    <String, ConnectionWorkspaceTransportRecoveryPhase>{
                      for (final entry
                          in controller
                              ._state
                              .transportRecoveryPhasesByConnectionId
                              .entries)
                        if (entry.key != connectionId) entry.key: entry.value,
                    },
              ),
        liveReattachPhasesByConnectionId: shouldReconnectTransport
            ? _sanitizeWorkspaceLiveReattachPhases(
                catalog: controller._state.catalog,
                liveConnectionIds: controller._state.liveConnectionIds,
                liveReattachPhasesByConnectionId:
                    <String, ConnectionWorkspaceLiveReattachPhase>{
                      ...controller._state.liveReattachPhasesByConnectionId,
                      connectionId:
                          ConnectionWorkspaceLiveReattachPhase.reconnecting,
                    },
              )
            : _sanitizeWorkspaceLiveReattachPhases(
                catalog: controller._state.catalog,
                liveConnectionIds: controller._state.liveConnectionIds,
                liveReattachPhasesByConnectionId:
                    <String, ConnectionWorkspaceLiveReattachPhase>{
                      for (final entry
                          in controller
                              ._state
                              .liveReattachPhasesByConnectionId
                              .entries)
                        if (entry.key != connectionId) entry.key: entry.value,
                    },
              ),
        recoveryDiagnosticsByConnectionId:
            _sanitizeWorkspaceRecoveryDiagnostics(
              catalog: controller._state.catalog,
              liveConnectionIds: controller._state.liveConnectionIds,
              recoveryDiagnosticsByConnectionId:
                  controller._state.recoveryDiagnosticsByConnectionId,
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

Future<void> _deleteWorkspaceSavedConnectionImpl(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  await controller._connectionRepository.deleteConnection(connectionId);
  await controller._modelCatalogStore.delete(connectionId);
  controller._remoteRuntimeRefreshGenerationByConnectionId.remove(connectionId);
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
      final selectedConnectionId = controller._state.selectedConnectionId;
      final backgroundedAt = controller._now();
      if (selectedConnectionId != null &&
          controller._state.isConnectionLive(selectedConnectionId)) {
        controller._recordLifecycleBackgroundSnapshot(
          selectedConnectionId,
          occurredAt: backgroundedAt,
          lifecycleState: ConnectionWorkspaceBackgroundLifecycleState.inactive,
        );
      }
      await controller._enqueueRecoveryPersistence(
        backgroundedAt: backgroundedAt,
        backgroundedLifecycleState:
            ConnectionWorkspaceBackgroundLifecycleState.inactive,
      );
      return;
    case AppLifecycleState.hidden:
      final hiddenConnectionId = controller._state.selectedConnectionId;
      final hiddenAt = controller._now();
      if (hiddenConnectionId != null &&
          controller._state.isConnectionLive(hiddenConnectionId)) {
        controller._recordLifecycleBackgroundSnapshot(
          hiddenConnectionId,
          occurredAt: hiddenAt,
          lifecycleState: ConnectionWorkspaceBackgroundLifecycleState.hidden,
        );
      }
      await controller._enqueueRecoveryPersistence(
        backgroundedAt: hiddenAt,
        backgroundedLifecycleState:
            ConnectionWorkspaceBackgroundLifecycleState.hidden,
      );
      return;
    case AppLifecycleState.paused:
      final pausedConnectionId = controller._state.selectedConnectionId;
      final pausedAt = controller._now();
      if (pausedConnectionId != null &&
          controller._state.isConnectionLive(pausedConnectionId)) {
        controller._recordLifecycleBackgroundSnapshot(
          pausedConnectionId,
          occurredAt: pausedAt,
          lifecycleState: ConnectionWorkspaceBackgroundLifecycleState.paused,
        );
      }
      await controller._enqueueRecoveryPersistence(
        backgroundedAt: pausedAt,
        backgroundedLifecycleState:
            ConnectionWorkspaceBackgroundLifecycleState.paused,
      );
      return;
    case AppLifecycleState.resumed:
      final selectedConnectionId = controller._state.selectedConnectionId;
      final resumedAt = controller._now();
      if (selectedConnectionId == null ||
          !controller._state.isConnectionLive(selectedConnectionId)) {
        return;
      }

      controller._recordLifecycleResume(
        selectedConnectionId,
        occurredAt: resumedAt,
      );
      if (!controller._state.requiresTransportReconnect(selectedConnectionId)) {
        return;
      }

      final binding =
          controller._liveBindingsByConnectionId[selectedConnectionId];
      if (binding == null || binding.sessionController.sessionState.isBusy) {
        return;
      }

      controller._beginRecoveryAttempt(
        selectedConnectionId,
        startedAt: resumedAt,
        origin: ConnectionWorkspaceRecoveryOrigin.foregroundResume,
      );
      await _reconnectWorkspaceConnection(controller, selectedConnectionId);
      return;
    case AppLifecycleState.detached:
      return;
  }
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

Future<void> _connectWorkspaceBindingTransport(ConnectionLaneBinding binding) {
  if (binding.appServerClient.isConnected) {
    return Future<void>.value();
  }

  return binding.appServerClient.connect(
    profile: binding.sessionController.profile,
    secrets: binding.sessionController.secrets,
  );
}

Future<void> _recoverWorkspaceConversationAfterTransportReconnect(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionLaneBinding binding, {
  required String threadId,
  required bool hadVisibleConversationState,
}) async {
  try {
    await binding.sessionController.reattachConversation(threadId);
    if (controller._isDisposed) {
      return;
    }

    if (_shouldFallbackToHistoryRestoreAfterLiveReattach(
      binding,
      hadVisibleConversationState: hadVisibleConversationState,
    )) {
      controller._clearTransportReconnectRequired(connectionId);
      controller._setLiveReattachPhase(
        connectionId,
        ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
      );
      await binding.sessionController.selectConversationForResume(threadId);
      if (!controller._isDisposed) {
        controller._completeConversationRecoveryAttempt(
          connectionId,
          binding,
          completedAt: controller._now(),
        );
      }
      return;
    }

    controller._clearTransportReconnectRequired(connectionId);
    controller._setLiveReattachPhase(
      connectionId,
      ConnectionWorkspaceLiveReattachPhase.liveReattached,
    );
    controller._completeLiveReattachRecoveryAttempt(
      connectionId,
      completedAt: controller._now(),
    );
  } catch (_) {
    if (controller._isDisposed) {
      return;
    }

    controller._clearTransportReconnectRequired(connectionId);
    controller._setLiveReattachPhase(
      connectionId,
      ConnectionWorkspaceLiveReattachPhase.fallbackRestore,
    );
    await binding.sessionController.selectConversationForResume(threadId);
    if (!controller._isDisposed) {
      controller._completeConversationRecoveryAttempt(
        connectionId,
        binding,
        completedAt: controller._now(),
      );
    }
  }
}

bool _shouldFallbackToHistoryRestoreAfterLiveReattach(
  ConnectionLaneBinding binding, {
  required bool hadVisibleConversationState,
}) {
  if (hadVisibleConversationState) {
    return false;
  }

  return !_workspaceLaneHasVisibleLiveConversationState(binding);
}

bool _workspaceLaneHasVisibleLiveConversationState(
  ConnectionLaneBinding binding,
) {
  final sessionState = binding.sessionController.sessionState;
  return sessionState.activeTurn != null ||
      sessionState.pendingApprovalRequests.isNotEmpty ||
      sessionState.pendingUserInputRequests.isNotEmpty ||
      binding.sessionController.transcriptBlocks.isNotEmpty;
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
