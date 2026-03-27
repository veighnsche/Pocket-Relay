import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/chat_screen_shell.dart';
import 'package:pocket_relay/src/features/connection_settings/application/connection_settings_remote_runtime_probe.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_lifecycle_errors.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_lifecycle_presentation.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_lifecycle_widgets.dart';

part 'workspace_saved_connections_content_items.dart';
part 'workspace_saved_connections_content_shell.dart';

const double _savedConnectionsPanelRadius = 12;

class ConnectionWorkspaceSavedConnectionsContent extends StatefulWidget {
  const ConnectionWorkspaceSavedConnectionsContent({
    super.key,
    required this.workspaceController,
    required this.description,
    this.platformBehavior = const PocketPlatformBehavior(
      experience: PocketPlatformExperience.mobile,
      supportsLocalConnectionMode: false,
      supportsWakeLock: true,
      supportsFiniteBackgroundGrace: false,
      supportsActiveTurnForegroundService: false,
      usesDesktopKeyboardSubmit: false,
      supportsCollapsibleDesktopSidebar: false,
    ),
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
    this.useSafeArea = true,
  });

  final ConnectionWorkspaceController workspaceController;
  final String description;
  final PocketPlatformBehavior platformBehavior;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;
  final bool useSafeArea;

  @override
  State<ConnectionWorkspaceSavedConnectionsContent> createState() =>
      _ConnectionWorkspaceSavedConnectionsContentState();
}

