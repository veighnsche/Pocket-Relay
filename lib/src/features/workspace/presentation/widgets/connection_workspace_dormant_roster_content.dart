import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_screen_shell.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_renderer.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/models/connection_workspace_state.dart';

enum ConnectionWorkspaceRosterStyle { material, cupertino }

class ConnectionWorkspaceDormantRosterContent extends StatefulWidget {
  const ConnectionWorkspaceDormantRosterContent({
    super.key,
    required this.workspaceController,
    required this.description,
    required this.visualStyle,
    this.platformBehavior = const PocketPlatformBehavior(
      experience: PocketPlatformExperience.mobile,
      supportsLocalConnectionMode: false,
      supportsWakeLock: true,
      usesDesktopKeyboardSubmit: false,
    ),
    this.settingsRenderer = ConnectionSettingsRenderer.material,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
    this.useSafeArea = true,
  });

  final ConnectionWorkspaceController workspaceController;
  final String description;
  final ConnectionWorkspaceRosterStyle visualStyle;
  final PocketPlatformBehavior platformBehavior;
  final ConnectionSettingsRenderer settingsRenderer;
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

    final content = switch (widget.visualStyle) {
      ConnectionWorkspaceRosterStyle.material => _buildMaterialContent(
        context,
        workspaceState: workspaceState,
        dormantConnections: dormantConnections,
      ),
      ConnectionWorkspaceRosterStyle.cupertino => _buildCupertinoContent(
        context,
        workspaceState: workspaceState,
        dormantConnections: dormantConnections,
      ),
    };

    final wrappedContent = widget.useSafeArea
        ? switch (widget.visualStyle) {
            ConnectionWorkspaceRosterStyle.material => SafeArea(
              bottom: false,
              child: content,
            ),
            ConnectionWorkspaceRosterStyle.cupertino => SafeArea(
              top: false,
              bottom: true,
              child: content,
            ),
          }
        : content;

    final gradientBackground = ChatScreenGradientBackground(
      child: wrappedContent,
    );

