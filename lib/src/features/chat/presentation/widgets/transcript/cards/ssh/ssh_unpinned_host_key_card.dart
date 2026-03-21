import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/ssh/ssh_card_frame.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class SshUnpinnedHostKeyCard extends StatelessWidget {
  const SshUnpinnedHostKeyCard({
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

    return SshCardFrame(
      key: const ValueKey('ssh_unpinned_host_key_card'),
      title: 'Host key not pinned',
      description: block.isSaved
          ? 'This fingerprint has been pinned to the saved connection profile.'
          : 'This SSH host key was accepted because the current profile has no pinned fingerprint yet. Save it if you trust this host.',
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
