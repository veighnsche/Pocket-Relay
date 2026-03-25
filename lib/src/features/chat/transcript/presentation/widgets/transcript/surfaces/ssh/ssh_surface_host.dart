import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_auth_failed_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_connect_failed_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_host_key_mismatch_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_unpinned_host_key_surface.dart';

class SshSurfaceHost extends StatelessWidget {
  const SshSurfaceHost({
    super.key,
    required this.block,
    this.onSaveFingerprint,
    this.onOpenConnectionSettings,
  });

  final CodexSshTranscriptBlock block;
  final Future<void> Function(String blockId)? onSaveFingerprint;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      final CodexSshUnpinnedHostKeyBlock unpinnedBlock =>
        SshUnpinnedHostKeySurface(
          block: unpinnedBlock,
          onSaveFingerprint: onSaveFingerprint,
          onOpenConnectionSettings: onOpenConnectionSettings,
        ),
      final CodexSshConnectFailedBlock connectFailedBlock =>
        SshConnectFailedSurface(
          block: connectFailedBlock,
          onOpenConnectionSettings: onOpenConnectionSettings,
        ),
      final CodexSshHostKeyMismatchBlock mismatchBlock =>
        SshHostKeyMismatchSurface(
          block: mismatchBlock,
          onOpenConnectionSettings: onOpenConnectionSettings,
        ),
      final CodexSshAuthenticationFailedBlock authFailedBlock =>
        SshAuthFailedSurface(
          block: authFailedBlock,
          onOpenConnectionSettings: onOpenConnectionSettings,
        ),
    };
  }
}
