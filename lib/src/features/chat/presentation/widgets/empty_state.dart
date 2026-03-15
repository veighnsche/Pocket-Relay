import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';

enum ChatEmptyStateRenderer { flutter, cupertino }

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.isConfigured,
    required this.onConfigure,
  });

  final bool isConfigured;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.pocketPalette;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: palette.surfaceBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
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
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Remote Codex, cleaned up for a phone screen',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isConfigured
                            ? 'Send a prompt below. The app will SSH into your box, keep `codex app-server` running, and turn the live stream into phone-sized cards.'
                            : 'Start by configuring an SSH target. After that, the app keeps a remote Codex session open and makes the interaction readable on mobile.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _ChecklistPill('SSH into the dev box'),
                          _ChecklistPill('Keep Codex app-server live'),
                          _ChecklistPill('Handle approvals and user input'),
                          _ChecklistPill('Show commands and answers as cards'),
                        ],
                      ),
                      if (!isConfigured) ...[
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: onConfigure,
                          icon: const Icon(Icons.settings),
                          label: const Text('Configure remote'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChecklistPill extends StatelessWidget {
  const _ChecklistPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
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
}
