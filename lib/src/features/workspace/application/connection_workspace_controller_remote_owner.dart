part of 'connection_workspace_controller.dart';

Future<ConnectionRemoteRuntimeState> _startWorkspaceRemoteServer(
  ConnectionWorkspaceController controller, {
  required String connectionId,
}) {
  return _runWorkspaceRemoteServerAction(
    controller,
    actionId: ConnectionSettingsRemoteServerActionId.start,
    connectionId: connectionId,
    actionDetail: 'Starting managed remote runtime…',
    runAction: ({required profile, required secrets, required ownerId}) =>
        controller
            ._remoteRuntimeDelegateFactory(profile.agentAdapter)
            .startRemoteServer(
              profile: profile,
              secrets: secrets,
              ownerId: ownerId,
            ),
  );
}

Future<ConnectionRemoteRuntimeState> _stopWorkspaceRemoteServer(
  ConnectionWorkspaceController controller, {
  required String connectionId,
}) {
  return _runWorkspaceRemoteServerAction(
    controller,
    actionId: ConnectionSettingsRemoteServerActionId.stop,
    connectionId: connectionId,
    actionDetail: 'Stopping managed remote runtime…',
    runAction: ({required profile, required secrets, required ownerId}) =>
        controller
            ._remoteRuntimeDelegateFactory(profile.agentAdapter)
            .stopRemoteServer(
              profile: profile,
              secrets: secrets,
              ownerId: ownerId,
            ),
  );
}

Future<ConnectionRemoteRuntimeState> _restartWorkspaceRemoteServer(
  ConnectionWorkspaceController controller, {
  required String connectionId,
}) {
  return _runWorkspaceRemoteServerAction(
    controller,
    actionId: ConnectionSettingsRemoteServerActionId.restart,
    connectionId: connectionId,
    actionDetail: 'Restarting managed remote runtime…',
    runAction: ({required profile, required secrets, required ownerId}) =>
        controller
            ._remoteRuntimeDelegateFactory(profile.agentAdapter)
            .restartRemoteServer(
              profile: profile,
              secrets: secrets,
              ownerId: ownerId,
            ),
  );
}

typedef _WorkspaceRemoteServerActionRunner =
    Future<void> Function({
      required ConnectionProfile profile,
      required ConnectionSecrets secrets,
      required String ownerId,
    });

Future<ConnectionRemoteRuntimeState> _runWorkspaceRemoteServerAction(
  ConnectionWorkspaceController controller, {
  required ConnectionSettingsRemoteServerActionId actionId,
  required String connectionId,
  required String actionDetail,
  required _WorkspaceRemoteServerActionRunner runAction,
}) async {
  final normalizedConnectionId = _normalizeWorkspaceConnectionId(connectionId);
  await controller.initialize();
  _requireKnownWorkspaceConnectionId(controller, normalizedConnectionId);

  final savedConnection = await controller._connectionRepository.loadConnection(
    normalizedConnectionId,
  );
  if (savedConnection.profile.isLocal) {
    throw StateError(
      'Managed remote app-server lifecycle is only available for remote connections.',
    );
  }

  final refreshGeneration =
      (controller
              ._remoteRuntimeRefreshGenerationByConnectionId[normalizedConnectionId] ??
          0) +
      1;
  controller
          ._remoteRuntimeRefreshGenerationByConnectionId[normalizedConnectionId] =
      refreshGeneration;

  final sessionName = controller
      ._remoteRuntimeDelegateFactory(savedConnection.profile.agentAdapter)
      .buildSessionName(normalizedConnectionId);
  final existingRuntime = controller.state.remoteRuntimeFor(
    normalizedConnectionId,
  );
  final checkingRuntime = ConnectionRemoteRuntimeState(
    hostCapability:
        existingRuntime?.hostCapability ??
        const ConnectionRemoteHostCapabilityState.unknown(),
    server: ConnectionRemoteServerState.checking(
      ownerId: normalizedConnectionId,
      sessionName: sessionName,
      detail: actionDetail,
    ),
  );
  if (_canApplyWorkspaceRemoteRuntime(
    controller,
    connectionId: normalizedConnectionId,
    refreshGeneration: refreshGeneration,
  )) {
    controller._applyState(
      controller._state.copyWith(
        remoteRuntimeByConnectionId: <String, ConnectionRemoteRuntimeState>{
          ...controller._state.remoteRuntimeByConnectionId,
          normalizedConnectionId: checkingRuntime,
        },
      ),
    );
  }

  Object? actionError;
  StackTrace? actionStackTrace;
  try {
    await runAction(
      profile: savedConnection.profile,
      secrets: savedConnection.secrets,
      ownerId: normalizedConnectionId,
    );
  } catch (error, stackTrace) {
    // Always re-probe after an explicit lifecycle action so runtime truth comes
    // from the remote host, even when the action itself fails.
    actionError = error;
    actionStackTrace = stackTrace;
  }

  final nextRuntime = await _refreshWorkspaceRemoteRuntime(
    controller,
    normalizedConnectionId,
    profile: savedConnection.profile,
    secrets: savedConnection.secrets,
  );
  if (actionError != null &&
      !_didWorkspaceRemoteServerActionSucceed(actionId, nextRuntime)) {
    Error.throwWithStackTrace(actionError, actionStackTrace!);
  }
  return nextRuntime;
}

bool _didWorkspaceRemoteServerActionSucceed(
  ConnectionSettingsRemoteServerActionId actionId,
  ConnectionRemoteRuntimeState remoteRuntime,
) {
  if (!remoteRuntime.hostCapability.isSupported) {
    return false;
  }

  return switch (actionId) {
    ConnectionSettingsRemoteServerActionId.start =>
      remoteRuntime.server.status == ConnectionRemoteServerStatus.running,
    ConnectionSettingsRemoteServerActionId.stop =>
      remoteRuntime.server.status == ConnectionRemoteServerStatus.notRunning,
    ConnectionSettingsRemoteServerActionId.restart =>
      remoteRuntime.server.status == ConnectionRemoteServerStatus.running,
  };
}
