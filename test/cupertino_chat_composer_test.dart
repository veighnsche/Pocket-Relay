import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_composer.dart';

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
          placeholder: 'Describe what you want Codex to do…',
          primaryAction: ChatComposerPrimaryAction.send,
        ),
      ),
    );

    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller
          ?.text,
      'Initial draft',
    );

    await tester.pumpWidget(
      _buildComposerApp(
        contract: const ChatComposerContract(
          draftText: '',
          isTextInputEnabled: true,
          isPrimaryActionEnabled: true,
          isBusy: false,
          placeholder: 'Describe what you want Codex to do…',
          primaryAction: ChatComposerPrimaryAction.send,
        ),
      ),
    );

    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller
          ?.text,
      '',
    );
  });

  testWidgets('forwards text changes and send presses', (tester) async {
    String? latestValue;
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        contract: const ChatComposerContract(
          draftText: '',
          isTextInputEnabled: true,
          isPrimaryActionEnabled: true,
          isBusy: false,
          placeholder: 'Describe what you want Codex to do…',
          primaryAction: ChatComposerPrimaryAction.send,
        ),
        onChanged: (value) {
          latestValue = value;
        },
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    await tester.enterText(find.byType(CupertinoTextField), 'Cupertino draft');
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(latestValue, 'Cupertino draft');
    expect(sendCalls, 1);
  });

  testWidgets('switches to stop action and forwards stop presses', (
    tester,
  ) async {
    var stopCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        contract: const ChatComposerContract(
          draftText: '',
          isTextInputEnabled: false,
          isPrimaryActionEnabled: true,
          isBusy: true,
          placeholder: 'Describe what you want Codex to do…',
          primaryAction: ChatComposerPrimaryAction.stop,
        ),
        onStop: () async {
          stopCalls += 1;
        },
      ),
    );

    expect(find.byKey(const ValueKey('stop')), findsOneWidget);
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .enabled,
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('stop')));
    await tester.pumpAndSettle();

    expect(stopCalls, 1);
  });
}

Widget _buildComposerApp({
  required ChatComposerContract contract,
  ValueChanged<String>? onChanged,
  Future<void> Function()? onSend,
  Future<void> Function()? onStop,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: CupertinoChatComposer(
        contract: contract,
        onChanged: onChanged ?? (_) {},
        onSend: onSend ?? () async {},
        onStop: onStop ?? () async {},
      ),
    ),
  );
}