class _ConnectionWorkspaceSavedConnectionsContentState
    extends State<ConnectionWorkspaceSavedConnectionsContent> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _instantiatingConnectionIds = <String>{};
  final Set<String> _reconnectingConnectionIds = <String>{};
  final Set<String> _editingConnectionIds = <String>{};
  final Set<String> _deletingConnectionIds = <String>{};
  final Set<String> _disconnectingConnectionIds = <String>{};
  final Set<String> _checkingHostConnectionIds = <String>{};
  final Map<String, ConnectionSettingsRemoteServerActionId>
  _activeRemoteServerActionsByConnectionId =
      <String, ConnectionSettingsRemoteServerActionId>{};
  final Set<String> _autoProbedRemoteRuntimeConnectionIds = <String>{};
  bool _isCreatingConnection = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceState = widget.workspaceController.state;
    final sections = connectionLifecycleSectionsFromState(
      workspaceState,
      isTransportConnected: _isTransportConnected,
    );
    _scheduleMissingRemoteRuntimeProbes(sections: sections);

    final content = _buildMaterialContent(context, sections: sections);

    final wrappedContent = widget.useSafeArea
        ? SafeArea(bottom: false, child: content)
        : content;

    final gradientBackground = ChatScreenGradientBackground(
      child: wrappedContent,
    );

    return Material(type: MaterialType.transparency, child: gradientBackground);
  }

  bool _isTransportConnected(String connectionId) {
    return widget.workspaceController
            .bindingForConnectionId(connectionId)
            ?.appServerClient
            .isConnected ==
        true;
  }

  Future<void> _instantiateConnection(String connectionId) async {
    if (_instantiatingConnectionIds.contains(connectionId)) {
      return;
    }

    setState(() {
      _instantiatingConnectionIds.add(connectionId);
    });

    try {
      await widget.workspaceController.instantiateConnection(connectionId);
    } finally {
      if (mounted) {
        setState(() {
          _instantiatingConnectionIds.remove(connectionId);
        });
      }
    }
  }

  Future<void> _openConnection(SavedConnectionSummary connection) async {
    if (widget.workspaceController.state.isConnectionLive(connection.id)) {
      widget.workspaceController.selectConnection(connection.id);
      return;
    }

    try {
      await _instantiateConnection(connection.id);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ConnectionRemoteRuntimeState? remoteRuntime;
      if (connection.profile.isRemote) {
        try {
          remoteRuntime = await widget.workspaceController.refreshRemoteRuntime(
            connectionId: connection.id,
          );
        } catch (_) {
          remoteRuntime = widget.workspaceController.state.remoteRuntimeFor(
            connection.id,
          );
        }
      }

      if (!mounted) {
        return;
      }
      _showTransientMessage(
        ConnectionLifecycleErrors.openConnectionFailure(
          profile: connection.profile,
          remoteRuntime: remoteRuntime,
          error: error,
        ).inlineMessage,
      );
    }
  }

  Future<void> _reconnectConnection(String connectionId) async {
    if (_reconnectingConnectionIds.contains(connectionId)) {
      return;
    }

    setState(() {
      _reconnectingConnectionIds.add(connectionId);
    });

    try {
      await widget.workspaceController.reconnectConnection(connectionId);
    } finally {
      if (mounted) {
        setState(() {
          _reconnectingConnectionIds.remove(connectionId);
        });
      }
    }
  }

  Future<void> _createConnection() async {
    if (_isCreatingConnection) {
      return;
    }

    setState(() {
      _isCreatingConnection = true;
    });

    try {
      final availableModelCatalog = await widget.workspaceController
          .loadLastKnownConnectionModelCatalog();
      if (!mounted) {
        return;
      }
      final payload = await _openConnectionSettings(
        profile: ConnectionProfile.defaults(),
        secrets: const ConnectionSecrets(),
        availableModelCatalog: availableModelCatalog,
        availableModelCatalogSource: availableModelCatalog == null
            ? null
            : ConnectionSettingsModelCatalogSource.lastKnownCache,
      );
      if (!mounted || payload == null) {
        return;
      }

      await widget.workspaceController.createConnection(
        profile: payload.profile,
        secrets: payload.secrets,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingConnection = false;
        });
      }
    }
  }

  Future<void> _editConnection(SavedConnectionSummary connection) async {
    final connectionId = connection.id;
    if (_editingConnectionIds.contains(connectionId)) {
      return;
    }

    setState(() {
      _editingConnectionIds.add(connectionId);
    });

    try {
      final savedConnectionFuture = widget.workspaceController
          .loadSavedConnection(connectionId);
      final cachedModelCatalogFuture = widget.workspaceController
          .loadConnectionModelCatalog(connectionId);
      final lastKnownModelCatalogFuture = widget.workspaceController
          .loadLastKnownConnectionModelCatalog();
      final savedConnection = await savedConnectionFuture;
      final cachedModelCatalog = await cachedModelCatalogFuture;
      final lastKnownModelCatalog = await lastKnownModelCatalogFuture;
      if (!mounted) {
        return;
      }

      final payload = await _openConnectionSettings(
        connectionId: connectionId,
        profile: savedConnection.profile,
        secrets: savedConnection.secrets,
        availableModelCatalog: cachedModelCatalog ?? lastKnownModelCatalog,
        availableModelCatalogSource: cachedModelCatalog != null
            ? ConnectionSettingsModelCatalogSource.connectionCache
            : lastKnownModelCatalog != null
            ? ConnectionSettingsModelCatalogSource.lastKnownCache
            : null,
      );
      if (!mounted || payload == null) {
        return;
      }

      await widget.workspaceController.saveSavedConnection(
        connectionId: connectionId,
        profile: payload.profile,
        secrets: payload.secrets,
      );
      _autoProbedRemoteRuntimeConnectionIds.remove(connectionId);
    } finally {
      if (mounted) {
        setState(() {
          _editingConnectionIds.remove(connectionId);
        });
      }
    }
  }

  Future<void> _deleteConnection(String connectionId) async {
    if (_deletingConnectionIds.contains(connectionId)) {
      return;
    }

    setState(() {
      _deletingConnectionIds.add(connectionId);
    });

    try {
      await widget.workspaceController.deleteSavedConnection(connectionId);
      _autoProbedRemoteRuntimeConnectionIds.remove(connectionId);
    } finally {
      if (mounted) {
        setState(() {
          _deletingConnectionIds.remove(connectionId);
        });
      }
    }
  }

  Future<void> _disconnectConnection(String connectionId) async {
    if (_disconnectingConnectionIds.contains(connectionId)) {
      return;
    }

    setState(() {
      _disconnectingConnectionIds.add(connectionId);
    });

    try {
      await widget.workspaceController.disconnectConnection(connectionId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      final detail = error.toString().trim();
      _showTransientMessage(
        detail.isEmpty
            ? 'Could not disconnect lane.'
            : 'Could not disconnect lane. $detail',
      );
    } finally {
      if (mounted) {
        setState(() {
          _disconnectingConnectionIds.remove(connectionId);
        });
      }
    }
  }

  void _scheduleMissingRemoteRuntimeProbes({
    required List<ConnectionLifecycleSectionPresentation> sections,
  }) {
    final connectionIdsToProbe = <String>[
      for (final section in sections)
        for (final row in section.rows)
          if (row.connection.profile.isRemote &&
              row.remoteRuntime == null &&
              !_autoProbedRemoteRuntimeConnectionIds.contains(
                row.connection.id,
              ))
            row.connection.id,
    ];
    if (connectionIdsToProbe.isEmpty) {
      return;
    }

    _autoProbedRemoteRuntimeConnectionIds.addAll(connectionIdsToProbe);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final connectionId in connectionIdsToProbe) {
        unawaited(
          widget.workspaceController.refreshRemoteRuntime(
            connectionId: connectionId,
          ),
        );
      }
    });
  }

  Future<void> _checkHost(String connectionId) async {
    if (_checkingHostConnectionIds.contains(connectionId)) {
      return;
    }

    setState(() {
      _checkingHostConnectionIds.add(connectionId);
    });

    try {
      await widget.workspaceController.refreshRemoteRuntime(
        connectionId: connectionId,
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingHostConnectionIds.remove(connectionId);
        });
      }
    }
  }

  Future<void> _runRemoteServerAction(
    String connectionId,
    ConnectionSettingsRemoteServerActionId actionId,
  ) async {
    if (_activeRemoteServerActionsByConnectionId.containsKey(connectionId)) {
      return;
    }

    setState(() {
      _activeRemoteServerActionsByConnectionId[connectionId] = actionId;
    });

    try {
      final remoteRuntime = await switch (actionId) {
        ConnectionSettingsRemoteServerActionId.start =>
          widget.workspaceController.startRemoteServer(
            connectionId: connectionId,
          ),
        ConnectionSettingsRemoteServerActionId.stop =>
          widget.workspaceController.stopRemoteServer(
            connectionId: connectionId,
          ),
        ConnectionSettingsRemoteServerActionId.restart =>
          widget.workspaceController.restartRemoteServer(
            connectionId: connectionId,
          ),
      };
      if (!mounted) {
        return;
      }
      if (!_didRemoteServerActionSucceed(actionId, remoteRuntime)) {
        _showTransientMessage(
          ConnectionLifecycleErrors.remoteServerActionFailure(
            actionId,
            remoteRuntime: remoteRuntime,
          ).inlineMessage,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showTransientMessage(
        ConnectionLifecycleErrors.remoteServerActionFailure(
          actionId,
          remoteRuntime: widget.workspaceController.state.remoteRuntimeFor(
            connectionId,
          ),
          error: error,
        ).inlineMessage,
      );
    } finally {
      if (mounted) {
        setState(() {
          _activeRemoteServerActionsByConnectionId.remove(connectionId);
        });
      }
    }
  }

  bool _didRemoteServerActionSucceed(
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

  void _showTransientMessage(String message) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<ConnectionSettingsSubmitPayload?> _openConnectionSettings({
    String? connectionId,
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
    ConnectionModelCatalog? availableModelCatalog,
    ConnectionSettingsModelCatalogSource? availableModelCatalogSource,
  }) {
    return widget.settingsOverlayDelegate.openConnectionSettings(
      context: context,
      initialProfile: profile,
      initialSecrets: secrets,
      platformBehavior: widget.platformBehavior,
      initialRemoteRuntime: connectionId == null
          ? null
          : widget.workspaceController.state.remoteRuntimeFor(connectionId),
      availableModelCatalog: availableModelCatalog,
      availableModelCatalogSource: availableModelCatalogSource,
      onRefreshRemoteRuntime: (payload) {
        if (connectionId == null) {
          return probeConnectionSettingsRemoteRuntime(payload: payload);
        }
        return widget.workspaceController.refreshRemoteRuntime(
          connectionId: connectionId,
          profile: payload.profile,
          secrets: payload.secrets,
        );
      },
    );
  }
}
