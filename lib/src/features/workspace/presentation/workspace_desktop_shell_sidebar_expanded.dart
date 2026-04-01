part of 'workspace_desktop_shell.dart';

extension on _MaterialDesktopSidebar {
  List<Widget> _buildExpandedChildren(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _lifecycleSections();

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
      if (sections.isNotEmpty) const SizedBox(height: 16),
      ...sections.indexed.expand((entry) {
        final sectionIndex = entry.$1;
        final section = entry.$2;
        return <Widget>[
          _MaterialSidebarSectionTitle(
            title: section.title,
            trailingCount: section.rows.length,
          ),
          const SizedBox(height: 10),
          ...section.rows.indexed.map((rowEntry) {
            final rowIndex = rowEntry.$1;
            final row = rowEntry.$2;
            final connectionId = row.connection.id;
            final laneBinding = workspaceController.bindingForConnectionId(
              connectionId,
            );
            final isBusy =
                laneBinding?.sessionController.sessionState.isBusy ?? false;
            return Padding(
              padding: EdgeInsets.only(
                bottom: rowIndex == section.rows.length - 1 ? 0 : 10,
              ),
              child: _MaterialSidebarConnectionRow(
                row: row,
                facts: _sidebarFactsForRow(row),
                isSelected: row.isCurrent,
                isOpening: openingConnectionIds.contains(connectionId),
                onTap: () {
                  if (row.isLive) {
                    workspaceController.selectConnection(connectionId);
                    return;
                  }
                  unawaited(onOpenConnection(connectionId));
                },
                onClose: row.isLive && !isBusy
                    ? () =>
                          workspaceController.terminateConnection(connectionId)
                    : null,
              ),
            );
          }),
          if (sectionIndex != sections.length - 1) const SizedBox(height: 14),
        ];
      }),
    ];
  }
}
