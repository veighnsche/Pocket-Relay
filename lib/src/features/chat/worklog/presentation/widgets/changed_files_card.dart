import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_radii.dart';
import 'package:pocket_relay/src/core/ui/layout/pocket_spacing.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
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
    final accent = amberAccent(Theme.of(context).brightness);

    return TranscriptAnnotation(
      accent: accent,
      header: TranscriptAnnotationHeader(
        icon: Icons.drive_file_rename_outline,
        label: item.title,
        accent: accent,
        trailing: item.isRunning
            ? const InlinePulseChip(label: 'updating')
            : null,
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
          const SizedBox(height: PocketSpacing.xs),
          if (item.rows.isEmpty)
            Text(
              'Waiting for changed files…',
              style: TextStyle(color: cards.textMuted),
            )
          else
            Column(
              children: item.rows.indexed
                  .map(
                    (entry) => Padding(
                      padding: EdgeInsets.only(
                        bottom: entry.$1 == item.rows.length - 1 ? 0 : 6,
                      ),
                      child: _ChangedFileRow(
                        row: entry.$2,
                        cards: cards,
                        onOpenDiff: onOpenDiff,
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
        ],
      ),
    );
  }
}
