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
      final shouldPreferCachedModelCatalog = widget.workspaceController.state
          .requiresReconnect(connectionId);
      final initialSettingsFuture = _resolveInitialSettings(
        request: request,
        workspaceController: workspaceController,
        connectionId: connectionId,
      );
      final availableModelCatalogFuture = _resolveAvailableModelCatalog(
        workspaceController: workspaceController,
        connectionId: connectionId,
        preferConnectionCatalog: shouldPreferCachedModelCatalog,
      );
      final initialSettings = await initialSettingsFuture;
      final availableModelCatalog = await availableModelCatalogFuture;
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

      final onRefreshModelCatalog = laneBinding.appServerClient.isConnected
          ? (ConnectionSettingsDraft draft) {
              return _refreshAvailableModelCatalog(
                workspaceController: workspaceController,
                laneBinding: laneBinding,
                connectionId: connectionId,
                draft: draft,
              );
            }
          : null;
      final result = await settingsOverlayDelegate.openConnectionSettings(
        context: context,
        initialProfile: initialSettings.$1,
        initialSecrets: initialSettings.$2,
        platformBehavior: platformPolicy.behavior,
        availableModelCatalog: availableModelCatalog.$1,
        availableModelCatalogSource: availableModelCatalog.$2,
        onRefreshModelCatalog: onRefreshModelCatalog,
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

  Future<(
    ConnectionModelCatalog?,
    ConnectionSettingsModelCatalogSource?
  )> _resolveAvailableModelCatalog({
    required ConnectionWorkspaceController workspaceController,
    required String connectionId,
    required bool preferConnectionCatalog,
  }) async {
    final connectionCatalog = await _loadCachedModelCatalog(
      workspaceController: workspaceController,
      connectionId: connectionId,
    );
    if (connectionCatalog != null || preferConnectionCatalog) {
      return (
        connectionCatalog,
        connectionCatalog == null
            ? null
            : ConnectionSettingsModelCatalogSource.connectionCache,
      );
    }

    final lastKnownCatalog = await _loadLastKnownModelCatalog(
      workspaceController: workspaceController,
    );
    return (
      lastKnownCatalog,
      lastKnownCatalog == null
          ? null
          : ConnectionSettingsModelCatalogSource.lastKnownCache,
    );
  }

  Future<ConnectionModelCatalog?> _loadCachedModelCatalog({
    required ConnectionWorkspaceController workspaceController,
    required String connectionId,
  }) async {
    try {
      return await workspaceController.loadConnectionModelCatalog(connectionId);
    } catch (_) {
      return null;
    }
  }

  Future<ConnectionModelCatalog?> _loadLastKnownModelCatalog({
    required ConnectionWorkspaceController workspaceController,
  }) async {
    try {
      return await workspaceController.loadLastKnownConnectionModelCatalog();
    } catch (_) {
      return null;
    }
  }

  Future<ConnectionModelCatalog?> _refreshAvailableModelCatalog({
    required ConnectionWorkspaceController workspaceController,
    required ConnectionLaneBinding laneBinding,
    required String connectionId,
    required ConnectionSettingsDraft draft,
  }) async {
    if (draft.workspaceDir.trim().isEmpty) {
      return null;
    }
    if (!laneBinding.appServerClient.isConnected) {
      return null;
    }

    try {
      String? cursor;
      final models = <ConnectionAvailableModel>[];
      do {
        final page = await laneBinding.appServerClient.listModels(
          cursor: cursor,
          includeHidden: true,
        );
        models.addAll(
          page.models.map(_connectionAvailableModelFromAppServerModel),
        );
        final nextCursor = page.nextCursor?.trim();
        cursor = nextCursor == null || nextCursor.isEmpty ? null : nextCursor;
      } while (cursor != null);

      final catalog = ConnectionModelCatalog(
        connectionId: connectionId,
        fetchedAt: DateTime.now().toUtc(),
        models: models,
      );
      try {
        await workspaceController.saveConnectionModelCatalog(catalog);
      } catch (_) {}
      try {
        await workspaceController.saveLastKnownConnectionModelCatalog(catalog);
      } catch (_) {}
      return catalog;
    } catch (_) {
      return null;
    }
  }

  ConnectionAvailableModel _connectionAvailableModelFromAppServerModel(
    CodexAppServerModel model,
  ) {
    return ConnectionAvailableModel(
      id: model.id,
      model: model.model,
      displayName: model.displayName,
      description: model.description,
      hidden: model.hidden,
      supportedReasoningEfforts: model.supportedReasoningEfforts
          .map<ConnectionAvailableModelReasoningEffortOption>(
            (option) => ConnectionAvailableModelReasoningEffortOption(
              reasoningEffort: option.reasoningEffort,
              description: option.description,
            ),
          )
          .toList(growable: false),
      defaultReasoningEffort: model.defaultReasoningEffort,
      inputModalities: model.inputModalities,
      supportsPersonality: model.supportsPersonality,
      isDefault: model.isDefault,
      upgrade: model.upgrade,
      upgradeInfo: switch (model.upgradeInfo) {
        final upgradeInfo? => ConnectionAvailableModelUpgradeInfo(
          model: upgradeInfo.model,
          upgradeCopy: upgradeInfo.upgradeCopy,
          modelLink: upgradeInfo.modelLink,
          migrationMarkdown: upgradeInfo.migrationMarkdown,
        ),
        null => null,
      },
      availabilityNuxMessage: model.availabilityNuxMessage,
    );
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
