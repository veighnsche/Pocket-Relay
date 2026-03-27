part of 'workspace_saved_connections_content.dart';

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
