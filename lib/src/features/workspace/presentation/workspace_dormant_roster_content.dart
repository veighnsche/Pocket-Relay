import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/chat_screen_shell.dart';
import 'package:pocket_relay/src/features/connection_settings/domain/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/connection_settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

part 'workspace_dormant_roster_content_items.dart';
part 'workspace_dormant_roster_content_shell.dart';

const double _dormantRosterPanelRadius = 12;

class ConnectionWorkspaceDormantRosterContent extends StatefulWidget {
  const ConnectionWorkspaceDormantRosterContent({
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
  State<ConnectionWorkspaceDormantRosterContent> createState() =>
      _ConnectionWorkspaceDormantRosterContentState();
}

class _ConnectionWorkspaceDormantRosterContentState
    extends State<ConnectionWorkspaceDormantRosterContent> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _instantiatingConnectionIds = <String>{};
  final Set<String> _editingConnectionIds = <String>{};
  final Set<String> _deletingConnectionIds = <String>{};
  bool _isCreatingConnection = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceState = widget.workspaceController.state;
    final dormantConnections = workspaceState.catalog.orderedConnections
        .where(
          (connection) =>
              workspaceState.dormantConnectionIds.contains(connection.id),
        )
        .toList(growable: false);

    final content = _buildMaterialContent(
      context,
      workspaceState: workspaceState,
      dormantConnections: dormantConnections,
    );

    final wrappedContent = widget.useSafeArea
        ? SafeArea(bottom: false, child: content)
        : content;

    final gradientBackground = ChatScreenGradientBackground(
      child: wrappedContent,
    );

    return Material(type: MaterialType.transparency, child: gradientBackground);
  }

  String _connectionSubtitle(ConnectionProfile profile) {
    return ConnectionWorkspaceCopy.connectionSubtitle(profile);
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

      await widget.workspaceController.saveDormantConnection(
        connectionId: connectionId,
        profile: payload.profile,
        secrets: payload.secrets,
      );
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
      await widget.workspaceController.deleteDormantConnection(connectionId);
    } finally {
      if (mounted) {
        setState(() {
          _deletingConnectionIds.remove(connectionId);
        });
      }
    }
  }

  void _handleReturnToLiveLane() {
    final selectedConnectionId =
        widget.workspaceController.state.selectedConnectionId;
    if (selectedConnectionId == null) {
      return;
    }

    widget.workspaceController.selectConnection(selectedConnectionId);
  }

  Future<ConnectionSettingsSubmitPayload?> _openConnectionSettings({
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
      availableModelCatalog: availableModelCatalog,
      availableModelCatalogSource: availableModelCatalogSource,
    );
  }
}
