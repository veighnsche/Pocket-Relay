import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          placeholder: 'Message Codex',
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
          placeholder: 'Message Codex',
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
          placeholder: 'Message Codex',
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

    final fieldFinder = find.byType(CupertinoTextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Desktop draft');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 1);
    expect(
      tester.widget<CupertinoTextField>(fieldFinder).controller?.text,
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

    final fieldFinder = find.byType(CupertinoTextField);

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
      tester.widget<CupertinoTextField>(fieldFinder).controller?.text,
      'Desktop draft\n',
    );
  });

  testWidgets('mobile enter does not send and the draft remains multiline', (
    tester,
  ) async {
    var sendCalls = 0;

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.iOS,
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

    final fieldFinder = find.byType(CupertinoTextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Mobile draft');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(sendCalls, 0);
    expect(
      tester.widget<CupertinoTextField>(fieldFinder).textInputAction,
      TextInputAction.newline,
    );

    await tester.enterText(fieldFinder, 'Mobile draft\nSecond line');
    await tester.pump();

    expect(
      tester.widget<CupertinoTextField>(fieldFinder).controller?.text,
      'Mobile draft\nSecond line',
    );
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
          placeholder: 'Message Codex',
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

  testWidgets('uses adaptive cupertino text colors in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildComposerApp(
        brightness: Brightness.dark,
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

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    final surfaceContext = tester.element(
      find.byKey(const ValueKey('cupertino_composer_surface')),
    );
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('cupertino_composer_surface')),
    );
    final decoration = surface.decoration as BoxDecoration;

    expect(
      field.style?.color,
      CupertinoDynamicColor.resolve(CupertinoColors.label, surfaceContext),
    );
    expect(
      field.placeholderStyle?.color,
      CupertinoDynamicColor.resolve(
        CupertinoColors.placeholderText,
        surfaceContext,
      ),
    );
    expect(
      decoration.color,
      CupertinoDynamicColor.resolve(
        CupertinoColors.secondarySystemGroupedBackground,
        surfaceContext,
      ).withValues(alpha: 0.82),
    );
  });

  testWidgets('uses a compact centered layout in cupertino mode', (
    tester,
  ) async {
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

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    final contentRow = tester.widget<Row>(
      find.byKey(const ValueKey('chat_composer_content_row')),
    );

    expect(field.padding, const EdgeInsets.fromLTRB(2, 6, 8, 6));
    expect(contentRow.crossAxisAlignment, CrossAxisAlignment.center);
  });
}

Widget _buildComposerApp({
  required ChatComposerContract contract,
  Brightness brightness = Brightness.light,
  TargetPlatform platform = TargetPlatform.iOS,
  ValueChanged<String>? onChanged,
  Future<void> Function()? onSend,
  Future<void> Function()? onStop,
}) {
  return MaterialApp(
    theme: buildPocketTheme(brightness).copyWith(platform: platform),
    darkTheme: buildPocketTheme(Brightness.dark).copyWith(platform: platform),
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
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
