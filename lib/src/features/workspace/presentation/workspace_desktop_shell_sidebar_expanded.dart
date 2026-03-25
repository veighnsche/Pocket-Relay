part of 'workspace_desktop_shell.dart';

extension on _MaterialDesktopSidebar {
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
        final isBusy =
            laneBinding?.sessionController.sessionState.isBusy ?? false;
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
            reconnectRequirement: state.reconnectRequirementFor(connectionId),
            isSelected:
                state.isShowingLiveLane &&
                state.selectedConnectionId == connectionId,
            onTap: () => workspaceController.selectConnection(connectionId),
            canClose: !isBusy,
            onClose: () =>
                workspaceController.terminateConnection(connectionId),
          ),
        );
      }),
      const SizedBox(height: 22),
      _MaterialSidebarSectionTitle(
        title: ConnectionWorkspaceCopy.savedSectionTitle,
        trailingCount: state.savedConnectionIds.length,
      ),
      const SizedBox(height: 10),
      _MaterialSavedConnectionsSidebarRow(
        isSelected: state.isShowingSavedConnections,
        onTap: workspaceController.showSavedConnections,
      ),
      if (state.savedConnectionIds.isNotEmpty) ...[
        const SizedBox(height: 10),
        ...state.savedConnectionIds.indexed.map((entry) {
          final index = entry.$1;
          final connectionId = entry.$2;
          final summary = state.catalog.connectionForId(connectionId);
          if (summary == null) {
            return const SizedBox.shrink();
          }

          final isOpen = state.isConnectionLive(connectionId);
          final inventoryLabel =
              ConnectionWorkspaceCopy.compactSavedConnectionLabel(
                summary.profile,
              ) +
              (isOpen
                  ? ' · ${ConnectionWorkspaceCopy.openConnectionBadge}'
                  : '');

          return Padding(
            padding: EdgeInsets.only(left: 12, top: index == 0 ? 0 : 8),
            child: Text(
              '${summary.profile.label} · $inventoryLabel',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }),
      ],
    ];
  }
}
