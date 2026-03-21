import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/chat_composer.dart';

void main() {
  testWidgets('resyncs displayed text from the composer contract', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildComposerApp(
        contract: _composerContract(draftText: 'Initial draft'),
      ),
    );

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Initial draft',
    );

    await tester.pumpWidget(_buildComposerApp(contract: _composerContract()));

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
        contract: _composerContract(),
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
        contract: _composerContract(),
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
        contract: _composerContract(),
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
        contract: _composerContract(),
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

  testWidgets('keeps desktop focus and the send affordance stable while busy', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: _composerContract(draftText: 'Desktop draft'),
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isTrue);
    expect(find.byKey(const ValueKey('send')), findsOneWidget);

    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.macOS,
        contract: _composerContract(
          draftText: 'Desktop draft',
          isSendActionEnabled: false,
        ),
      ),
    );
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isTrue);
    expect(find.byKey(const ValueKey('send')), findsOneWidget);
    expect(find.byKey(const ValueKey('stop')), findsNothing);
  });

  testWidgets('uses a compact chat-style input shell', (tester) async {
    await tester.pumpWidget(_buildComposerApp(contract: _composerContract()));

    final field = tester.widget<TextField>(find.byType(TextField));
    final sendSize = tester.getSize(find.byKey(const ValueKey('send')));

    expect(field.decoration?.isCollapsed, isTrue);
    expect(
      field.decoration?.contentPadding,
      const EdgeInsets.symmetric(vertical: 4),
    );
    expect(sendSize, const Size(36, 36));
  });

  testWidgets('tapping outside the composer input dismisses focus', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildComposerApp(
        contract: _composerContract(),
        includeOutsideTapTarget: true,
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isTrue);

    await tester.tapAt(const Offset(24, 24));
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isFalse);
  });

  testWidgets('send dismisses composer focus on mobile', (tester) async {
    await tester.pumpWidget(
      _buildComposerApp(
        platform: TargetPlatform.android,
        contract: _composerContract(),
      ),
    );

    final fieldFinder = find.byType(TextField);

    await tester.tap(fieldFinder);
    await tester.pump();
    await tester.enterText(fieldFinder, 'Mobile draft');
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isTrue);

    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump();

    expect(_editableTextFocusNode(tester).hasFocus, isFalse);
  });
}

Widget _buildComposerApp({
  required ChatComposerContract contract,
  TargetPlatform platform = TargetPlatform.android,
  ValueChanged<String>? onChanged,
  Future<void> Function()? onSend,
  bool includeOutsideTapTarget = false,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light).copyWith(platform: platform),
    home: Scaffold(
      body: Column(
        children: [
          if (includeOutsideTapTarget)
            const Expanded(
              child: SizedBox(
                key: ValueKey('outside_tap_target'),
                width: double.infinity,
              ),
            ),
          ChatComposer(
            platformBehavior: PocketPlatformBehavior.resolve(
              platform: platform,
            ),
            contract: contract,
            onChanged: onChanged ?? (_) {},
            onSend: onSend ?? () async {},
          ),
        ],
      ),
    ),
  );
}

ChatComposerContract _composerContract({
  String draftText = '',
  bool isSendActionEnabled = true,
}) {
  return ChatComposerContract(
    draftText: draftText,
    isSendActionEnabled: isSendActionEnabled,
    placeholder: 'Message Codex',
  );
}

FocusNode _editableTextFocusNode(WidgetTester tester) {
  return tester.widget<EditableText>(find.byType(EditableText)).focusNode;
}
