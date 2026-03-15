import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';

enum ChatEmptyStateVisualStyle { material, cupertino }

class ChatEmptyStateBody extends StatelessWidget {
  const ChatEmptyStateBody({
    super.key,
    required this.isConfigured,
    required this.onConfigure,
    required this.style,
  });

  final bool isConfigured;
  final VoidCallback onConfigure;
  final ChatEmptyStateVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: _buildCard(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeroIcon(context),
          const SizedBox(height: 18),
          Text(
            'Remote Codex, cleaned up for a phone screen',
            textAlign: TextAlign.center,
            style: _titleStyle(context),
          ),
          const SizedBox(height: 10),
          Text(
            isConfigured
                ? 'Send a prompt below. Pocket Relay keeps your remote Codex session running and turns the live stream into readable phone-sized cards.'
                : 'Start by configuring an SSH target. After that, Pocket Relay keeps a remote Codex session open and makes the interaction readable on mobile.',
            textAlign: TextAlign.center,
            style: _bodyStyle(context),
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children:
                const <String>[
                      'SSH into the dev box',
                      'Keep Codex app-server live',
                      'Handle approvals and user input',
                      'Show commands and answers as cards',
                    ]
                    .map((label) => _ChecklistPill(label: label, style: style))
                    .toList(growable: false),
          ),
          if (!isConfigured) ...[
            const SizedBox(height: 22),
            _buildConfigureButton(),
          ],
        ],
      ),
    );

    return switch (style) {
      ChatEmptyStateVisualStyle.material => _buildMaterialCard(
        context,
        content,
      ),
      ChatEmptyStateVisualStyle.cupertino => _buildCupertinoCard(content),
    };
  }

  Widget _buildMaterialCard(BuildContext context, Widget content) {
    final palette = context.pocketPalette;

    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: palette.surfaceBorder),
      ),
      child: content,
    );
  }

  Widget _buildCupertinoCard(Widget content) {
    return Builder(
      builder: (context) {
        final surfaceColor = CupertinoDynamicColor.resolve(
          CupertinoColors.secondarySystemGroupedBackground,
          context,
        ).withValues(alpha: 0.92);
        final borderColor = CupertinoDynamicColor.resolve(
          CupertinoColors.separator,
          context,
        ).withValues(alpha: 0.16);
        const shapeRadius = BorderRadius.all(Radius.circular(28));

        return ClipRSuperellipse(
          borderRadius: shapeRadius,
          child: DecoratedBox(
            key: const ValueKey('cupertino_empty_state_card'),
            decoration: ShapeDecoration(
              color: surfaceColor,
              shape: RoundedSuperellipseBorder(
                borderRadius: shapeRadius,
                side: BorderSide(color: borderColor),
              ),
            ),
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildHeroIcon(BuildContext context) {
    return switch (style) {
      ChatEmptyStateVisualStyle.material => _buildMaterialHeroIcon(context),
      ChatEmptyStateVisualStyle.cupertino => _buildCupertinoHeroIcon(context),
    };
  }

  Widget _buildMaterialHeroIcon(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: palette.subtleSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        Icons.phone_android,
        size: 30,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildCupertinoHeroIcon(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(
        CupertinoIcons.rectangle_stack_badge_person_crop,
        size: 30,
        color: CupertinoColors.activeBlue.resolveFrom(context),
      ),
    );
  }

  TextStyle _titleStyle(BuildContext context) {
    return switch (style) {
      ChatEmptyStateVisualStyle.material => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.2,
      ),
      ChatEmptyStateVisualStyle.cupertino => TextStyle(
        fontSize: 25,
        fontWeight: FontWeight.w700,
        color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
        height: 1.18,
      ),
    };
  }

  TextStyle _bodyStyle(BuildContext context) {
    return switch (style) {
      ChatEmptyStateVisualStyle.material => TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.5,
      ),
      ChatEmptyStateVisualStyle.cupertino => TextStyle(
        fontSize: 15,
        height: 1.45,
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.secondaryLabel,
          context,
        ),
      ),
    };
  }

  Widget _buildConfigureButton() {
    return switch (style) {
      ChatEmptyStateVisualStyle.material => FilledButton.icon(
        onPressed: onConfigure,
        icon: const Icon(Icons.settings),
        label: const Text('Configure remote'),
      ),
      ChatEmptyStateVisualStyle.cupertino => CupertinoButton.filled(
        onPressed: onConfigure,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.settings, size: 18),
            SizedBox(width: 8),
            Text('Configure remote'),
          ],
        ),
      ),
    };
  }
}

class _ChecklistPill extends StatelessWidget {
  const _ChecklistPill({required this.label, required this.style});

  final String label;
  final ChatEmptyStateVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      ChatEmptyStateVisualStyle.material => _buildMaterialPill(context),
      ChatEmptyStateVisualStyle.cupertino => _buildCupertinoPill(context),
    };
  }

  Widget _buildMaterialPill(BuildContext context) {
    final palette = context.pocketPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.subtleSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }

  Widget _buildCupertinoPill(BuildContext context) {
    final fillColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondarySystemFill,
      context,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.label,
              context,
            ),
          ),
        ),
      ),
    );
  }
}
