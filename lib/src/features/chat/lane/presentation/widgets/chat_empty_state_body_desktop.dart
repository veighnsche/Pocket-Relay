part of 'chat_empty_state_body.dart';

extension on ChatEmptyStateBody {
  Widget _buildDesktopShell(BuildContext context, double availableWidth) {
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
                if (supplementalContent != null) ...[
                  const SizedBox(height: 20),
                  supplementalContent!,
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (isConfigured) ...[
            _buildDesktopStatusSurface(context),
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

    return _buildShell(context, content);
  }

  Widget _buildDesktopRoutePanel(BuildContext context, double availableWidth) {
    final optionWidth = availableWidth >= 720 ? 320.0 : double.infinity;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: optionWidth,
          child: _DesktopRouteOption(
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
          width: optionWidth,
          child: _DesktopRouteOption(
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

  Widget _buildDesktopStatusSurface(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: _DesktopRouteOption(
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
        ),
        _EmptyStateDetail(
          title: 'Live transcript',
          body: 'Commands, edits, and replies stay readable in one place.',
          materialIcon: Icons.subject_rounded,
        ),
        _EmptyStateDetail(
          title: 'Interruptions',
          body: 'Approvals and follow-up forms stay inline.',
          materialIcon: Icons.rule_folder_outlined,
        ),
      ],
      ConnectionMode.remote => const <_EmptyStateDetail>[
        _EmptyStateDetail(
          title: 'Next prompt',
          body: 'Continue the remote workspace from the composer below.',
          materialIcon: Icons.play_circle_outline_rounded,
        ),
        _EmptyStateDetail(
          title: 'Live transcript',
          body: 'Commands, edits, and replies stay readable in one place.',
          materialIcon: Icons.subject_rounded,
        ),
        _EmptyStateDetail(
          title: 'Interruptions',
          body: 'Approvals and follow-up forms stay inline.',
          materialIcon: Icons.rule_folder_outlined,
        ),
      ],
    };
  }
}

class _DesktopRouteOption extends StatelessWidget {
  const _DesktopRouteOption({
    required this.title,
    required this.subtitle,
    required this.isActive,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (background, border, titleColor, bodyColor) = (
      isActive
          ? context.pocketPalette.subtleSurface
          : context.pocketPalette.surface,
      isActive
          ? context.pocketPalette.surfaceBorder.withValues(alpha: 0.9)
          : context.pocketPalette.surfaceBorder,
      Theme.of(context).colorScheme.onSurface,
      Theme.of(context).colorScheme.onSurfaceVariant,
    );

    final indicatorColor = isActive ? titleColor : bodyColor;
    final optionSurface = DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: PocketRadii.circular(PocketRadii.lg),
        border: Border.all(color: border),
      ),
      child: Padding(
        padding: PocketSpacing.panelPadding,
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
            const SizedBox(height: PocketSpacing.xs),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, height: 1.45, color: bodyColor),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return optionSurface;
    }

    return Semantics(
      button: true,
      selected: isActive,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: optionSurface,
        ),
      ),
    );
  }
}
