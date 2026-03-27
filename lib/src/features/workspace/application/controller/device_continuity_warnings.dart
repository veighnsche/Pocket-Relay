part of '../connection_workspace_controller.dart';

void _setWorkspaceForegroundServiceWarning(
  ConnectionWorkspaceController controller,
  PocketUserFacingError? warning,
) {
  _updateWorkspaceDeviceContinuityWarnings(
    controller,
    (current) => current.copyWith(
      foregroundServiceWarning: warning,
      clearForegroundServiceWarning: warning == null,
    ),
  );
}

void _setWorkspaceBackgroundGraceWarning(
  ConnectionWorkspaceController controller,
  PocketUserFacingError? warning,
) {
  _updateWorkspaceDeviceContinuityWarnings(
    controller,
    (current) => current.copyWith(
      backgroundGraceWarning: warning,
      clearBackgroundGraceWarning: warning == null,
    ),
  );
}

void _setWorkspaceWakeLockWarning(
  ConnectionWorkspaceController controller,
  PocketUserFacingError? warning,
) {
  _updateWorkspaceDeviceContinuityWarnings(
    controller,
    (current) => current.copyWith(
      wakeLockWarning: warning,
      clearWakeLockWarning: warning == null,
    ),
  );
}

void _updateWorkspaceDeviceContinuityWarnings(
  ConnectionWorkspaceController controller,
  ConnectionWorkspaceDeviceContinuityWarnings Function(
    ConnectionWorkspaceDeviceContinuityWarnings current,
  )
  update,
) {
  if (controller._isDisposed) {
    return;
  }

  final currentWarnings = controller._state.deviceContinuityWarnings;
  final nextWarnings = update(currentWarnings);
  if (nextWarnings == currentWarnings) {
    return;
  }

  controller._applyStateWithoutRecoveryPersistence(
    controller._state.copyWith(deviceContinuityWarnings: nextWarnings),
  );
}
