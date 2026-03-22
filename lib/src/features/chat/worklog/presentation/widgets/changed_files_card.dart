import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/changed_file_syntax_highlighter.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/conversation_card_palette.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';

part 'changed_files_card_diff_sheet.dart';
part 'changed_files_card_diff_sheet_code_frame.dart';
part 'changed_files_card_diff_sheet_header.dart';
part 'changed_files_card_row.dart';
part 'changed_files_card_support.dart';

class ChangedFilesCard extends StatelessWidget {
  const ChangedFilesCard({super.key, required this.item, this.onOpenDiff});

  final ChatChangedFilesItemContract item;
  final void Function(ChatChangedFileDiffContract diff)? onOpenDiff;

  @override
  Widget build(BuildContext context) {
    final cards = ConversationCardPalette.of(context);
    final accent = amberAccent(cards.brightness);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.drive_file_rename_outline,
        label: item.title,
        accent: accent,
        trailing: item.isRunning ? _LiveUpdateLabel(accent: accent) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _summaryLabel(item),
            style: TextStyle(
              color: cards.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: PocketSpacing.sm),
          if (item.rows.isEmpty)
            Text(
              'Waiting for changed files…',
              style: TextStyle(color: cards.textMuted),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: cards.surface,
                borderRadius: PocketRadii.circular(PocketRadii.lg),
                border: Border.all(
                  color: cards.neutralBorder.withValues(alpha: 0.86),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cards.shadow.withValues(
                      alpha: cards.isDark ? 0.16 : 0.06,
                    ),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: item.rows.indexed
                    .map(
                      (entry) => _ChangedFileRow(
                        row: entry.$2,
                        cards: cards,
                        isLast: entry.$1 == item.rows.length - 1,
                        onOpenDiff: onOpenDiff,
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}
