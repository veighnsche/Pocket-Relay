part of 'workspace_desktop_shell.dart';

extension on _MaterialDesktopSidebar {
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
