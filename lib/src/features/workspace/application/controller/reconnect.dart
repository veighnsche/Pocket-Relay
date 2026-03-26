part of '../connection_workspace_controller.dart';

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
