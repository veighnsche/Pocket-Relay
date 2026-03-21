import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';

class ApprovalDecisionCard extends StatelessWidget {
  const ApprovalDecisionCard({super.key, required this.request});

  final ChatApprovalRequestContract request;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = _accentColor(Theme.of(context).brightness);

    return TranscriptBlocker(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconData, size: 16, color: accent),
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
        ],
      ),
    );
  }

  Color _accentColor(Brightness brightness) {
    return switch (request.resolutionLabel) {
      'approved' => Colors.greenAccent.shade400,
      'denied' => Colors.redAccent.shade200,
      _ => amberAccent(brightness),
    };
  }

  IconData get _iconData {
    return switch (request.resolutionLabel) {
      'approved' => Icons.verified_outlined,
      'denied' => Icons.gpp_bad_outlined,
      _ => Icons.gpp_maybe_outlined,
    };
  }
}
