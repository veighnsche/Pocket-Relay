part of 'workspace_desktop_shell.dart';

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
