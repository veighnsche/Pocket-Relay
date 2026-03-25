part of 'workspace_dormant_roster_content.dart';

class _SavedConnectionsEmptyState extends StatelessWidget {
  const _SavedConnectionsEmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);

    return PocketPanelSurface(
      backgroundColor: palette.surface.withValues(alpha: 0.86),
      borderColor: palette.surfaceBorder,
      padding: const EdgeInsets.all(PocketSpacing.xxl),
      radius: _savedConnectionsPanelRadius,
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
            ConnectionWorkspaceCopy.emptyWorkspaceTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PocketSpacing.xs),
          Text(
            ConnectionWorkspaceCopy.emptyWorkspaceMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedConnectionItem extends StatelessWidget {
  const _SavedConnectionItem({
    required this.connectionId,
    required this.title,
    required this.subtitle,
    required this.statusBadges,
    required this.remoteStatusSummary,
    required this.isLive,
    required this.isOpening,
    required this.isEditing,
    required this.isDeleting,
    required this.onOpen,
    required this.onEdit,
    this.onDelete,
  });

  final String connectionId;
  final String title;
  final String subtitle;
  final List<Widget> statusBadges;
  final String? remoteStatusSummary;
  final bool isLive;
  final bool isOpening;
  final bool isEditing;
  final bool isDeleting;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);
    final isBusy = isOpening || isEditing || isDeleting;

    return PocketPanelSurface(
      key: ValueKey<String>('saved_connection_$connectionId'),
      backgroundColor: palette.surface.withValues(alpha: 0.9),
      borderColor: palette.surfaceBorder,
      padding: PocketSpacing.panelPadding,
      radius: _savedConnectionsPanelRadius,
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
          if (statusBadges.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: statusBadges),
          ],
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (remoteStatusSummary case final summary?) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton(
                key: ValueKey<String>('open_connection_$connectionId'),
                onPressed: isBusy ? null : onOpen,
                child: Text(
                  isOpening
                      ? ConnectionWorkspaceCopy.openingLaneAction
                      : isLive
                      ? ConnectionWorkspaceCopy.goToLaneAction
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
              if (onDelete case final deleteAction?)
                TextButton(
                  key: ValueKey<String>('delete_$connectionId'),
                  onPressed: isBusy ? null : deleteAction,
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
