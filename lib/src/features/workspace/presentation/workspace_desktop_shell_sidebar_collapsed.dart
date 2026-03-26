part of 'workspace_desktop_shell.dart';

extension on _MaterialDesktopSidebar {
  List<Widget> _buildCollapsedChildren(BuildContext context) {
    final inventoryEntries = connectionWorkspaceInventoryEntriesFromState(state);

    return <Widget>[
      if (onToggleCollapsed case final onPressed?)
        Align(
          child: _MaterialSidebarToggleButton(
            isCollapsed: true,
            onPressed: onPressed,
          ),
        ),
      if (onToggleCollapsed != null) const SizedBox(height: 14),
      ...inventoryEntries.indexed.map((entry) {
        final index = entry.$1;
        final inventoryEntry = entry.$2;
        final connectionId = inventoryEntry.connection.id;
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == inventoryEntries.length - 1 ? 0 : 10,
          ),
          child: _MaterialCollapsedSidebarButton(
            buttonKey: ValueKey<String>('desktop_connection_$connectionId'),
            label: _monogramFor(inventoryEntry.connection.profile.label),
            isSelected: inventoryEntry.isCurrent,
            showsActivityDot: state.requiresReconnect(connectionId),
            onTap: () {
              if (inventoryEntry.isLive) {
                workspaceController.selectConnection(connectionId);
                return;
              }
              unawaited(onOpenConnection(connectionId));
            },
          ),
        );
      }),
      const SizedBox(height: 14),
      _MaterialSavedConnectionsSidebarRow(
        isSelected: state.isShowingSavedConnections,
        isCollapsed: true,
        onTap: workspaceController.showSavedConnections,
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
