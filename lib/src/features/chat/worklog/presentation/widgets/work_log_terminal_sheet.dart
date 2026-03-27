import 'package:flutter/material.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/ui/primitives/pocket_badge.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_item_primitives.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/transcript_palette.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';

class WorkLogTerminalSheet extends StatelessWidget {
  const WorkLogTerminalSheet({super.key, required this.terminal});

  final ChatWorkLogTerminalContract terminal;

  @override
  Widget build(BuildContext context) {
    final cards = TranscriptPalette.of(context);
    final pocket = context.pocketPalette;
    final accent = _accentForTerminal(cards);

    return FractionallySizedBox(
      heightFactor: 0.93,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth >= 1040
              ? 980.0
              : double.infinity;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: pocket.sheetBackground,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  border: Border.all(color: cards.neutralBorder),
                  boxShadow: [
                    BoxShadow(
                      color: cards.shadow.withValues(
                        alpha: cards.isDark ? 0.34 : 0.14,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, -12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    const ModalSheetDragHandle(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 14, 14),
                      child: _TerminalSheetHeader(
                        terminal: terminal,
                        cards: cards,
                        accent: accent,
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: TranscriptCodeInset(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.zero,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.zero,
                                child: SelectableText(
                                  _terminalTranscriptText(terminal),
                                  style: TextStyle(
                                    color: cards.textPrimary,
                                    fontSize: 12.5,
                                    height: 1.45,
                                    fontFamily: 'monospace',
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
      return cards.brightness == Brightness.dark
          ? const Color(0xFF88D4C8)
          : const Color(0xFF0F8C7B);
    }
    final code = terminal.exitCode;
    if (code != null && code != 0) {
      return cards.brightness == Brightness.dark
          ? const Color(0xFFF28B82)
          : const Color(0xFFC62828);
    }
    return cards.brightness == Brightness.dark
        ? const Color(0xFF8AB4F8)
        : const Color(0xFF1A73E8);
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
            Icon(Icons.terminal_rounded, size: 20, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Terminal',
                style: TextStyle(
                  color: cards.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          terminal.activityLabel,
          style: TextStyle(
            color: accent,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.15,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
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
  _writePrefixedBlock(buffer, prefix: r'$ ', value: terminal.commandText);
  if (terminal.terminalInput case final input?) {
    _writePrefixedBlock(buffer, prefix: '> ', value: input);
  }
  if (terminal.terminalOutput case final output?) {
    _writeBodyBlock(buffer, output);
  } else if (!terminal.hasTerminalInput) {
    buffer
      ..writeln()
      ..write(
        terminal.isWaiting
            ? 'Waiting for terminal output...'
            : 'No terminal output captured.',
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
