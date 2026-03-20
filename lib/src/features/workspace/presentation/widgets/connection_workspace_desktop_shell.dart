import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/theme/pocket_cupertino_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_overlay_delegate.dart';
import 'package:pocket_relay/src/features/workspace/models/connection_workspace_state.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_controller.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_workspace_copy.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_dormant_roster_content.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_live_lane_surface.dart';

import 'connection_workspace_settings_renderer.dart';

class ConnectionWorkspaceDesktopShell extends StatefulWidget {
  const ConnectionWorkspaceDesktopShell({
    super.key,
    required this.workspaceController,
    required this.platformPolicy,
    required this.conversationHistoryRepository,
    this.settingsOverlayDelegate =
        const ModalConnectionSettingsOverlayDelegate(),
  });

  final ConnectionWorkspaceController workspaceController;
  final PocketPlatformPolicy platformPolicy;
  final CodexWorkspaceConversationHistoryRepository
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
    final usesCupertinoSidebar =
        widget.platformPolicy.regionPolicy.screenShell ==
        ChatRootScreenShellRenderer.cupertino;

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
              usesCupertinoSidebar
                  ? _CupertinoDesktopSidebar(
                      workspaceController: widget.workspaceController,
                      state: state,
                      isCollapsed: _isSidebarCollapsed,
                      onToggleCollapsed: _toggleSidebarCollapsed,
                      connectionSubtitleBuilder: _connectionSubtitle,
                    )
                  : _MaterialDesktopSidebar(
                      workspaceController: widget.workspaceController,
                      state: state,
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
                    settingsRenderer: connectionSettingsRendererFor(
                      widget.platformPolicy,
                    ),
                    settingsOverlayDelegate: widget.settingsOverlayDelegate,
                    useSafeArea: true,
                    visualStyle: usesCupertinoSidebar
                        ? ConnectionWorkspaceRosterStyle.cupertino
                        : ConnectionWorkspaceRosterStyle.material,
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
    required this.connectionSubtitleBuilder,
  });

  final ConnectionWorkspaceController workspaceController;
  final ConnectionWorkspaceState state;
  final String Function(ConnectionProfile profile) connectionSubtitleBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return DecoratedBox(
      key: const ValueKey('desktop_sidebar'),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.82),
        border: Border(right: BorderSide(color: palette.surfaceBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          width: 304,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
            children: [
              Text(
                ConnectionWorkspaceCopy.workspaceTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
                    bottom: index == state.liveConnectionIds.length - 1
                        ? 0
                        : 10,
                  ),
                  child: _MaterialSidebarConnectionRow(
                    connectionId: connectionId,
                    title: liveProfile.label,
                    subtitle: connectionSubtitleBuilder(liveProfile),
                    requiresReconnect: state.requiresReconnect(connectionId),
                    isSelected:
                        state.isShowingLiveLane &&
                        state.selectedConnectionId == connectionId,
                    onTap: () =>
                        workspaceController.selectConnection(connectionId),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _CupertinoDesktopSidebar extends StatelessWidget {
  const _CupertinoDesktopSidebar({
    required this.workspaceController,
    required this.state,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.connectionSubtitleBuilder,
  });

  final ConnectionWorkspaceController workspaceController;
  final ConnectionWorkspaceState state;
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  final String Function(ConnectionProfile profile) connectionSubtitleBuilder;

  @override
  Widget build(BuildContext context) {
    final resolvedTheme = buildPocketCupertinoTheme(Theme.of(context));
    final separatorColor = CupertinoColors.separator.resolveFrom(context);
    final backgroundColor = CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    );

    return CupertinoTheme(
      data: resolvedTheme,
      child: AnimatedContainer(
        key: const ValueKey('desktop_sidebar'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: isCollapsed ? 76 : 304,
        decoration: BoxDecoration(
          color: backgroundColor.withValues(alpha: 0.92),
          border: Border(right: BorderSide(color: separatorColor)),
        ),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: isCollapsed
                ? const EdgeInsets.fromLTRB(8, 14, 8, 18)
                : const EdgeInsets.fromLTRB(14, 18, 14, 24),
            children: isCollapsed
                ? _buildCollapsedChildren(context)
                : _buildExpandedChildren(context),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildExpandedChildren(BuildContext context) {
    final theme = CupertinoTheme.of(context);

    return <Widget>[
      Row(
        children: [
          Expanded(
            child: Text(
              ConnectionWorkspaceCopy.workspaceTitle,
              style: theme.textTheme.navTitleTextStyle.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _CupertinoSidebarToggleButton(
            isCollapsed: false,
            onPressed: onToggleCollapsed,
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        ConnectionWorkspaceCopy.desktopSidebarDescription,
        style: theme.textTheme.textStyle.copyWith(
          fontSize: 14,
          height: 1.4,
          color: CupertinoColors.secondaryLabel.resolveFrom(context),
        ),
      ),
      const SizedBox(height: 22),
      _CupertinoSidebarSectionTitle(
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
          child: _CupertinoSidebarConnectionRow(
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
      _CupertinoSidebarSectionTitle(
        title: ConnectionWorkspaceCopy.savedSectionTitle,
        trailingCount: state.dormantConnectionIds.length,
      ),
      const SizedBox(height: 10),
      _CupertinoSavedConnectionsRow(
        isSelected: state.isShowingDormantRoster,
        isCollapsed: false,
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
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          );
        }),
      ],
    ];
  }

  List<Widget> _buildCollapsedChildren(BuildContext context) {
    return <Widget>[
      Align(
        child: _CupertinoSidebarToggleButton(
          isCollapsed: true,
          onPressed: onToggleCollapsed,
        ),
      ),
      const SizedBox(height: 14),
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
          child: _CupertinoCollapsedSidebarButton(
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
      _CupertinoSavedConnectionsRow(
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
            borderRadius: BorderRadius.circular(999),
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
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                key: ValueKey<String>('desktop_live_$connectionId'),
                borderRadius: BorderRadius.circular(22),
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
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.28,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            child: Text(
                              ConnectionWorkspaceCopy.reconnectBadge,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
  });

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(22),
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

class _CupertinoSidebarToggleButton extends StatelessWidget {
  const _CupertinoSidebarToggleButton({
    required this.isCollapsed,
    required this.onPressed,
  });

  final bool isCollapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      key: const ValueKey('desktop_sidebar_toggle'),
      padding: const EdgeInsets.all(10),
      minimumSize: Size.zero,
      onPressed: onPressed,
      child: Icon(
        isCollapsed
            ? CupertinoIcons.chevron_right
            : CupertinoIcons.chevron_left,
        size: 18,
      ),
    );
  }
}

class _CupertinoSidebarSectionTitle extends StatelessWidget {
  const _CupertinoSidebarSectionTitle({
    required this.title,
    required this.trailingCount,
  });

  final String title;
  final int trailingCount;

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context);
    final fillColor = CupertinoColors.secondarySystemFill.resolveFrom(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.textStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              '$trailingCount',
              style: theme.textTheme.textStyle.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CupertinoSidebarConnectionRow extends StatelessWidget {
  const _CupertinoSidebarConnectionRow({
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
    final activeBlue = CupertinoColors.activeBlue.resolveFrom(context);
    final fillColor = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final borderColor = isSelected
        ? activeBlue.withValues(alpha: 0.28)
        : CupertinoColors.separator.resolveFrom(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected ? activeBlue.withValues(alpha: 0.10) : fillColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: CupertinoButton(
              key: ValueKey<String>('desktop_live_$connectionId'),
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              minimumSize: Size.zero,
              onPressed: onTap,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: CupertinoTheme.of(context).textTheme.textStyle
                          .copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CupertinoTheme.of(context).textTheme.textStyle
                          .copyWith(
                            fontSize: 13,
                            color: CupertinoColors.secondaryLabel.resolveFrom(
                              context,
                            ),
                          ),
                    ),
                    if (requiresReconnect) ...[
                      const SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: activeBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          child: Text(
                            ConnectionWorkspaceCopy.reconnectBadge,
                            style: CupertinoTheme.of(context)
                                .textTheme
                                .textStyle
                                .copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: activeBlue,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          CupertinoButton(
            key: ValueKey<String>('desktop_close_lane_$connectionId'),
            padding: const EdgeInsets.all(8),
            minimumSize: Size.zero,
            onPressed: onClose,
            child: Icon(
              CupertinoIcons.xmark,
              size: 18,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _CupertinoSavedConnectionsRow extends StatelessWidget {
  const _CupertinoSavedConnectionsRow({
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isCollapsed) {
      return _CupertinoCollapsedSidebarButton(
        buttonKey: const ValueKey('desktop_dormant_roster'),
        label: 'S',
        icon: CupertinoIcons.square_stack_3d_up,
        isSelected: isSelected,
        onTap: onTap,
      );
    }

    final activeBlue = CupertinoColors.activeBlue.resolveFrom(context);
    final fillColor = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final borderColor = isSelected
        ? activeBlue.withValues(alpha: 0.28)
        : CupertinoColors.separator.resolveFrom(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isSelected ? activeBlue.withValues(alpha: 0.10) : fillColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: CupertinoButton(
        key: const ValueKey('desktop_dormant_roster'),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        minimumSize: Size.zero,
        onPressed: onTap,
        child: Row(
          children: [
            Icon(
              CupertinoIcons.square_stack_3d_up,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ConnectionWorkspaceCopy.savedConnectionsTitle,
                style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CupertinoCollapsedSidebarButton extends StatelessWidget {
  const _CupertinoCollapsedSidebarButton({
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
    final activeBlue = CupertinoColors.activeBlue.resolveFrom(context);
    final fillColor = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);
    final borderColor = isSelected
        ? activeBlue.withValues(alpha: 0.28)
        : CupertinoColors.separator.resolveFrom(context);

    return CupertinoButton(
      key: buttonKey,
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? activeBlue.withValues(alpha: 0.10) : fillColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: SizedBox(
          width: 60,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (icon case final resolvedIcon?)
                Icon(
                  resolvedIcon,
                  size: 20,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                )
              else
                Text(
                  label,
                  style: CupertinoTheme.of(context).textTheme.textStyle
                      .copyWith(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              if (showsActivityDot)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: activeBlue,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
