part of 'connection_workspace_controller.dart';

Future<void> _reconnectWorkspaceLane(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  if (!controller._state.isConnectionLive(normalizedConnectionId) ||
      !controller._state.requiresReconnect(normalizedConnectionId)) {
    return;
  }

  await _reconnectWorkspaceConnection(controller, normalizedConnectionId);
}

Future<void> _resumeWorkspaceConversationSelection(
  ConnectionWorkspaceController controller, {
  required String connectionId,
  required String threadId,
}) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  final normalizedThreadId = threadId.trim();
  if (normalizedThreadId.isEmpty) {
    throw ArgumentError.value(
      threadId,
      'threadId',
      'Thread id must not be empty.',
    );
  }

  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);

  await _resumeWorkspaceConversation(
    controller,
    normalizedConnectionId,
    threadId: normalizedThreadId,
  );
}

Future<void> _instantiateWorkspaceLiveConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);

  if (controller._state.isConnectionLive(normalizedConnectionId)) {
    _selectWorkspaceConnection(controller, normalizedConnectionId);
    return;
  }

  await _instantiateWorkspaceConnection(controller, normalizedConnectionId);
}

void _selectWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  final normalizedConnectionId = connectionId.trim();
  if (normalizedConnectionId.isEmpty ||
      !controller._state.isConnectionLive(normalizedConnectionId)) {
    return;
  }
  if (controller._state.selectedConnectionId == normalizedConnectionId &&
      controller._state.isShowingLiveLane) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      selectedConnectionId: normalizedConnectionId,
      viewport: ConnectionWorkspaceViewport.liveLane,
    ),
  );
}

void _showWorkspaceDormantRoster(ConnectionWorkspaceController controller) {
  if (controller._state.isShowingDormantRoster) {
    return;
  }

  controller._applyState(
    controller._state.copyWith(
      viewport: ConnectionWorkspaceViewport.dormantRoster,
    ),
  );
}

void _terminateWorkspaceConnection(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  final normalizedConnectionId = connectionId.trim();
  final binding =
      controller._liveBindingsByConnectionId[normalizedConnectionId];
  if (binding == null) {
    return;
  }
  if (binding.sessionController.sessionState.isBusy) {
    return;
  }
  controller._liveBindingsByConnectionId.remove(normalizedConnectionId);

  final currentLiveConnectionIds = controller._state.liveConnectionIds;
  final removalIndex = currentLiveConnectionIds.indexOf(normalizedConnectionId);
  final nextLiveConnectionIds = _orderWorkspaceLiveConnectionIds(
    controller,
    controller._liveBindingsByConnectionId.keys,
  );
  final nextSelectedConnectionId =
      _nextSelectedWorkspaceConnectionIdAfterTermination(
        controller,
        removedConnectionId: normalizedConnectionId,
        removalIndex: removalIndex,
        nextLiveConnectionIds: nextLiveConnectionIds,
      );
  final nextViewport = _nextWorkspaceViewportAfterTermination(
    controller,
    removedConnectionId: normalizedConnectionId,
    nextSelectedConnectionId: nextSelectedConnectionId,
  );

  controller._unregisterLiveBinding(normalizedConnectionId);
  binding.dispose();
  controller._applyState(
    controller._state.copyWith(
      isLoading: false,
      liveConnectionIds: nextLiveConnectionIds,
      selectedConnectionId: nextSelectedConnectionId,
      viewport: nextViewport,
      clearSelectedConnectionId: nextSelectedConnectionId == null,
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
      liveReattachPhasesByConnectionId: _sanitizeWorkspaceLiveReattachPhases(
        catalog: controller._state.catalog,
        liveConnectionIds: nextLiveConnectionIds,
        liveReattachPhasesByConnectionId:
            controller._state.liveReattachPhasesByConnectionId,
      ),
      recoveryDiagnosticsByConnectionId: _sanitizeWorkspaceRecoveryDiagnostics(
        catalog: controller._state.catalog,
        liveConnectionIds: nextLiveConnectionIds,
        recoveryDiagnosticsByConnectionId:
            controller._state.recoveryDiagnosticsByConnectionId,
      ),
    ),
  );
}

List<String> _orderWorkspaceLiveConnectionIds(
  ConnectionWorkspaceController controller,
  Iterable<String> connectionIds,
) {
  final liveConnectionIdSet = connectionIds.toSet();
  return <String>[
    for (final connectionId in controller._state.catalog.orderedConnectionIds)
      if (liveConnectionIdSet.contains(connectionId)) connectionId,
  ];
}

String? _nextSelectedWorkspaceConnectionIdAfterTermination(
  ConnectionWorkspaceController controller, {
  required String removedConnectionId,
  required int removalIndex,
  required List<String> nextLiveConnectionIds,
}) {
  if (controller._state.selectedConnectionId != removedConnectionId) {
    return controller._state.selectedConnectionId;
  }
  if (nextLiveConnectionIds.isEmpty) {
    return null;
  }

  final nextIndex = removalIndex.clamp(0, nextLiveConnectionIds.length - 1);
  return nextLiveConnectionIds[nextIndex];
}

ConnectionWorkspaceViewport _nextWorkspaceViewportAfterTermination(
  ConnectionWorkspaceController controller, {
  required String removedConnectionId,
  required String? nextSelectedConnectionId,
}) {
  if (controller._state.selectedConnectionId == removedConnectionId &&
      nextSelectedConnectionId == null) {
    return ConnectionWorkspaceViewport.dormantRoster;
  }

  return controller._state.viewport;
}
