import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/ui/surfaces/pocket_transcript_frame.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_request_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class UserInputResultCard extends StatelessWidget {
  const UserInputResultCard({
    super.key,
    required this.request,
  });

  final ChatUserInputRequestContract request;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = blueAccent(Theme.of(context).brightness);

    return PocketTranscriptFrame(
      maxWidth: 680,
      shadowColor: cards.shadow,
      boxShadow: const <BoxShadow>[],
      backgroundColor: cards.tintedSurface(
        accent,
        lightAlpha: 0.06,
        darkAlpha: 0.14,
      ),
      borderColor: cards.accentBorder(accent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt_outlined, size: 16, color: accent),
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
              TranscriptBadge(label: 'submitted', color: accent),
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
}
