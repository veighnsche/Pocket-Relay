import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/application/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_dormant_roster_content.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_live_lane_surface.dart';

class ConnectionWorkspaceDesktopShell extends StatefulWidget {
  const ConnectionWorkspaceDesktopShell({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
    this.conversationHistoryRepository,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;
  final CodexWorkspaceConversationHistoryRepository?
  conversationHistoryRepository;
  final ConnectionSettingsOverlayDelegate settingsOverlayDelegate;

  @override
  State<ConnectionWorkspaceDesktopShell> createState() =>
      _ConnectionWorkspaceDesktopShellState();
}

class _ConnectionWorkspaceDesktopShellState
    extends State<ConnectionWorkspaceDesktopShell> {
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final supportsCollapsedSidebar =
        widget.platformPolicy.behavior.supportsCollapsibleDesktopSidebar;

    return AnimatedBuilder(
      animation: widget.workspaceController,
      builder: (context, _) {
        final state = widget.workspaceController.state;
        final selectedLaneBinding =
            widget.workspaceController.selectedLaneBinding;
        final palette = context.pocketPalette;

        return Scaffold(
          backgroundColor: palette.backgroundTop,
          body: Row(
            children: [
              _MaterialDesktopSidebar(
                workspaceController: widget.workspaceController,
                state: state,
                isCollapsed: supportsCollapsedSidebar && _isSidebarCollapsed,
                onToggleCollapsed: supportsCollapsedSidebar
                    ? _toggleSidebarCollapsed
                    : null,
                connectionSubtitleBuilder: _connectionSubtitle,
              ),
              Expanded(
                child: switch ((
                  state.isShowingDormantRoster,
                  selectedLaneBinding,
                )) {
                  (true, _) => ConnectionWorkspaceDormantRosterContent(
                    workspaceController: widget.workspaceController,
                    description: ConnectionWorkspaceCopy
                        .desktopSavedConnectionsDescription,
                    platformBehavior: widget.platformPolicy.behavior,
                    settingsOverlayDelegate: widget.settingsOverlayDelegate,
                    useSafeArea: true,
                  ),
                  (false, final laneBinding?) =>
                    ConnectionWorkspaceLiveLaneSurface(
                      workspaceController: widget.workspaceController,
                      laneBinding: laneBinding,
                      platformPolicy: widget.platformPolicy,
                      conversationHistoryRepository:
                          widget.conversationHistoryRepository,
                      settingsOverlayDelegate: widget.settingsOverlayDelegate,
                    ),
                  _ => const SizedBox.shrink(),
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _toggleSidebarCollapsed() {
    setState(() {
      _isSidebarCollapsed = !_isSidebarCollapsed;
    });
  }

  String _connectionSubtitle(ConnectionProfile profile) {
    return ConnectionWorkspaceCopy.connectionSubtitle(profile);
  }
}

class _MaterialDesktopSidebar extends StatelessWidget {
  const _MaterialDesktopSidebar({
    required this.workspaceController,
    required this.state,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.connectionSubtitleBuilder,
  });

  final ConnectionWorkspaceController workspaceController;
  final ConnectionWorkspaceState state;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;
  final String Function(ConnectionProfile profile) connectionSubtitleBuilder;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;

    return AnimatedContainer(
      key: const ValueKey('desktop_sidebar'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: isCollapsed ? 76 : 304,
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.82),
        border: Border(right: BorderSide(color: palette.surfaceBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: isCollapsed
              ? const EdgeInsets.fromLTRB(
                  PocketSpacing.xs,
                  PocketSpacing.lg,
                  PocketSpacing.xs,
                  PocketSpacing.xl,
                )
              : const EdgeInsets.fromLTRB(
                  PocketSpacing.lg,
                  PocketSpacing.xl,
                  PocketSpacing.lg,
                  PocketSpacing.xxxl,
                ),
          children: isCollapsed
              ? _buildCollapsedChildren(context)
              : _buildExpandedChildren(context),
        ),
      ),
    );
  }

  List<Widget> _buildExpandedChildren(BuildContext context) {
    final theme = Theme.of(context);

    return <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              ConnectionWorkspaceCopy.workspaceTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onToggleCollapsed case final onPressed?)
            _MaterialSidebarToggleButton(
              isCollapsed: false,
              onPressed: onPressed,
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        ConnectionWorkspaceCopy.desktopSidebarDescription,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 22),
      _MaterialSidebarSectionTitle(
        title: ConnectionWorkspaceCopy.openLanesSectionTitle,
        trailingCount: state.liveConnectionIds.length,
      ),
      const SizedBox(height: 10),
      ...state.liveConnectionIds.indexed.map((entry) {
        final index = entry.$1;
        final connectionId = entry.$2;
        final laneBinding = workspaceController.bindingForConnectionId(
          connectionId,
        );
        final liveProfile = laneBinding?.sessionController.profile;
        if (liveProfile == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == state.liveConnectionIds.length - 1 ? 0 : 10,
          ),
          child: _MaterialSidebarConnectionRow(
            connectionId: connectionId,
            title: liveProfile.label,
            subtitle: connectionSubtitleBuilder(liveProfile),
            requiresReconnect: state.requiresReconnect(connectionId),
            isSelected:
                state.isShowingLiveLane &&
                state.selectedConnectionId == connectionId,
            onTap: () => workspaceController.selectConnection(connectionId),
            onClose: () =>
                workspaceController.terminateConnection(connectionId),
          ),
        );
      }),
      const SizedBox(height: 22),
      _MaterialSidebarSectionTitle(
        title: ConnectionWorkspaceCopy.savedSectionTitle,
        trailingCount: state.dormantConnectionIds.length,
      ),
      const SizedBox(height: 10),
      _MaterialDormantRosterSidebarRow(
        isSelected: state.isShowingDormantRoster,
        onTap: workspaceController.showDormantRoster,
      ),
      if (state.dormantConnectionIds.isNotEmpty) ...[
        const SizedBox(height: 10),
        ...state.dormantConnectionIds.indexed.map((entry) {
          final index = entry.$1;
          final connectionId = entry.$2;
          final summary = state.catalog.connectionForId(connectionId);
          if (summary == null) {
            return const SizedBox.shrink();
          }

          return Padding(
            padding: EdgeInsets.only(left: 12, top: index == 0 ? 0 : 8),
            child: Text(
              '${summary.profile.label} · ${ConnectionWorkspaceCopy.compactSavedConnectionLabel(summary.profile)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ],
    ];
  }

  List<Widget> _buildCollapsedChildren(BuildContext context) {
    return <Widget>[
      if (onToggleCollapsed case final onPressed?)
        Align(
          child: _MaterialSidebarToggleButton(
            isCollapsed: true,
            onPressed: onPressed,
          ),
        ),
      if (onToggleCollapsed != null) const SizedBox(height: 14),
      ...state.liveConnectionIds.indexed.map((entry) {
        final index = entry.$1;
        final connectionId = entry.$2;
        final laneBinding = workspaceController.bindingForConnectionId(
          connectionId,
        );
        final liveProfile = laneBinding?.sessionController.profile;
        if (liveProfile == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(
            bottom: index == state.liveConnectionIds.length - 1 ? 0 : 10,
          ),
          child: _MaterialCollapsedSidebarButton(
            buttonKey: ValueKey<String>('desktop_live_$connectionId'),
            label: _monogramFor(liveProfile.label),
            isSelected:
                state.isShowingLiveLane &&
                state.selectedConnectionId == connectionId,
            showsActivityDot: state.requiresReconnect(connectionId),
            onTap: () => workspaceController.selectConnection(connectionId),
          ),
        );
      }),
      const SizedBox(height: 14),
      _MaterialDormantRosterSidebarRow(
        isSelected: state.isShowingDormantRoster,
        isCollapsed: true,
        onTap: workspaceController.showDormantRoster,
      ),
    ];
  }

  String _monogramFor(String label) {
    final trimmedLabel = label.trim();
    if (trimmedLabel.isEmpty) {
      return '?';
    }

    return trimmedLabel.characters.first.toUpperCase();
  }
}

class _MaterialSidebarToggleButton extends StatelessWidget {
  const _MaterialSidebarToggleButton({
    required this.isCollapsed,
    required this.onPressed,
  });

  final bool isCollapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
      child: IconButton(
        key: const ValueKey('desktop_sidebar_toggle'),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
        icon: Icon(
          isCollapsed
              ? Icons.chevron_right_rounded
              : Icons.chevron_left_rounded,
        ),
      ),
    );
  }
}

class _MaterialSidebarSectionTitle extends StatelessWidget {
  const _MaterialSidebarSectionTitle({
    required this.title,
    required this.trailingCount,
  });

  final String title;
  final int trailingCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.subtleSurface,
            borderRadius: PocketRadii.circular(PocketRadii.pill),
            border: Border.all(color: palette.surfaceBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              '$trailingCount',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MaterialSidebarConnectionRow extends StatelessWidget {
  const _MaterialSidebarConnectionRow({
    required this.connectionId,
    required this.title,
    required this.subtitle,
    required this.requiresReconnect,
    required this.isSelected,
    required this.onTap,
    required this.onClose,
  });

  final String connectionId;
  final String title;
  final String subtitle;
  final bool requiresReconnect;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;
    final backgroundColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : palette.surface.withValues(alpha: 0.72);
    final borderColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.36)
        : palette.surfaceBorder;

    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: PocketRadii.circular(22),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey<String>('desktop_live_$connectionId'),
                borderRadius: PocketRadii.circular(22),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (requiresReconnect) ...[
                        const SizedBox(height: 8),
                        DefaultTextStyle(
                          style: theme.textTheme.labelSmall!.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          child: PocketTintBadge(
                            label: ConnectionWorkspaceCopy.reconnectBadge,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Tooltip(
              message: ConnectionWorkspaceCopy.closeLaneAction,
              child: IconButton(
                key: ValueKey<String>('desktop_close_lane_$connectionId'),
                visualDensity: VisualDensity.compact,
                onPressed: onClose,
                color: theme.colorScheme.onSurfaceVariant,
                icon: const Icon(Icons.close),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _MaterialDormantRosterSidebarRow extends StatelessWidget {
  const _MaterialDormantRosterSidebarRow({
    required this.isSelected,
    required this.onTap,
    this.isCollapsed = false,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return _MaterialCollapsedSidebarButton(
        buttonKey: const ValueKey('desktop_dormant_roster'),
        label: 'S',
        icon: Icons.layers_outlined,
        isSelected: isSelected,
        onTap: onTap,
      );
    }

    final theme = Theme.of(context);
    final palette = context.pocketPalette;
    final backgroundColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : palette.subtleSurface.withValues(alpha: 0.8);
    final borderColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.36)
        : palette.surfaceBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('desktop_dormant_roster'),
        borderRadius: PocketRadii.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: PocketRadii.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                const Icon(Icons.layers_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ConnectionWorkspaceCopy.savedConnectionsTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialCollapsedSidebarButton extends StatelessWidget {
  const _MaterialCollapsedSidebarButton({
    required this.buttonKey,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.showsActivityDot = false,
  });

  final Key buttonKey;
  final String label;
  final IconData? icon;
  final bool isSelected;
  final bool showsActivityDot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;
    final backgroundColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : palette.surface.withValues(alpha: 0.72);
    final borderColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.36)
        : palette.surfaceBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: buttonKey,
        borderRadius: PocketRadii.circular(PocketRadii.lg),
        onTap: onTap,
        child: Ink(
          width: 60,
          height: 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: PocketRadii.circular(PocketRadii.lg),
            border: Border.all(color: borderColor),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (icon case final resolvedIcon?)
                Icon(
                  resolvedIcon,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              else
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              if (showsActivityDot)
                Positioned(
                  top: 12,
                  right: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: PocketRadii.circular(PocketRadii.pill),
                    ),
                    child: const SizedBox(width: 8, height: 8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
