part of '../connection_workspace_controller.dart';

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
