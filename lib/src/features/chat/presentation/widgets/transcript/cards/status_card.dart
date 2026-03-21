import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_meta_card.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/conversation_card_palette.dart';

class StatusCard extends StatelessWidget {
  const StatusCard({super.key, required this.block});

  final CodexStatusBlock block;

  @override
  Widget build(BuildContext context) {
    return PocketMetaCard(
      title: block.title,
      body: block.body,
      accent: tealAccent(Theme.of(context).brightness),
      icon: Icons.info_outline,
    );
  }
}
