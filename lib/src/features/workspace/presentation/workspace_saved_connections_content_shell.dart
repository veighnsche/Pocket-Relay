part of 'workspace_saved_connections_content.dart';

extension on _ConnectionWorkspaceSavedConnectionsContentState {
  Widget _buildMaterialContent(
    BuildContext context, {
    required ConnectionWorkspaceState workspaceState,
    required List<ConnectionWorkspaceInventoryEntry> inventoryEntries,
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
        if (inventoryEntries.isEmpty)
          const _SavedConnectionsEmptyState()
        else
          ...inventoryEntries.indexed.map((entry) {
            final index = entry.$1;
            final inventoryEntry = entry.$2;
            final connection = inventoryEntry.connection;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == inventoryEntries.length - 1 ? 0 : 12,
              ),
              child: _SavedConnectionItem(
                connectionId: connection.id,
                title: connection.profile.label,
                subtitle: _connectionSubtitle(connection.profile),
                statusBadges: _statusBadgesFor(
                  context,
                  inventoryEntry.badges,
                ),
                remoteStatusSummary: inventoryEntry.remoteStatusSummary,
                isLive: inventoryEntry.isLive,
                isOpening: _instantiatingConnectionIds.contains(connection.id),
                isEditing: _editingConnectionIds.contains(connection.id),
                isDeleting: _deletingConnectionIds.contains(connection.id),
                onOpen: () => _openConnection(connection),
                onEdit: () => _editConnection(connection),
                onDelete: inventoryEntry.isLive
                    ? null
                    : () => _deleteConnection(connection.id),
              ),
            );
          }),
      ],
    );
  }
}
