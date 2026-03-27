import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/theme/pocket_typography.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_work_log_terminal_contract.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/work_log_terminal_sheet.dart';

void main() {
  testWidgets('uses the app-owned monospace family for terminal text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: const Scaffold(
          body: WorkLogTerminalSheet(
            terminal: ChatWorkLogTerminalContract(
              id: 'terminal_1',
              activityLabel: 'Ran command',
              commandText: 'pwd',
              isRunning: false,
              isWaiting: false,
              terminalOutput: '/workspace\n',
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.style?.fontFamily, PocketFontFamilies.monospace);
  });
}
