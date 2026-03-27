import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_typography.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';

const double _terminalSheetHeightFactor = 0.93;
const double _terminalSheetDesktopBreakpoint = 1040;
const double _terminalSheetMaxWidth = 980;
const double _terminalSheetCornerRadius = 32;
const double _terminalSheetShadowBlur = 28;
const double _terminalSheetShadowOffsetY = -12;
const double _terminalSheetHandleSpacing = 10;
const double _terminalSheetHeaderIconSize = 20;
const double _terminalSheetHeaderGap = 10;
const double _terminalSheetTitleFontSize = 18;
const double _terminalSheetActivityFontSize = 12.5;
const double _terminalSheetActivityLetterSpacing = 0.15;
const double _terminalSheetActivityTopSpacing = 6;
const double _terminalSheetBadgeTopSpacing = 10;
const double _terminalSheetBadgeSpacing = 8;
const double _terminalSheetCodeFontSize = 12.5;
const double _terminalSheetCodeLineHeight = 1.45;
const EdgeInsets _terminalSheetHeaderPadding = EdgeInsets.fromLTRB(
  22,
  18,
  14,
  14,
);
const EdgeInsets _terminalSheetBodyPadding = EdgeInsets.fromLTRB(18, 0, 18, 18);
const EdgeInsets _terminalSheetInsetPadding = EdgeInsets.fromLTRB(
  16,
  14,
  16,
  14,
);
const String _terminalCloseTooltip = 'Close';
const String _terminalCommandPrefix = r'$ ';
const String _terminalInputPrefix = '> ';
const String _waitingForOutputMessage = 'Waiting for terminal output...';
const String _emptyOutputMessage = 'No terminal output captured.';

class WorkLogTerminalSheet extends StatelessWidget {
  const WorkLogTerminalSheet({super.key, required this.terminal});

  final ChatWorkLogTerminalContract terminal;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);
    final pocket = context.pocketPalette;
    final accent = _accentForTerminal(cards);

    return FractionallySizedBox(
      heightFactor: _terminalSheetHeightFactor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth =
              constraints.maxWidth >= _terminalSheetDesktopBreakpoint
              ? _terminalSheetMaxWidth
              : double.infinity;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: pocket.sheetBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_terminalSheetCornerRadius),
                  ),
                  border: Border.all(color: cards.neutralBorder),
                  boxShadow: [
                    BoxShadow(
                      color: cards.shadow.withValues(
                        alpha: cards.isDark ? 0.34 : 0.14,
                      ),
                      blurRadius: _terminalSheetShadowBlur,
                      offset: const Offset(0, _terminalSheetShadowOffsetY),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: _terminalSheetHandleSpacing),
                    const ModalSheetDragHandle(),
                    Padding(
                      padding: _terminalSheetHeaderPadding,
                      child: _TerminalSheetHeader(
                        terminal: terminal,
                        cards: cards,
                        accent: accent,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: _terminalSheetBodyPadding,
                        child: TranscriptCodeInset(
                          padding: _terminalSheetInsetPadding,
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.zero,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.zero,
                                child: SelectableText(
                                  _terminalTranscriptText(terminal),
                                  style: PocketTypography.monospace(
                                    context,
                                    color: cards.textPrimary,
                                    fontSize: _terminalSheetCodeFontSize,
                                    height: _terminalSheetCodeLineHeight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _accentForTerminal(TranscriptPalette cards) {
    if (terminal.isWaiting) {
      return tealAccent(cards.brightness);
    }
    if (terminal.isFailed) {
      return redAccent(cards.brightness);
    }
    return blueAccent(cards.brightness);
  }
}

class _TerminalSheetHeader extends StatelessWidget {
  const _TerminalSheetHeader({
    required this.terminal,
    required this.cards,
    required this.accent,
    required this.onClose,
  });

  final ChatWorkLogTerminalContract terminal;
  final TranscriptPalette cards;
  final Color accent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.terminal_rounded,
              size: _terminalSheetHeaderIconSize,
              color: accent,
            ),
            const SizedBox(width: _terminalSheetHeaderGap),
            Expanded(
              child: Text(
                'Terminal',
                style: TextStyle(
                  color: cards.textPrimary,
                  fontSize: _terminalSheetTitleFontSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: _terminalCloseTooltip,
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: _terminalSheetActivityTopSpacing),
        Text(
          terminal.activityLabel,
          style: TextStyle(
            color: accent,
            fontSize: _terminalSheetActivityFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: _terminalSheetActivityLetterSpacing,
          ),
        ),
        const SizedBox(height: _terminalSheetBadgeTopSpacing),
        Wrap(
          spacing: _terminalSheetBadgeSpacing,
          runSpacing: _terminalSheetBadgeSpacing,
          children: [
            TranscriptBadge(label: terminal.statusBadgeLabel, color: accent),
            if (terminal.processId case final processId?)
              TranscriptBadge(label: processId, color: cards.textMuted),
          ],
        ),
      ],
    );
  }
}

String _terminalTranscriptText(ChatWorkLogTerminalContract terminal) {
  final buffer = StringBuffer();
  _writePrefixedBlock(
    buffer,
    prefix: _terminalCommandPrefix,
    value: terminal.commandText,
  );
  if (terminal.terminalInput case final input?) {
    _writePrefixedBlock(buffer, prefix: _terminalInputPrefix, value: input);
  }
  if (terminal.terminalOutput case final output?) {
    _writeBodyBlock(buffer, output);
  } else if (!terminal.hasTerminalInput) {
    buffer
      ..writeln()
      ..write(
        terminal.isWaiting ? _waitingForOutputMessage : _emptyOutputMessage,
      );
  }

  return buffer.toString();
}

void _writePrefixedBlock(
  StringBuffer buffer, {
  required String prefix,
  required String value,
}) {
  if (buffer.isNotEmpty) {
    buffer.writeln();
    buffer.writeln();
  }

  final lines = value.split('\n');
  for (var index = 0; index < lines.length; index += 1) {
    final line = lines[index];
    final isLastLine = index == lines.length - 1;
    if (isLastLine && line.isEmpty) {
      continue;
    }
    buffer
      ..write(prefix)
      ..write(line);
    if (!isLastLine) {
      buffer.writeln();
    }
  }
}

void _writeBodyBlock(StringBuffer buffer, String value) {
  if (buffer.isNotEmpty) {
    buffer.writeln();
    buffer.writeln();
  }

  buffer.write(value);
}
