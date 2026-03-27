part of 'workspace_desktop_shell.dart';

extension on _MaterialDesktopSidebar {
  List<Widget> _buildCollapsedChildren(BuildContext context) {
    final sections = _lifecycleSections();

    return <Widget>[
      if (onToggleCollapsed case final onPressed?)
        Align(
          child: _MaterialSidebarToggleButton(
            isCollapsed: true,
            onPressed: onPressed,
          ),
        ),
      if (onToggleCollapsed != null) const SizedBox(height: 14),
      ...sections.indexed.expand((entry) {
        final sectionIndex = entry.$1;
        final section = entry.$2;
        return <Widget>[
          ...section.rows.indexed.map((rowEntry) {
            final rowIndex = rowEntry.$1;
            final row = rowEntry.$2;
            final connectionId = row.connection.id;
            final needsSectionGap =
                rowIndex == section.rows.length - 1 &&
                sectionIndex != sections.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: needsSectionGap ? 14 : 10),
              child: _MaterialCollapsedSidebarButton(
                buttonKey: ValueKey<String>('desktop_connection_$connectionId'),
                label: _monogramFor(row.connection.profile.label),
                isSelected: row.isCurrent,
                showsActivityDot: row.sectionId ==
                    ConnectionLifecycleSectionId.needsAttention,
                onTap: () {
                  if (row.isLive) {
                    workspaceController.selectConnection(connectionId);
                    return;
                  }
                  unawaited(onOpenConnection(connectionId));
                },
              ),
            );
          }),
        ];
      }),
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
