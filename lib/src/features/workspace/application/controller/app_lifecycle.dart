part of '../connection_workspace_controller.dart';

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
