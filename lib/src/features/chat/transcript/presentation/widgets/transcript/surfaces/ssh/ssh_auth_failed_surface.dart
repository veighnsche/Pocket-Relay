import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/transcript_ui_block.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/ssh/ssh_surface_frame.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';

class SshAuthFailedSurface extends StatelessWidget {
  const SshAuthFailedSurface({
    super.key,
    required this.block,
    this.onOpenConnectionSettings,
  });

  final TranscriptSshAuthenticationFailedBlock block;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    final authLabel = switch (block.authMode) {
      AuthMode.password => 'password',
      AuthMode.privateKey => 'private key',
    };

    return SshSurfaceFrame(
      key: const ValueKey('ssh_auth_failed_surface'),
      title: 'SSH authentication failed',
      description:
          'SSH could not authenticate as ${block.username}. Check the saved $authLabel configuration in connection settings.',
      host: block.host,
      port: block.port,
      contextLabel: '${block.username}  •  $authLabel',
      accent: redAccent(Theme.of(context).brightness),
      icon: Icons.lock_outline,
      panels: <Widget>[SshDetailPanel(label: 'Details', value: block.message)],
      actions: <Widget>[
        OutlinedButton(
          key: const ValueKey('open_connection_settings'),
          onPressed: onOpenConnectionSettings,
          child: const Text('Connection settings'),
        ),
      ],
    );
  }
}
