import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';

enum ChatEmptyStateVisualStyle { material, cupertino }

class ChatEmptyStateBody extends StatelessWidget {
  const ChatEmptyStateBody({
    super.key,
    required this.isConfigured,
    required this.connectionMode,
    required this.platformBehavior,
    required this.onConfigure,
    this.onSelectConnectionMode,
    required this.style,
  });

  final bool isConfigured;
  final ConnectionMode connectionMode;
  final PocketPlatformBehavior platformBehavior;
  final VoidCallback onConfigure;
  final ValueChanged<ConnectionMode>? onSelectConnectionMode;
  final ChatEmptyStateVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = platformBehavior.isDesktopExperience;
        final maxWidth = isDesktop ? 820.0 : 640.0;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 28 : 24,
            vertical: isDesktop ? 28 : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: isDesktop
                    ? _buildDesktopCard(context, constraints.maxWidth)
                    : _buildMobileCard(context),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopCard(BuildContext context, double availableWidth) {
    final supportsLocalConnectionMode =
        platformBehavior.supportsLocalConnectionMode;
    final content = Padding(
      padding: EdgeInsets.all(availableWidth >= 720 ? 32 : 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeroIcon(context, desktop: true),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Text(
                  _desktopTitle(),
                  textAlign: TextAlign.center,
                  style: _titleStyle(context, desktop: true),
                ),
                const SizedBox(height: 12),
                Text(
                  _desktopBody(),
                  textAlign: TextAlign.center,
                  style: _bodyStyle(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (isConfigured) ...[
            _buildDesktopStatusCard(context),
            const SizedBox(height: 16),
            _buildDetailsPanel(
              context,
              items: _desktopDetails(),
              maxWidth: 560,
            ),
          ] else if (supportsLocalConnectionMode) ...[
            _buildDesktopRoutePanel(context, availableWidth),
            const SizedBox(height: 18),
            _buildConfigureButton(desktop: true),
          ] else ...[
            _buildDetailsPanel(context, items: _mobileDetails(), maxWidth: 560),
            const SizedBox(height: 18),
            _buildConfigureButton(
              desktop: true,
              supportsLocalConnectionMode: false,
            ),
          ],
        ],
      ),
    );

    return _buildCard(context, content);
  }

  Widget _buildMobileCard(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeroIcon(context, desktop: false),
          const SizedBox(height: 18),
          Text(
            isConfigured
                ? 'Remote Codex, ready to continue'
                : 'Remote Codex, ready when you are',
            textAlign: TextAlign.center,
            style: _titleStyle(context, desktop: false),
          ),
          const SizedBox(height: 10),
          Text(
            isConfigured
                ? 'Send the next prompt below. Pocket Relay keeps the remote session readable and keeps approvals in the same flow.'
                : 'Configure one remote workspace, then keep prompts, approvals, and live output readable from your phone.',
            textAlign: TextAlign.center,
            style: _bodyStyle(context),
          ),
          if (!isConfigured) ...[
            const SizedBox(height: 20),
            _buildConfigureButton(desktop: false, fullWidth: true),
          ],
          const SizedBox(height: 22),
          _buildDetailsPanel(context, items: _mobileDetails(), maxWidth: 520),
        ],
      ),
    );

    return _buildCard(context, content);
  }

  Widget _buildCard(BuildContext context, Widget content) {
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.surface,
            palette.subtleSurface.withValues(alpha: 0.55),
          ],
        ),
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

  Widget _buildDesktopRoutePanel(BuildContext context, double availableWidth) {
    final cardWidth = availableWidth >= 720 ? 320.0 : double.infinity;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: cardWidth,
          child: _DesktopRouteCard(
            style: style,
            title: 'Local',
            subtitle:
                'Run `codex app-server` here and keep the repo and tools on this machine.',
            isActive: connectionMode == ConnectionMode.local,
            onTap: onSelectConnectionMode == null
                ? null
                : () => onSelectConnectionMode!(ConnectionMode.local),
          ),
        ),
        SizedBox(
          width: cardWidth,
          child: _DesktopRouteCard(
            style: style,
            title: 'Remote',
            subtitle:
                'SSH to a developer box, run Codex there, and stream the session back to this desktop.',
            isActive: connectionMode == ConnectionMode.remote,
            onTap: onSelectConnectionMode == null
                ? null
                : () => onSelectConnectionMode!(ConnectionMode.remote),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopStatusCard(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: _DesktopRouteCard(
        style: style,
        title: connectionMode == ConnectionMode.local
            ? 'Current route: Local'
            : 'Current route: Remote',
        subtitle: connectionMode == ConnectionMode.local
            ? 'The workspace and execution stay on this desktop.'
            : 'This desktop stays attached to Codex running on your developer box.',
        isActive: true,
      ),
    );
  }

  Widget _buildDetailsPanel(
    BuildContext context, {
    required List<_EmptyStateDetail> items,
    required double maxWidth,
  }) {
    final (background, border, divider) = switch (style) {
      ChatEmptyStateVisualStyle.material => (
        context.pocketPalette.subtleSurface.withValues(alpha: 0.72),
        context.pocketPalette.surfaceBorder.withValues(alpha: 0.9),
        context.pocketPalette.surfaceBorder.withValues(alpha: 0.65),
      ),
      ChatEmptyStateVisualStyle.cupertino => (
        CupertinoDynamicColor.resolve(
          CupertinoColors.tertiarySystemGroupedBackground,
          context,
        ),
        CupertinoDynamicColor.resolve(
          CupertinoColors.separator,
          context,
        ).withValues(alpha: 0.18),
        CupertinoDynamicColor.resolve(
          CupertinoColors.separator,
          context,
        ).withValues(alpha: 0.12),
      ),
    };

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border),
        ),
        child: Column(
          children: items.indexed
              .map((entry) {
                final index = entry.$1;
                final item = entry.$2;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: _EmptyStateDetailRow(item: item, style: style),
                    ),
                    if (index != items.length - 1)
                      Divider(height: 1, thickness: 1, color: divider),
                  ],
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildHeroIcon(BuildContext context, {required bool desktop}) {
    return switch (style) {
      ChatEmptyStateVisualStyle.material => _buildMaterialHeroIcon(
        context,
        desktop: desktop,
      ),
      ChatEmptyStateVisualStyle.cupertino => _buildCupertinoHeroIcon(
        context,
        desktop: desktop,
      ),
    };
  }

  Widget _buildMaterialHeroIcon(BuildContext context, {required bool desktop}) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return Container(
      width: desktop ? 76 : 64,
      height: desktop ? 76 : 64,
      decoration: BoxDecoration(
        color: palette.subtleSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(
        desktop ? Icons.laptop_mac_rounded : Icons.phone_android,
        size: desktop ? 34 : 30,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildCupertinoHeroIcon(
    BuildContext context, {
    required bool desktop,
  }) {
    return Container(
      width: desktop ? 78 : 66,
      height: desktop ? 78 : 66,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Icon(
        desktop
            ? CupertinoIcons.desktopcomputer
            : CupertinoIcons.rectangle_stack_badge_person_crop,
        size: desktop ? 34 : 30,
        color: CupertinoColors.activeBlue.resolveFrom(context),
      ),
    );
  }

  TextStyle _titleStyle(BuildContext context, {required bool desktop}) {
    return switch (style) {
      ChatEmptyStateVisualStyle.material => TextStyle(
        fontSize: desktop ? 30 : 24,
        fontWeight: FontWeight.w800,
        height: 1.14,
      ),
      ChatEmptyStateVisualStyle.cupertino => TextStyle(
        fontSize: desktop ? 31 : 25,
        fontWeight: FontWeight.w700,
        color: CupertinoDynamicColor.resolve(CupertinoColors.label, context),
        height: 1.15,
      ),
    };
  }

  TextStyle _bodyStyle(BuildContext context) {
    return switch (style) {
      ChatEmptyStateVisualStyle.material => TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        height: 1.55,
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

  Widget _buildConfigureButton({
    required bool desktop,
    bool supportsLocalConnectionMode = true,
    bool fullWidth = false,
  }) {
    final label = desktop && supportsLocalConnectionMode
        ? 'Configure connection'
        : 'Configure remote';
    final button = switch (style) {
      ChatEmptyStateVisualStyle.material => FilledButton.icon(
        onPressed: onConfigure,
        icon: const Icon(Icons.settings),
        label: Text(label),
      ),
      ChatEmptyStateVisualStyle.cupertino => CupertinoButton.filled(
        onPressed: onConfigure,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Icon(CupertinoIcons.settings, size: 18),
            Text(label),
          ],
        ),
      ),
    };

    if (!fullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }

  String _desktopTitle() {
    if (!isConfigured) {
      return platformBehavior.supportsLocalConnectionMode
          ? 'Choose how this desktop reaches Codex'
          : 'Remote Codex is ready on this desktop';
    }

    return switch (connectionMode) {
      ConnectionMode.local => 'Local Codex is ready on this desktop',
      ConnectionMode.remote => 'Remote Codex is routed through this desktop',
    };
  }

  String _desktopBody() {
    if (!isConfigured) {
      return platformBehavior.supportsLocalConnectionMode
          ? 'Use local when the repo already lives on this machine. Use remote when the authoritative workspace stays on a developer box.'
          : 'Configure one remote workspace, then keep prompts, approvals, and live output readable from this desktop.';
    }

    return switch (connectionMode) {
      ConnectionMode.local =>
        'Send a prompt below. Pocket Relay will keep the local Codex session readable while the workspace and execution stay on this machine.',
      ConnectionMode.remote =>
        'Send a prompt below. Pocket Relay will stay attached to your developer box and keep the remote session readable in one transcript.',
    };
  }

  List<_EmptyStateDetail> _desktopDetails() {
    return switch (connectionMode) {
      ConnectionMode.local => const <_EmptyStateDetail>[
        _EmptyStateDetail(
          title: 'Next prompt',
          body: 'Continue the local workspace from the composer below.',
          materialIcon: Icons.play_circle_outline_rounded,
          cupertinoIcon: CupertinoIcons.play_circle,
        ),
        _EmptyStateDetail(
          title: 'Live transcript',
          body: 'Commands, edits, and replies stay readable in one place.',
          materialIcon: Icons.subject_rounded,
          cupertinoIcon: CupertinoIcons.doc_text,
        ),
        _EmptyStateDetail(
          title: 'Interruptions',
          body: 'Approvals and follow-up forms stay inline.',
          materialIcon: Icons.rule_folder_outlined,
          cupertinoIcon: CupertinoIcons.check_mark_circled,
        ),
      ],
      ConnectionMode.remote => const <_EmptyStateDetail>[
        _EmptyStateDetail(
          title: 'Next prompt',
          body: 'Continue the remote workspace from the composer below.',
          materialIcon: Icons.play_circle_outline_rounded,
          cupertinoIcon: CupertinoIcons.play_circle,
        ),
        _EmptyStateDetail(
          title: 'Live transcript',
          body: 'Commands, edits, and replies stay readable in one place.',
          materialIcon: Icons.subject_rounded,
          cupertinoIcon: CupertinoIcons.doc_text,
        ),
        _EmptyStateDetail(
          title: 'Interruptions',
          body: 'Approvals and follow-up forms stay inline.',
          materialIcon: Icons.rule_folder_outlined,
          cupertinoIcon: CupertinoIcons.check_mark_circled,
        ),
      ],
    };
  }

  List<_EmptyStateDetail> _mobileDetails() {
    if (isConfigured) {
      return const <_EmptyStateDetail>[
        _EmptyStateDetail(
          title: 'Next prompt',
          body: 'Resume the remote session from the composer below.',
          materialIcon: Icons.send_outlined,
          cupertinoIcon: CupertinoIcons.arrow_up_circle,
        ),
        _EmptyStateDetail(
          title: 'Live transcript',
          body:
              'Commands, edits, and replies land in order while the turn runs.',
          materialIcon: Icons.view_stream_outlined,
          cupertinoIcon: CupertinoIcons.text_alignleft,
        ),
        _EmptyStateDetail(
          title: 'Interruptions',
          body:
              'Approve commands or answer follow-up requests without leaving the session.',
          materialIcon: Icons.fact_check_outlined,
          cupertinoIcon: CupertinoIcons.check_mark_circled,
        ),
      ];
    }

    return const <_EmptyStateDetail>[
      _EmptyStateDetail(
        title: 'Connect once',
        body:
            'Point Pocket Relay at your SSH workspace and keep it ready for the next prompt.',
        materialIcon: Icons.link_rounded,
        cupertinoIcon: CupertinoIcons.link,
      ),
      _EmptyStateDetail(
        title: 'Read the live turn',
        body:
            'Commands, edits, and replies stay in one scroll instead of a terminal wall.',
        materialIcon: Icons.menu_book_outlined,
        cupertinoIcon: CupertinoIcons.doc_plaintext,
      ),
      _EmptyStateDetail(
        title: 'Handle interruptions',
        body: 'Approvals and follow-up forms stay in the same flow.',
        materialIcon: Icons.pending_actions_outlined,
        cupertinoIcon: CupertinoIcons.hand_raised,
      ),
    ];
  }
}

class _DesktopRouteCard extends StatelessWidget {
  const _DesktopRouteCard({
    required this.style,
    required this.title,
    required this.subtitle,
    required this.isActive,
    this.onTap,
  });

  final ChatEmptyStateVisualStyle style;
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (background, border, titleColor, bodyColor) = switch (style) {
      ChatEmptyStateVisualStyle.material => (
        isActive
            ? context.pocketPalette.subtleSurface
            : context.pocketPalette.surface,
        isActive
            ? context.pocketPalette.surfaceBorder.withValues(alpha: 0.9)
            : context.pocketPalette.surfaceBorder,
        Theme.of(context).colorScheme.onSurface,
        Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      ChatEmptyStateVisualStyle.cupertino => (
        CupertinoDynamicColor.resolve(
          isActive
              ? CupertinoColors.tertiarySystemGroupedBackground
              : CupertinoColors.secondarySystemGroupedBackground,
          context,
        ),
        CupertinoDynamicColor.resolve(
          CupertinoColors.separator,
          context,
        ).withValues(alpha: isActive ? 0.26 : 0.14),
        CupertinoDynamicColor.resolve(CupertinoColors.label, context),
        CupertinoDynamicColor.resolve(CupertinoColors.secondaryLabel, context),
      ),
    };

    final indicatorColor = isActive ? titleColor : bodyColor;
    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: titleColor,
                    ),
                  ),
                ),
                Icon(
                  isActive
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: indicatorColor,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, height: 1.45, color: bodyColor),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Semantics(
      button: true,
      selected: isActive,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: card,
        ),
      ),
    );
  }
}

