part of '../connection_workspace_controller.dart';

void _scheduleWorkspaceRecoveryPersistence(
  ConnectionWorkspaceController controller,
) {
  if (controller._isDisposed) {
    return;
  }
  controller._recoveryPersistenceDebounceTimer?.cancel();
  controller._recoveryPersistenceDebounceTimer = Timer(
    controller._recoveryPersistenceDebounceDuration,
    () {
      controller._recoveryPersistenceDebounceTimer = null;
      unawaited(
        controller._queueRecoveryPersistenceSnapshot(
          snapshot: controller._selectedRecoveryStateSnapshot(),
        ),
      );
    },
  );
}

Future<void> _enqueueWorkspaceRecoveryPersistence(
  ConnectionWorkspaceController controller, {
  DateTime? backgroundedAt,
  ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
}) {
  controller._recoveryPersistenceDebounceTimer?.cancel();
  controller._recoveryPersistenceDebounceTimer = null;
  return controller._queueRecoveryPersistenceSnapshot(
    snapshot: controller._selectedRecoveryStateSnapshot(
      backgroundedAt: backgroundedAt,
      backgroundedLifecycleState: backgroundedLifecycleState,
    ),
  );
}

Future<void> _queueWorkspaceRecoveryPersistenceSnapshot(
  ConnectionWorkspaceController controller, {
  ConnectionWorkspaceRecoveryState? snapshot,
}) {
  if (controller._isDisposed) {
    return controller._recoveryPersistence;
  }

  if (snapshot == controller._lastPersistedRecoveryState ||
      snapshot == controller._pendingRecoveryPersistenceState) {
    return controller._recoveryPersistence;
  }

  controller._pendingRecoveryPersistenceState = snapshot;
  if (controller._isPersistingRecoveryState) {
    return controller._recoveryPersistence;
  }

  controller._isPersistingRecoveryState = true;
  controller._recoveryPersistence = _drainWorkspaceRecoveryPersistenceQueue(
    controller,
  );
  return controller._recoveryPersistence;
}

Future<void> _drainWorkspaceRecoveryPersistenceQueue(
  ConnectionWorkspaceController controller,
) async {
  try {
    while (true) {
      final snapshot = controller._pendingRecoveryPersistenceState;
      controller._pendingRecoveryPersistenceState = null;
      if (snapshot == null) {
        break;
      }
      if (snapshot == controller._lastPersistedRecoveryState) {
        if (controller._pendingRecoveryPersistenceState == null) {
          break;
        }
        continue;
      }
      try {
        await controller._recoveryStore.save(snapshot);
        controller._lastPersistedRecoveryState = snapshot;
        if (snapshot != null) {
          controller._updateRecoveryDiagnostics(
            snapshot.connectionId,
            (current) => current.copyWith(
              clearLastRecoveryPersistenceFailureAt: true,
              clearLastRecoveryPersistenceFailureDetail: true,
            ),
          );
        }
      } catch (error, stackTrace) {
        if (snapshot != null) {
          controller._updateRecoveryDiagnostics(
            snapshot.connectionId,
            (current) => current.copyWith(
              lastRecoveryPersistenceFailureAt: controller._now().toUtc(),
              lastRecoveryPersistenceFailureDetail:
                  PocketErrorDetailFormatter.normalize(error),
            ),
          );
        }
        assert(() {
          debugPrint('Failed to save workspace recovery state: $error');
          debugPrintStack(stackTrace: stackTrace);
          return true;
        }());
      }
      if (controller._pendingRecoveryPersistenceState == null) {
        break;
      }
    }
  } finally {
    controller._isPersistingRecoveryState = false;
    if (controller._pendingRecoveryPersistenceState != null &&
        !controller._isDisposed) {
      controller._isPersistingRecoveryState = true;
      controller._recoveryPersistence = _drainWorkspaceRecoveryPersistenceQueue(
        controller,
      );
    }
  }
}

bool _hasWorkspaceImmediateRecoveryIdentityChange(
  ConnectionWorkspaceController controller,
  ConnectionWorkspaceRecoveryState? snapshot,
) {
  final referenceSnapshot =
      controller._pendingRecoveryPersistenceState ??
      controller._lastPersistedRecoveryState;
  return referenceSnapshot?.connectionId != snapshot?.connectionId ||
      referenceSnapshot?.selectedThreadId != snapshot?.selectedThreadId;
}

ConnectionWorkspaceRecoveryState? _selectedWorkspaceRecoveryStateSnapshot(
  ConnectionWorkspaceController controller, {
  DateTime? backgroundedAt,
  ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState,
}) {
  final selectedConnectionId = controller._state.selectedConnectionId;
  if (selectedConnectionId == null ||
      !controller._state.isConnectionLive(selectedConnectionId)) {
    return null;
  }

  final binding = controller._liveBindingsByConnectionId[selectedConnectionId];
  if (binding == null) {
    return null;
  }

  final selectedThreadId = _normalizedWorkspaceThreadId(
    binding.sessionController.sessionState.currentThreadId ??
        binding.sessionController.sessionState.rootThreadId ??
        binding.sessionController.historicalConversationRestoreState?.threadId,
  );
  final diagnostics = controller._state.recoveryDiagnosticsFor(
    selectedConnectionId,
  );

  return ConnectionWorkspaceRecoveryState(
    connectionId: selectedConnectionId,
    selectedThreadId: selectedThreadId,
    draftText: binding.composerDraftHost.draft.text,
    backgroundedAt: backgroundedAt ?? diagnostics?.lastBackgroundedAt,
    backgroundedLifecycleState:
        backgroundedLifecycleState ??
        diagnostics?.lastBackgroundedLifecycleState,
  );
}
