part of 'workspace_dormant_roster_content.dart';

extension on _ConnectionWorkspaceDormantRosterContentState {
  Widget _buildMaterialContent(
    BuildContext context, {
    required ConnectionWorkspaceState workspaceState,
    required List<SavedConnectionSummary> dormantConnections,
  }) {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text(
          ConnectionWorkspaceCopy.savedConnectionsTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          widget.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('add_connection'),
            onPressed: _isCreatingConnection ? null : _createConnection,
            icon: const Icon(Icons.add),
            label: Text(
              _isCreatingConnection
                  ? ConnectionWorkspaceCopy.addConnectionProgress
                  : ConnectionWorkspaceCopy.addConnectionAction,
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (dormantConnections.isEmpty)
          _DormantConnectionsEmptyState(
            isEmptyWorkspace: workspaceState.isEmptyWorkspace,
            canReturnToLane: workspaceState.selectedConnectionId != null,
            onReturnToLane: _handleReturnToLiveLane,
          )
        else
          ...dormantConnections.indexed.map((entry) {
            final index = entry.$1;
            final connection = entry.$2;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == dormantConnections.length - 1 ? 0 : 12,
              ),
              child: _DormantConnectionCard(
                connectionId: connection.id,
                title: connection.profile.label,
                subtitle: _connectionSubtitle(connection.profile),
                isOpening: _instantiatingConnectionIds.contains(connection.id),
                isEditing: _editingConnectionIds.contains(connection.id),
                isDeleting: _deletingConnectionIds.contains(connection.id),
                onOpen: () => _instantiateConnection(connection.id),
                onEdit: () => _editConnection(connection),
                onDelete: () => _deleteConnection(connection.id),
              ),
            );
          }),
      ],
    );
  }
}
