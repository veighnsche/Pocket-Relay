import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/features/workspace/presentation/connection_lifecycle_presentation.dart';

class ConnectionLifecycleButtonAction {
  const ConnectionLifecycleButtonAction({
    required this.key,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final Key key;
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;
}

class ConnectionLifecycleSection extends StatelessWidget {
  const ConnectionLifecycleSection({
    super.key,
    required this.sectionId,
    required this.title,
    required this.count,
    required this.children,
  });

  final ConnectionLifecycleSectionId sectionId;
  final String title;
  final int count;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return KeyedSubtree(
      key: ValueKey<String>('connections_section_${sectionId.name}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PocketTintBadge(
                label: '$count',
                color: theme.colorScheme.primary,
                backgroundOpacity: 0.14,
                fontSize: 11,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class ConnectionLifecycleFacts extends StatelessWidget {
  const ConnectionLifecycleFacts({super.key, required this.facts});

  final List<ConnectionLifecycleFact> facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (facts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final fact in facts)
          DefaultTextStyle(
            style: theme.textTheme.labelSmall!.copyWith(
              fontWeight: FontWeight.w700,
            ),
            child: PocketTintBadge(
              label: fact.label,
              color: _colorForFactTone(theme, fact.tone),
              backgroundOpacity: 0.12,
              fontSize: 10.5,
            ),
          ),
      ],
    );
  }

  Color _colorForFactTone(ThemeData theme, ConnectionLifecycleFactTone tone) {
    return switch (tone) {
      ConnectionLifecycleFactTone.accent => theme.colorScheme.primary,
      ConnectionLifecycleFactTone.positive => theme.colorScheme.secondary,
      ConnectionLifecycleFactTone.warning => theme.colorScheme.tertiary,
      ConnectionLifecycleFactTone.neutral => theme.colorScheme.onSurfaceVariant,
    };
  }
}

class ConnectionLifecycleActionBar extends StatelessWidget {
  const ConnectionLifecycleActionBar({
    super.key,
    this.primaryAction,
    this.secondaryActions = const <ConnectionLifecycleButtonAction>[],
  });

  final ConnectionLifecycleButtonAction? primaryAction;
  final List<ConnectionLifecycleButtonAction> secondaryActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryAction = this.primaryAction;
    if (primaryAction == null && secondaryActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (primaryAction != null)
          FilledButton(
            key: primaryAction.key,
            onPressed: primaryAction.onPressed,
            child: Text(primaryAction.label),
          ),
        for (final action in secondaryActions)
          action.isDestructive
              ? TextButton(
                  key: action.key,
                  onPressed: action.onPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: Text(action.label),
                )
              : OutlinedButton(
                  key: action.key,
                  onPressed: action.onPressed,
                  child: Text(action.label),
                ),
      ],
    );
  }
}

class ConnectionLifecycleDetailActions extends StatelessWidget {
  const ConnectionLifecycleDetailActions({super.key, required this.actions});

  final List<ConnectionLifecycleButtonAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final action in actions)
          TextButton(
            key: action.key,
            onPressed: action.onPressed,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
            child: Text(action.label),
          ),
      ],
    );
  }
}

class ConnectionLifecycleRow extends StatelessWidget {
  const ConnectionLifecycleRow({
    super.key,
    required this.rowKey,
    required this.title,
    required this.subtitle,
    required this.facts,
    this.primaryAction,
    this.secondaryActions = const <ConnectionLifecycleButtonAction>[],
    this.detailActions = const <ConnectionLifecycleButtonAction>[],
  });

  final Key rowKey;
  final String title;
  final String subtitle;
  final List<ConnectionLifecycleFact> facts;
  final ConnectionLifecycleButtonAction? primaryAction;
  final List<ConnectionLifecycleButtonAction> secondaryActions;
  final List<ConnectionLifecycleButtonAction> detailActions;

  @override
  Widget build(BuildContext context) {
    final palette = context.pocketPalette;
    final theme = Theme.of(context);

    return PocketPanelSurface(
      key: rowKey,
      backgroundColor: palette.surface.withValues(alpha: 0.9),
      borderColor: palette.surfaceBorder,
      padding: PocketSpacing.panelPadding,
      radius: 12,
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
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ConnectionLifecycleFacts(facts: facts),
          ],
          if (detailActions.isNotEmpty) ...[
            const SizedBox(height: 10),
            ConnectionLifecycleDetailActions(actions: detailActions),
          ],
          if (primaryAction != null || secondaryActions.isNotEmpty) ...[
            const SizedBox(height: 16),
            ConnectionLifecycleActionBar(
              primaryAction: primaryAction,
              secondaryActions: secondaryActions,
            ),
          ],
        ],
      ),
    );
  }
}
