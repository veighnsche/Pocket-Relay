import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';

void main() {
  testWidgets('resyncs displayed text from the composer contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildComposerApp(
        contract: const ChatComposerContract(
          draftText: 'Initial draft',
          isTextInputEnabled: true,
          isPrimaryActionEnabled: true,
          isBusy: false,
          placeholder: 'Message Codex',
          primaryAction: ChatComposerPrimaryAction.send,
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Initial draft',
    );

    await tester.pumpWidget(
      _buildComposerApp(
        contract: const ChatComposerContract(
          draftText: '',
          isTextInputEnabled: true,
          isPrimaryActionEnabled: true,
          isBusy: false,
          placeholder: 'Message Codex',
          primaryAction: ChatComposerPrimaryAction.send,
        ),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
  });

  testWidgets('forwards text changes without owning draft state', (
    tester,
  ) async {
    String? latestValue;

    await tester.pumpWidget(
      _buildComposerApp(
        contract: const ChatComposerContract(
          draftText: '',
          isTextInputEnabled: true,
          isPrimaryActionEnabled: true,
          isBusy: false,
          placeholder: 'Message Codex',
          primaryAction: ChatComposerPrimaryAction.send,
        ),
        onChanged: (value) {
          latestValue = value;
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'Composer draft');

    expect(latestValue, 'Composer draft');
  });
}

Widget _buildComposerApp({
  required ChatComposerContract contract,
  ValueChanged<String>? onChanged,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: ChatComposer(
        contract: contract,
        onChanged: onChanged ?? (_) {},
        onSend: () async {},
        onStop: () async {},
      ),
    ),
  );
}
