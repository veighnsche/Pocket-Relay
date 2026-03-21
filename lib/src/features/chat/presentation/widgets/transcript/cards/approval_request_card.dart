import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_transcript_frame.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class ApprovalRequestCard extends StatelessWidget {
  const ApprovalRequestCard({
    super.key,
    required this.request,
    this.onApprove,
    this.onDeny,
  });

  final ChatApprovalRequestContract request;
  final Future<void> Function(String requestId)? onApprove;
  final Future<void> Function(String requestId)? onDeny;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = amberAccent(Theme.of(context).brightness);
    final canRespond =
        !request.isResolved && onApprove != null && onDeny != null;

    return PocketTranscriptFrame(
      maxWidth: 680,
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
            children: [
              Icon(Icons.gpp_maybe_outlined, size: 16, color: accent),
              const SizedBox(width: PocketSpacing.xs),
              Expanded(
                child: Text(
                  request.title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (request.isResolved)
                TranscriptBadge(
                  label: request.resolutionLabel ?? 'resolved',
                  color: accent,
                ),
            ],
          ),
          if (request.body.trim().isNotEmpty) ...[
            const SizedBox(height: PocketSpacing.xs),
            SelectableText(
              request.body,
              style: TextStyle(
                color: cards.textSecondary,
                fontSize: 13,
                height: 1.32,
              ),
            ),
          ],
          const SizedBox(height: PocketSpacing.sm),
          Row(
            children: [
              OutlinedButton(
                onPressed: canRespond ? () => onDeny!(request.requestId) : null,
                child: const Text('Deny'),
              ),
              const SizedBox(width: PocketSpacing.sm),
              FilledButton(
                onPressed: canRespond
                    ? () => onApprove!(request.requestId)
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