class _EmptyStateDetail {
  const _EmptyStateDetail({
    required this.title,
    required this.body,
    required this.materialIcon,
    required this.cupertinoIcon,
  });

  final String title;
  final String body;
  final IconData materialIcon;
  final IconData cupertinoIcon;
}

class _EmptyStateDetailRow extends StatelessWidget {
  const _EmptyStateDetailRow({required this.item, required this.style});

  final _EmptyStateDetail item;
  final ChatEmptyStateVisualStyle style;

  @override
  Widget build(BuildContext context) {
    return switch (style) {
      ChatEmptyStateVisualStyle.material => _buildMaterialRow(context),
      ChatEmptyStateVisualStyle.cupertino => _buildCupertinoRow(context),
    };
  }

  Widget _buildMaterialRow(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item.materialIcon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.body,
                style: TextStyle(
                  height: 1.45,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCupertinoRow(BuildContext context) {
    final iconBackground = CupertinoDynamicColor.resolve(
      CupertinoColors.secondarySystemFill,
      context,
    );
    final titleColor = CupertinoDynamicColor.resolve(
      CupertinoColors.label,
      context,
    );
    final bodyColor = CupertinoDynamicColor.resolve(
      CupertinoColors.secondaryLabel,
      context,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              item.cupertinoIcon,
              size: 18,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(item.body, style: TextStyle(height: 1.45, color: bodyColor)),
            ],
          ),
        ),
      ],
    );
  }
}