    return switch (widget.visualStyle) {
      ConnectionWorkspaceRosterStyle.material => Material(
        type: MaterialType.transparency,
        child: gradientBackground,
      ),
      ConnectionWorkspaceRosterStyle.cupertino => gradientBackground,
    };
  }

  Widget _buildMaterialContent(
    BuildContext context, {
    required ConnectionWorkspaceState workspaceState,
    required List<SavedConnectionSummary> dormantConnections,
  }) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text(
          ConnectionWorkspaceCopy.savedConnectionsTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          widget.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('add_connection'),
            onPressed: _isCreatingConnection ? null : _createConnection,
            icon: const Icon(Icons.add),
            label: Text(
              _isCreatingConnection
                  ? ConnectionWorkspaceCopy.addConnectionProgress
                  : ConnectionWorkspaceCopy.addConnectionAction,
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (dormantConnections.isEmpty)
          _DormantConnectionsEmptyState(
            visualStyle: widget.visualStyle,
            isEmptyWorkspace: workspaceState.isEmptyWorkspace,
            canReturnToLane: workspaceState.selectedConnectionId != null,
            onReturnToLane: _handleReturnToLiveLane,
          )
        else
          ...dormantConnections.indexed.map((entry) {
            final index = entry.$1;
            final connection = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == dormantConnections.length - 1 ? 0 : 12,
              ),
              child: _DormantConnectionCard(
                visualStyle: widget.visualStyle,
                connectionId: connection.id,
                title: connection.profile.label,
                subtitle: _connectionSubtitle(connection.profile),
                isOpening: _instantiatingConnectionIds.contains(connection.id),
                isEditing: _editingConnectionIds.contains(connection.id),
                isDeleting: _deletingConnectionIds.contains(connection.id),
                onOpen: () => _instantiateConnection(connection.id),
                onEdit: () => _editConnection(connection),
                onDelete: () => _deleteConnection(connection.id),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildCupertinoContent(
    BuildContext context, {
    required ConnectionWorkspaceState workspaceState,
    required List<SavedConnectionSummary> dormantConnections,
  }) {
    final secondaryLabelColor = CupertinoColors.secondaryLabel.resolveFrom(
      context,
    );

    return CupertinoScrollbar(
      controller: _scrollController,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              widget.description,
              style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                fontSize: 15,
                height: 1.4,
                color: secondaryLabelColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: CupertinoButton.filled(
              key: const ValueKey('add_connection'),
              onPressed: _isCreatingConnection ? null : _createConnection,
              child: Text(
                _isCreatingConnection
                    ? ConnectionWorkspaceCopy.addConnectionProgress
                    : ConnectionWorkspaceCopy.addConnectionAction,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (dormantConnections.isEmpty)
            _DormantConnectionsEmptyState(
              visualStyle: widget.visualStyle,
              isEmptyWorkspace: workspaceState.isEmptyWorkspace,
              canReturnToLane: workspaceState.selectedConnectionId != null,
              onReturnToLane: _handleReturnToLiveLane,
            )
          else
            ...dormantConnections.map(
              (connection) => _DormantConnectionCard(
                visualStyle: widget.visualStyle,
                connectionId: connection.id,
                title: connection.profile.label,
                subtitle: _connectionSubtitle(connection.profile),
                isOpening: _instantiatingConnectionIds.contains(connection.id),
                isEditing: _editingConnectionIds.contains(connection.id),
                isDeleting: _deletingConnectionIds.contains(connection.id),
                onOpen: () => _instantiateConnection(connection.id),
                onEdit: () => _editConnection(connection),
                onDelete: () => _deleteConnection(connection.id),
              ),
            ),
        ],
      ),
    );
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

    final payload = await _openConnectionSettings(
      profile: ConnectionProfile.defaults(),
      secrets: const ConnectionSecrets(),
    );
    if (!mounted || payload == null) {
      return;
    }

    setState(() {
      _isCreatingConnection = true;
    });

    try {
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

    final savedConnection = await widget.workspaceController
        .loadSavedConnection(connectionId);
    if (!mounted) {
      return;
    }

    final payload = await _openConnectionSettings(
      profile: savedConnection.profile,
      secrets: savedConnection.secrets,
    );
    if (!mounted || payload == null) {
      return;
    }

    setState(() {
      _editingConnectionIds.add(connectionId);
    });

    try {
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
  }) {
    return widget.settingsOverlayDelegate.openConnectionSettings(
      context: context,
      initialProfile: profile,
      initialSecrets: secrets,
      platformBehavior: widget.platformBehavior,
      renderer: widget.settingsRenderer,
    );
  }
}

class _DormantConnectionsEmptyState extends StatelessWidget {
  const _DormantConnectionsEmptyState({
    required this.visualStyle,
    required this.isEmptyWorkspace,
    required this.canReturnToLane,
    required this.onReturnToLane,
  });

  final ConnectionWorkspaceRosterStyle visualStyle;
  final bool isEmptyWorkspace;
  final bool canReturnToLane;
  final VoidCallback onReturnToLane;

  @override
  Widget build(BuildContext context) {
    return switch (visualStyle) {
      ConnectionWorkspaceRosterStyle.material => _buildMaterial(context),
      ConnectionWorkspaceRosterStyle.cupertino => _buildCupertino(context),
    };
  }

  Widget _buildMaterial(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ConnectionWorkspaceCopy.emptySavedConnectionsTitle(
                isEmptyWorkspace: isEmptyWorkspace,
              ),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ConnectionWorkspaceCopy.emptySavedConnectionsMessage(
                isEmptyWorkspace: isEmptyWorkspace,
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (canReturnToLane) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onReturnToLane,
                child: const Text(
                  ConnectionWorkspaceCopy.returnToOpenLaneAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCupertino(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return CupertinoListSection.insetGrouped(
      hasLeading: false,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ConnectionWorkspaceCopy.emptySavedConnectionsTitle(
                  isEmptyWorkspace: isEmptyWorkspace,
                ),
                style: theme.textTheme.navTitleTextStyle.copyWith(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ConnectionWorkspaceCopy.emptySavedConnectionsMessage(
                  isEmptyWorkspace: isEmptyWorkspace,
                ),
                style: theme.textTheme.textStyle.copyWith(
                  fontSize: 15,
                  height: 1.4,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
              if (canReturnToLane) ...[
                const SizedBox(height: 14),
                CupertinoButton.filled(
                  onPressed: onReturnToLane,
                  child: const Text(
                    ConnectionWorkspaceCopy.returnToOpenLaneAction,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DormantConnectionCard extends StatelessWidget {
  const _DormantConnectionCard({
    required this.visualStyle,
    required this.connectionId,
    required this.title,
    required this.subtitle,
    required this.isOpening,
    required this.isEditing,
    required this.isDeleting,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final ConnectionWorkspaceRosterStyle visualStyle;
  final String connectionId;
  final String title;
  final String subtitle;
  final bool isOpening;
  final bool isEditing;
  final bool isDeleting;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return switch (visualStyle) {
      ConnectionWorkspaceRosterStyle.material => _buildMaterial(context),
      ConnectionWorkspaceRosterStyle.cupertino => _buildCupertino(context),
    };
  }

  Widget _buildMaterial(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);
    final isBusy = isOpening || isEditing || isDeleting;

    return DecoratedBox(
      key: ValueKey<String>('dormant_connection_$connectionId'),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.surfaceBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadowColor,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton(
                  key: ValueKey<String>('instantiate_$connectionId'),
                  onPressed: isBusy ? null : onOpen,
                  child: Text(
                    isOpening
                        ? ConnectionWorkspaceCopy.openingLaneAction
                        : ConnectionWorkspaceCopy.openLaneAction,
                  ),
                ),
                OutlinedButton(
                  key: ValueKey<String>('edit_$connectionId'),
                  onPressed: isBusy ? null : onEdit,
                  child: Text(
                    isEditing
                        ? ConnectionWorkspaceCopy.saveProgress
                        : ConnectionWorkspaceCopy.editAction,
                  ),
                ),
                TextButton(
                  key: ValueKey<String>('delete_$connectionId'),
                  onPressed: isBusy ? null : onDelete,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: Text(
                    isDeleting
                        ? ConnectionWorkspaceCopy.deleteProgress
                        : ConnectionWorkspaceCopy.deleteAction,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCupertino(BuildContext context) {
    final isBusy = isOpening || isEditing || isDeleting;
    final textStyle = CupertinoTheme.of(context).textTheme.textStyle;

    return CupertinoListSection.insetGrouped(
      key: ValueKey<String>('dormant_connection_$connectionId'),
      hasLeading: false,
      children: [
        CupertinoListTile.notched(
          title: Text(
            title,
            style: textStyle.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: textStyle.copyWith(
              fontSize: 14,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          trailing: isOpening
              ? const CupertinoActivityIndicator()
              : const CupertinoListTileChevron(),
          onTap: isBusy ? null : onOpen,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: CupertinoButton.filled(
                  key: ValueKey<String>('instantiate_$connectionId'),
                  onPressed: isBusy ? null : onOpen,
                  child: Text(
                    isOpening
                        ? ConnectionWorkspaceCopy.openingLaneAction
                        : ConnectionWorkspaceCopy.openLaneAction,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CupertinoButton(
                      key: ValueKey<String>('edit_$connectionId'),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: CupertinoColors.secondarySystemFill.resolveFrom(
                        context,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: isBusy ? null : onEdit,
                      child: Text(
                        isEditing
                            ? ConnectionWorkspaceCopy.saveProgress
                            : ConnectionWorkspaceCopy.editAction,
                        style: textStyle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoButton(
                      key: ValueKey<String>('delete_$connectionId'),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      color: CupertinoColors.secondarySystemFill.resolveFrom(
                        context,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      onPressed: isBusy ? null : onDelete,
                      child: Text(
                        isDeleting
                            ? ConnectionWorkspaceCopy.deleteProgress
                            : ConnectionWorkspaceCopy.deleteAction,
                        style: textStyle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.destructiveRed.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
