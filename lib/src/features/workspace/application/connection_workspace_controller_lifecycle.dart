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
        viewport: ConnectionWorkspaceViewport.dormantRoster,
        savedSettingsReconnectRequiredConnectionIds: <String>{},
        transportReconnectRequiredConnectionIds: <String>{},
        transportRecoveryPhasesByConnectionId:
            <String, ConnectionWorkspaceTransportRecoveryPhase>{},
        recoveryDiagnosticsByConnectionId:
            <String, ConnectionWorkspaceRecoveryDiagnostics>{},
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
      recoveryDiagnosticsByConnectionId: _initialWorkspaceRecoveryDiagnostics(
        connectionId: firstConnectionId,
        recoveryState: recoveryState,
      ),
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
  } catch (_) {
    if (!controller._isDisposed) {
      controller._recordFallbackTransportConnectFailure(
        firstConnectionId,
        occurredAt: controller._now(),
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
  }

  await firstBinding.sessionController.selectConversationForResume(
    recoveryState!.selectedThreadId!,
  );
  if (!controller._isDisposed) {
    controller._completeConversationRecoveryAttempt(
      firstConnectionId,
      firstBinding,
      completedAt: controller._now(),
    );
  }
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
    controller._applyState(
      controller._state.copyWith(
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
            : controller._state.transportRecoveryPhasesByConnectionId,
      ),
    );
    if (!shouldReconnectTransport) {
      return;
    }

    try {
      await _connectWorkspaceBindingTransport(previousBinding);
    } catch (_) {
      if (!controller._isDisposed) {
        controller._recordFallbackTransportConnectFailure(
          connectionId,
          occurredAt: controller._now(),
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
    }
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
    } catch (_) {
      if (!controller._isDisposed) {
        controller._recordFallbackTransportConnectFailure(
          connectionId,
          occurredAt: controller._now(),
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
    }
  }
  if (preservedLaneState.threadId != null) {
    await nextBinding.sessionController.selectConversationForResume(
      preservedLaneState.threadId!,
    );
    if (!controller._isDisposed && shouldReconnectTransport) {
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

Future<void> _deleteDormantWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  await controller._connectionRepository.deleteConnection(connectionId);
  await controller._modelCatalogStore.delete(connectionId);
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
