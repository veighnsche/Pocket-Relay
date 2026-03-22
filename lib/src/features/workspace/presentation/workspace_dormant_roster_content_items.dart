part of 'workspace_dormant_roster_content.dart';

class _DormantConnectionsEmptyState extends StatelessWidget {
  const _DormantConnectionsEmptyState({
    required this.isEmptyWorkspace,
    required this.canReturnToLane,
    required this.onReturnToLane,
  });

  final bool isEmptyWorkspace;
  final bool canReturnToLane;
  final VoidCallback onReturnToLane;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);

    return PocketPanelSurface(
      backgroundColor: palette.surface.withValues(alpha: 0.86),
      borderColor: palette.surfaceBorder,
      padding: const EdgeInsets.all(PocketSpacing.xxl),
      radius: _dormantRosterPanelRadius,
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: palette.shadowColor,
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConnectionWorkspaceCopy.emptySavedConnectionsTitle(
              isEmptyWorkspace: isEmptyWorkspace,
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PocketSpacing.xs),
          Text(
            ConnectionWorkspaceCopy.emptySavedConnectionsMessage(
              isEmptyWorkspace: isEmptyWorkspace,
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (canReturnToLane) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onReturnToLane,
              child: const Text(ConnectionWorkspaceCopy.returnToOpenLaneAction),
            ),
          ],
        ],
      ),
    );
  }
}

class _DormantConnectionItem extends StatelessWidget {
  const _DormantConnectionItem({
    required this.connectionId,
    required this.title,
    required this.subtitle,
    required this.isOpening,
    required this.isEditing,
    required this.isDeleting,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final String connectionId;
  final String title;
  final String subtitle;
  final bool isOpening;
  final bool isEditing;
  final bool isDeleting;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);
    final isBusy = isOpening || isEditing || isDeleting;

    return PocketPanelSurface(
      key: ValueKey<String>('dormant_connection_$connectionId'),
      backgroundColor: palette.surface.withValues(alpha: 0.9),
      borderColor: palette.surfaceBorder,
      padding: PocketSpacing.panelPadding,
      radius: _dormantRosterPanelRadius,
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: palette.shadowColor,
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                key: ValueKey<String>('instantiate_$connectionId'),
                onPressed: isBusy ? null : onOpen,
                child: Text(
                  isOpening
                      ? ConnectionWorkspaceCopy.openingLaneAction
                      : ConnectionWorkspaceCopy.openLaneAction,
                ),
              ),
              OutlinedButton(
                key: ValueKey<String>('edit_$connectionId'),
                onPressed: isBusy ? null : onEdit,
                child: Text(
                  isEditing
                      ? ConnectionWorkspaceCopy.saveProgress
                      : ConnectionWorkspaceCopy.editAction,
                ),
              ),
              TextButton(
                key: ValueKey<String>('delete_$connectionId'),
                onPressed: isBusy ? null : onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(
                  isDeleting
                      ? ConnectionWorkspaceCopy.deleteProgress
                      : ConnectionWorkspaceCopy.deleteAction,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
