import 'package:flutter/material.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/transcript_chips.dart';

class HostFingerprintCard extends StatelessWidget {
  const HostFingerprintCard({
    super.key,
    required this.block,
    this.onSaveFingerprint,
    this.onOpenConnectionSettings,
  });

  final CodexUnpinnedHostKeyBlock block;
  final Future<void> Function(String blockId)? onSaveFingerprint;
  final VoidCallback? onOpenConnectionSettings;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = amberAccent(Theme.of(context).brightness);
    final canSave = !block.isSaved && onSaveFingerprint != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: cards.tintedSurface(accent, lightAlpha: 0.08, darkAlpha: 0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cards.accentBorder(accent)),
          boxShadow: [
            BoxShadow(
              color: cards.shadow.withValues(alpha: cards.isDark ? 0.18 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_user_outlined, size: 17, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Host key not pinned',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (block.isSaved)
                  TranscriptBadge(label: 'saved', color: accent),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              block.isSaved
                  ? 'This fingerprint has been pinned to the saved connection profile.'
                  : 'This SSH host key was accepted because the current profile has no pinned fingerprint yet. Save it if you trust this host.',
              style: TextStyle(
                color: cards.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: cards.codeSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cards.neutralBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${block.host}:${block.port}  •  ${block.keyType}',
                    style: TextStyle(
                      color: cards.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    block.fingerprint,
                    key: const ValueKey('host_fingerprint_value'),
                    style: TextStyle(
                      color: cards.codeText,
                      fontFamily: 'monospace',
                      fontSize: 13.2,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  key: const ValueKey('open_connection_settings'),
                  onPressed: onOpenConnectionSettings,
                  child: const Text('Connection settings'),
                ),
                if (!block.isSaved)
                  FilledButton(
                    key: const ValueKey('save_host_fingerprint'),
                    onPressed: canSave
                        ? () => onSaveFingerprint!(block.id)
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB45309),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save fingerprint'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
