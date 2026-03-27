import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_typography.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_panel_surface.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_transcript_frame.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';

class SshSurfaceFrame extends StatelessWidget {
  const SshSurfaceFrame({
    super.key,
    required this.title,
    required this.description,
    required this.host,
    required this.port,
    required this.accent,
    required this.icon,
    this.contextLabel,
    this.trailing,
    this.panels = const <Widget>[],
    this.actions = const <Widget>[],
  });

  final String title;
  final String description;
  final String host;
  final int port;
  final Color accent;
  final IconData icon;
  final String? contextLabel;
  final Widget? trailing;
  final List<Widget> panels;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);
    final metadata = contextLabel == null
        ? '$host:$port'
        : '$host:$port  •  $contextLabel';

    return PocketTranscriptFrame(
      shadowColor: cards.shadow,
      shadowOpacity: cards.isDark ? 0.18 : 0.06,
      backgroundColor: cards.tintedSurface(
        accent,
        lightAlpha: 0.08,
        darkAlpha: 0.14,
      ),
      borderColor: cards.accentBorder(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 18, color: accent),
              ),
              const SizedBox(width: PocketSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing case final Widget trailingWidget) trailingWidget,
            ],
          ),
          const SizedBox(height: PocketSpacing.xs),
          Text(
            description,
            style: TextStyle(
              color: cards.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: PocketSpacing.sm),
          PocketPanelSurface(
            backgroundColor: cards.codeSurface,
            borderColor: cards.neutralBorder,
            padding: const EdgeInsets.symmetric(
              horizontal: PocketSpacing.md,
              vertical: PocketSpacing.sm,
            ),
            radius: PocketRadii.sm,
            child: Text(
              metadata,
              style: TextStyle(
                color: cards.textMuted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final panel in panels) ...[
            const SizedBox(height: PocketSpacing.sm),
            panel,
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: PocketSpacing.md),
            Wrap(
              spacing: PocketSpacing.sm,
              runSpacing: PocketSpacing.sm,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}

class SshDetailPanel extends StatelessWidget {
  const SshDetailPanel({
    super.key,
    required this.label,
    required this.value,
    this.valueKey,
  });

  final String label;
  final String value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);

    return PocketPanelSurface(
      backgroundColor: cards.codeSurface,
      borderColor: cards.neutralBorder,
      padding: const EdgeInsets.symmetric(
        horizontal: PocketSpacing.md,
        vertical: 11,
      ),
      radius: PocketRadii.sm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: cards.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            value,
            key: valueKey,
            style: PocketTypography.monospaceStyle(
              base: const TextStyle(),
              color: cards.codeText,
              fontSize: 13.2,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
