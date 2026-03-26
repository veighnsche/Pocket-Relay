import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_surface_frame.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';

class SshUnpinnedHostKeySurface extends StatelessWidget {
  const SshUnpinnedHostKeySurface({
    super.key,
    required this.block,
    this.onSaveFingerprint,
    this.onOpenConnectionSettings,
  });

  final CodexSshUnpinnedHostKeyBlock block;
  final Future<void> Function(String blockId)? onSaveFingerprint;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    final canSave = !block.isSaved && onSaveFingerprint != null;
    final accent = amberAccent(Theme.of(context).brightness);
    final hostIdentityLabel = '${block.host}:${block.port}';

    return SshSurfaceFrame(
      key: const ValueKey('ssh_unpinned_host_key_surface'),
      title: 'Host key not pinned',
      description: block.isSaved
          ? 'This fingerprint is pinned for $hostIdentityLabel and will be reused by every saved connection that points there.'
          : 'This SSH host key was accepted because Pocket Relay does not have a pinned fingerprint for $hostIdentityLabel yet. Save it once if you trust this host, and sibling connections to the same host and port will reuse it.',
      host: block.host,
      port: block.port,
      contextLabel: block.keyType,
      accent: accent,
      icon: Icons.verified_user_outlined,
      trailing: block.isSaved
          ? TranscriptBadge(label: 'saved', color: accent)
          : null,
      panels: <Widget>[
        SshDetailPanel(
          label: 'Fingerprint',
          value: block.fingerprint,
          valueKey: const ValueKey('host_fingerprint_value'),
        ),
      ],
      actions: <Widget>[
        OutlinedButton(
          key: const ValueKey('open_connection_settings'),
          onPressed: onOpenConnectionSettings,
          child: const Text('Connection settings'),
        ),
        if (!block.isSaved)
          FilledButton(
            key: const ValueKey('save_host_fingerprint'),
            onPressed: canSave ? () => onSaveFingerprint!(block.id) : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB45309),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save fingerprint'),
          ),
      ],
    );
  }
}
