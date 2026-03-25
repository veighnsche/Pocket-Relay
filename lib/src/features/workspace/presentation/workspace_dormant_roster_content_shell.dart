part of 'workspace_dormant_roster_content.dart';

extension on _ConnectionWorkspaceSavedConnectionsContentState {
  Widget _buildMaterialContent(
    BuildContext context, {
    required ConnectionWorkspaceState workspaceState,
    required List<SavedConnectionSummary> savedConnections,
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
        if (savedConnections.isEmpty)
          const _SavedConnectionsEmptyState()
        else
          ...savedConnections.indexed.map((entry) {
            final index = entry.$1;
            final connection = entry.$2;
            final isLive = workspaceState.isConnectionLive(connection.id);
            final isSelected =
                isLive && workspaceState.selectedConnectionId == connection.id;
            final reconnectRequirement = workspaceState.reconnectRequirementFor(
              connection.id,
            );
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == savedConnections.length - 1 ? 0 : 12,
              ),
              child: _SavedConnectionItem(
                connectionId: connection.id,
                title: connection.profile.label,
                subtitle: _connectionSubtitle(connection.profile),
                statusBadges: _statusBadgesFor(
                  context,
                  connectionId: connection.id,
                  isLive: isLive,
                  isSelected: isSelected,
                  reconnectRequirement: reconnectRequirement,
                ),
                remoteStatusSummary:
                    ConnectionWorkspaceCopy.savedConnectionRemoteStatusSummary(
                      connection.profile,
                      workspaceState.remoteRuntimeFor(connection.id),
                    ),
                isLive: isLive,
                isOpening: _instantiatingConnectionIds.contains(connection.id),
                isEditing: _editingConnectionIds.contains(connection.id),
                isDeleting: _deletingConnectionIds.contains(connection.id),
                onOpen: () => _openConnection(connection.id),
                onEdit: () => _editConnection(connection),
                onDelete: isLive
                    ? null
                    : () => _deleteConnection(connection.id),
              ),
            );
          }),
      ],
    );
  }
}
