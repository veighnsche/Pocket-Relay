part of '../connection_workspace_controller.dart';

void _notifyWorkspaceBindingChange(ConnectionWorkspaceController controller) {
  if (controller._isDisposed) {
    return;
  }

  controller._notifyListenersInternal();
  unawaited(controller._enqueueRecoveryPersistence());
}

void _registerWorkspaceLiveBinding(
  ConnectionWorkspaceController controller,
  String connectionId,
  ConnectionLaneBinding binding,
) {
  controller._unregisterLiveBinding(connectionId);
  void listener() {
    if (controller._state.selectedConnectionId != connectionId) {
      return;
    }
    final snapshot = controller._selectedRecoveryStateSnapshot();
    if (controller._hasImmediateRecoveryIdentityChange(snapshot)) {
      unawaited(
        controller._queueRecoveryPersistenceSnapshot(snapshot: snapshot),
      );
      return;
    }
    controller._scheduleRecoveryPersistence();
  }

  controller._bindingRecoveryRegistrationsByConnectionId[connectionId] = (
    binding: binding,
    listener: listener,
    appServerEventSubscription: binding.agentAdapterClient.events.listen((
      event,
    ) {
      switch (event) {
        case CodexAppServerDisconnectedEvent(:final exitCode):
          if (controller._intentionalTransportDisconnectConnectionIds.remove(
            connectionId,
          )) {
            controller._clearTransportReconnectRequired(connectionId);
            controller._clearLiveReattachPhase(connectionId);
            break;
          }
          controller._recordTransportLoss(
            connectionId,
            occurredAt: controller._now(),
            reason: switch (exitCode) {
              null => ConnectionWorkspaceTransportLossReason.disconnected,
              0 => ConnectionWorkspaceTransportLossReason.appServerExitGraceful,
              _ => ConnectionWorkspaceTransportLossReason.appServerExitError,
            },
          );
          controller._markTransportReconnectRequired(connectionId);
          controller._setLiveReattachPhase(
            connectionId,
            ConnectionWorkspaceLiveReattachPhase.transportLost,
          );
          break;
        case CodexAppServerConnectedEvent():
          final wasRecovering = controller._state.requiresTransportReconnect(
            connectionId,
          );
          if (wasRecovering) {
            final hasConversationIdentity =
                binding.sessionController.sessionState.currentThreadId
                        ?.trim()
                        .isNotEmpty ==
                    true ||
                binding.sessionController.sessionState.rootThreadId
                        ?.trim()
                        .isNotEmpty ==
                    true;
            if (hasConversationIdentity) {
              controller._setLiveReattachPhase(
                connectionId,
                ConnectionWorkspaceLiveReattachPhase.reconnecting,
              );
            } else {
              controller._clearTransportReconnectRequired(connectionId);
              controller._clearLiveReattachPhase(connectionId);
              controller._completeRecoveryAttempt(
                connectionId,
                completedAt: controller._now(),
                outcome: ConnectionWorkspaceRecoveryOutcome.transportRestored,
              );
            }
          }
          break;
        case CodexAppServerSshConnectFailedEvent():
          controller._recordTransportLoss(
            connectionId,
            occurredAt: controller._now(),
            reason: ConnectionWorkspaceTransportLossReason.sshConnectFailed,
          );
          break;
        case CodexAppServerSshHostKeyMismatchEvent():
          controller._recordTransportLoss(
            connectionId,
            occurredAt: controller._now(),
            reason: ConnectionWorkspaceTransportLossReason.sshHostKeyMismatch,
          );
          break;
        case CodexAppServerSshAuthenticationFailedEvent():
          controller._recordTransportLoss(
            connectionId,
            occurredAt: controller._now(),
            reason:
                ConnectionWorkspaceTransportLossReason.sshAuthenticationFailed,
          );
          break;
        default:
          break;
      }
    }),
  );
  binding.sessionController.addListener(listener);
  binding.composerDraftHost.addListener(listener);
}

void _unregisterWorkspaceLiveBinding(
  ConnectionWorkspaceController controller,
  String connectionId,
) {
  final registration = controller._bindingRecoveryRegistrationsByConnectionId
      .remove(connectionId);
  if (registration == null) {
    return;
  }

  registration.binding.sessionController.removeListener(registration.listener);
  registration.binding.composerDraftHost.removeListener(registration.listener);
  unawaited(registration.appServerEventSubscription.cancel());
}
