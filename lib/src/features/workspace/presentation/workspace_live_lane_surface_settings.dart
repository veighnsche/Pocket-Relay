part of 'workspace_live_lane_surface.dart';

extension on _ConnectionWorkspaceLiveLaneSurfaceState {
  Future<void> _handleConnectionSettingsRequested(
    ChatConnectionSettingsLaunchContract request,
  ) async {
    if (_isOpeningConnectionSettings) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final laneBinding = widget.laneBinding;
    final settingsOverlayDelegate = widget.settingsOverlayDelegate;
    final platformPolicy = widget.platformPolicy;
    final connectionId = laneBinding.connectionId;

    _setOpeningConnectionSettings(true);

    try {
      final initialSettings = await _resolveInitialSettings(
        request: request,
        workspaceController: workspaceController,
        connectionId: connectionId,
      );
      if (!_matchesLiveRequestContext(
        workspaceController: workspaceController,
        laneBinding: laneBinding,
        settingsOverlayDelegate: settingsOverlayDelegate,
        platformPolicy: platformPolicy,
      )) {
        return;
      }
      if (!mounted) {
        return;
      }

      final result = await settingsOverlayDelegate.openConnectionSettings(
        context: context,
        initialProfile: initialSettings.$1,
        initialSecrets: initialSettings.$2,
        platformBehavior: platformPolicy.behavior,
      );
      if (!_matchesLiveRequestContext(
            workspaceController: workspaceController,
            laneBinding: laneBinding,
            settingsOverlayDelegate: settingsOverlayDelegate,
            platformPolicy: platformPolicy,
          ) ||
          result == null) {
        return;
      }

      if (result.profile == initialSettings.$1 &&
          result.secrets == initialSettings.$2) {
        return;
      }

      await workspaceController.saveLiveConnectionEdits(
        connectionId: connectionId,
        profile: result.profile,
        secrets: result.secrets,
      );
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding.connectionId == connectionId) {
        _setOpeningConnectionSettings(false);
      }
    }
  }

  Future<void> _applySavedSettings() async {
    if (_isApplyingSavedSettings) {
      return;
    }

    final workspaceController = widget.workspaceController;
    final laneBinding = widget.laneBinding;
    final connectionId = laneBinding.connectionId;
    if (!workspaceController.state.requiresReconnect(connectionId)) {
      return;
    }

    _setApplyingSavedSettings(true);

    try {
      await workspaceController.reconnectConnection(connectionId);
    } finally {
      if (mounted &&
          widget.workspaceController == workspaceController &&
          widget.laneBinding.connectionId == connectionId) {
        _setApplyingSavedSettings(false);
      }
    }
  }

  Future<(ConnectionProfile, ConnectionSecrets)> _resolveInitialSettings({
    required ChatConnectionSettingsLaunchContract request,
    required ConnectionWorkspaceController workspaceController,
    required String connectionId,
  }) async {
    if (!workspaceController.state.requiresReconnect(connectionId)) {
      return (request.initialProfile, request.initialSecrets);
    }

    final savedConnection = await workspaceController.loadSavedConnection(
      connectionId,
    );
    return (savedConnection.profile, savedConnection.secrets);
  }

  bool _matchesLiveRequestContext({
    required ConnectionWorkspaceController workspaceController,
    required ConnectionLaneBinding laneBinding,
    required ConnectionSettingsOverlayDelegate settingsOverlayDelegate,
    required PocketPlatformPolicy platformPolicy,
  }) {
    return mounted &&
        widget.workspaceController == workspaceController &&
        widget.laneBinding == laneBinding &&
        widget.settingsOverlayDelegate == settingsOverlayDelegate &&
        widget.platformPolicy == platformPolicy &&
        widget.workspaceController.state.isConnectionLive(
          laneBinding.connectionId,
        );
  }
}
