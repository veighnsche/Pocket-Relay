part of 'workspace_desktop_shell.dart';

class _MaterialDesktopSidebar extends StatelessWidget {
  const _MaterialDesktopSidebar({
    required this.workspaceController,
    required this.state,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    required this.openingConnectionIds,
    required this.onOpenConnection,
  });

  final ConnectionWorkspaceController workspaceController;
  final ConnectionWorkspaceState state;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapsed;
  final Set<String> openingConnectionIds;
  final Future<void> Function(String connectionId) onOpenConnection;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final listPadding = isCollapsed
        ? const EdgeInsets.fromLTRB(
            PocketSpacing.xs,
            PocketSpacing.lg,
            PocketSpacing.xs,
            PocketSpacing.md,
          )
        : const EdgeInsets.fromLTRB(
            PocketSpacing.lg,
            PocketSpacing.lg,
            PocketSpacing.lg,
            PocketSpacing.md,
          );
    final footerPadding = isCollapsed
        ? const EdgeInsets.fromLTRB(
            PocketSpacing.xs,
            0,
            PocketSpacing.xs,
            PocketSpacing.lg,
          )
        : const EdgeInsets.fromLTRB(
            PocketSpacing.lg,
            0,
            PocketSpacing.lg,
            PocketSpacing.xl,
          );

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
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: listPadding,
                children: isCollapsed
                    ? _buildCollapsedChildren(context)
                    : _buildExpandedChildren(context),
              ),
            ),
            Padding(
              padding: footerPadding,
              child: Column(
                children: [
                  _MaterialSavedConnectionsSidebarRow(
                    isSelected: state.isShowingSavedConnections,
                    isCollapsed: isCollapsed,
                    onTap: workspaceController.showSavedConnections,
                  ),
                  const SizedBox(height: 10),
                  _MaterialSavedSystemsSidebarRow(
                    isSelected: state.isShowingSavedSystems,
                    isCollapsed: isCollapsed,
                    onTap: workspaceController.showSavedSystems,
                  ),
                ],
              ),
            ),
          ],
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
    required this.row,
    required this.facts,
    required this.isSelected,
    required this.onTap,
    required this.isOpening,
    this.onClose,
  });

  final ConnectionLifecyclePresentation row;
  final List<ConnectionLifecycleFact> facts;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isOpening;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;
    final isAttention =
        row.sectionId == ConnectionLifecycleSectionId.needsAttention;
    final backgroundColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.12)
        : isAttention
        ? theme.colorScheme.tertiary.withValues(alpha: 0.1)
        : palette.surface.withValues(alpha: 0.72);
    final borderColor = isSelected
        ? theme.colorScheme.primary.withValues(alpha: 0.36)
        : isAttention
        ? theme.colorScheme.tertiary.withValues(alpha: 0.3)
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
                key: ValueKey<String>(
                  'desktop_connection_${row.connection.id}',
                ),
                borderRadius: PocketRadii.circular(22),
                onTap: isOpening ? null : onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.connection.profile.label,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (facts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ConnectionLifecycleFacts(facts: facts),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        row.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (row.isLive && onClose != null)
              Tooltip(
                message: ConnectionWorkspaceCopy.closeLaneAction,
                child: IconButton(
                  key: ValueKey<String>(
                    'desktop_close_lane_${row.connection.id}',
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  color: theme.colorScheme.onSurfaceVariant,
                  icon: const Icon(Icons.close),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: isOpening
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.arrow_forward_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

class _MaterialSavedConnectionsSidebarRow extends StatelessWidget {
  const _MaterialSavedConnectionsSidebarRow({
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
        buttonKey: const ValueKey('desktop_saved_connections'),
        label: 'C',
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
        key: const ValueKey('desktop_saved_connections'),
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
                    ConnectionWorkspaceCopy.allConnectionsAction,
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

class _MaterialSavedSystemsSidebarRow extends StatelessWidget {
  const _MaterialSavedSystemsSidebarRow({
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
        buttonKey: const ValueKey('desktop_saved_systems'),
        label: 'S',
        icon: Icons.dns_outlined,
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
        key: const ValueKey('desktop_saved_systems'),
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
                const Icon(Icons.dns_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    ConnectionWorkspaceCopy.manageSystemsAction,
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

extension on _MaterialDesktopSidebar {
  List<ConnectionLifecycleSectionPresentation> _lifecycleSections() {
    return connectionLifecycleSectionsFromState(
      state,
      isTransportConnected: _isTransportConnected,
    );
  }

  bool _isTransportConnected(String connectionId) {
    return workspaceController
            .bindingForConnectionId(connectionId)
            ?.agentAdapterClient
            .isConnected ==
        true;
  }

  List<ConnectionLifecycleFact> _sidebarFactsForRow(
    ConnectionLifecyclePresentation row,
  ) {
    ConnectionLifecycleFact? factMatching(
      bool Function(ConnectionLifecycleFact) test,
    ) {
      for (final fact in row.facts) {
        if (test(fact)) {
          return fact;
        }
      }
      return null;
    }

    final laneFact = factMatching(
      (fact) =>
          fact.label.startsWith('${ConnectionWorkspaceCopy.laneFactLabel}:'),
    );
    final settingsFact = factMatching(
      (fact) => fact.label.startsWith(
        '${ConnectionWorkspaceCopy.settingsFactLabel}:',
      ),
    );
    final transportFact = factMatching(
      (fact) => fact.label.startsWith(
        '${ConnectionWorkspaceCopy.transportFactLabel}:',
      ),
    );
    final hostFact = factMatching(
      (fact) =>
          fact.label.startsWith('${ConnectionWorkspaceCopy.hostFactLabel}:'),
    );
    final serverFact = factMatching(
      (fact) =>
          fact.label.startsWith('${ConnectionWorkspaceCopy.serverFactLabel}:'),
    );
    final configurationFact = factMatching(
      (fact) =>
          fact.label ==
          ConnectionWorkspaceCopy.laneConfigurationIncompleteStatus,
    );

    final secondaryFact =
        configurationFact ??
        settingsFact ??
        (row.connection.profile.isRemote &&
                (row.transportRecoveryPhase != null ||
                    row.liveReattachPhase != null ||
                    !row.isTransportConnected)
            ? transportFact
            : null) ??
        (row.connection.profile.isRemote &&
                row.remoteRuntime?.hostCapability.status !=
                    ConnectionRemoteHostCapabilityStatus.supported
            ? hostFact
            : null) ??
        (row.connection.profile.isRemote &&
                row.remoteRuntime?.server.status !=
                    ConnectionRemoteServerStatus.running
            ? serverFact
            : null);

    return <ConnectionLifecycleFact>[
      ...?(laneFact == null ? null : <ConnectionLifecycleFact>[laneFact]),
      ...?(secondaryFact == null || secondaryFact == laneFact
          ? null
          : <ConnectionLifecycleFact>[secondaryFact]),
    ];
  }
}
