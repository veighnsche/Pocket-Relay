import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  testWidgets('desktop enter sends the draft', (tester) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: const ChatComposerContract(
          draftText: '',
          isTextInputEnabled: true,
          isPrimaryActionEnabled: true,
          isBusy: false,
          placeholder: 'Message Codex',
          primaryAction: ChatComposerPrimaryAction.send,
        ),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Desktop draft');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 1);
    expect(
      tester.widget<TextField>(fieldFinder).controller?.text,
      'Desktop draft',
    );
  });

  testWidgets('desktop shift+enter inserts a newline', (tester) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: const ChatComposerContract(
          draftText: '',
          isTextInputEnabled: true,
          isPrimaryActionEnabled: true,
          isBusy: false,
          placeholder: 'Message Codex',
          primaryAction: ChatComposerPrimaryAction.send,
        ),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Desktop draft');
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(sendCalls, 0);
    expect(
      tester.widget<TextField>(fieldFinder).controller?.text,
      'Desktop draft\n',
    );
  });

  testWidgets('mobile enter does not send and the draft remains multiline', (
    tester,
  ) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.android,
        contract: const ChatComposerContract(
          draftText: '',
          isTextInputEnabled: true,
          isPrimaryActionEnabled: true,
          isBusy: false,
          placeholder: 'Message Codex',
          primaryAction: ChatComposerPrimaryAction.send,
        ),
        onSend: () async {
          sendCalls += 1;
        },
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Mobile draft');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 0);
    expect(
      tester.widget<TextField>(fieldFinder).textInputAction,
      TextInputAction.newline,
    );

    await tester.enterText(fieldFinder, 'Mobile draft\nSecond line');
    await tester.pump();

    expect(
      tester.widget<TextField>(fieldFinder).controller?.text,
      'Mobile draft\nSecond line',
    );
  });
}

Widget _buildComposerApp({
  required ChatComposerContract contract,
  TargetPlatform platform = TargetPlatform.android,
  ValueChanged<String>? onChanged,
  Future<void> Function()? onSend,
  Future<void> Function()? onStop,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light).copyWith(platform: platform),
    home: Scaffold(
      body: ChatComposer(
        contract: contract,
        onChanged: onChanged ?? (_) {},
        onSend: onSend ?? () async {},
        onStop: onStop ?? () async {},
      ),
    ),
  );
}
