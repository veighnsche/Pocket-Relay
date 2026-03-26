part of 'workspace_desktop_shell.dart';

extension on _MaterialDesktopSidebar {
  List<Widget> _buildExpandedChildren(BuildContext context) {
    final theme = Theme.of(context);
    final inventoryEntries = connectionWorkspaceInventoryEntriesFromState(state);

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
        title: ConnectionWorkspaceCopy.connectionInventorySectionTitle,
        trailingCount: inventoryEntries.length,
      ),
      const SizedBox(height: 10),
      ...inventoryEntries.indexed.map((entry) {
        final index = entry.$1;
        final inventoryEntry = entry.$2;
        final connectionId = inventoryEntry.connection.id;
        final laneBinding = workspaceController.bindingForConnectionId(connectionId);
        final isBusy = laneBinding?.sessionController.sessionState.isBusy ?? false;
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == inventoryEntries.length - 1 ? 0 : 10,
          ),
          child: _MaterialSidebarConnectionRow(
            entry: inventoryEntry,
            isSelected: inventoryEntry.isCurrent,
            isOpening: openingConnectionIds.contains(connectionId),
            onTap: () {
              if (inventoryEntry.isLive) {
                workspaceController.selectConnection(connectionId);
                return;
              }
              unawaited(onOpenConnection(connectionId));
            },
            onClose:
                inventoryEntry.isLive && !isBusy
                ? () => workspaceController.terminateConnection(connectionId)
                : null,
          ),
        );
      }),
      const SizedBox(height: 22),
      _MaterialSavedConnectionsSidebarRow(
        isSelected: state.isShowingSavedConnections,
        onTap: workspaceController.showSavedConnections,
      ),
    ];
  }
}
