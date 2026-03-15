import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_empty_state.dart';

void main() {
  testWidgets('forwards configure taps through the cupertino CTA', (
    tester,
  ) async {
    var configureCalls = 0;

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: CupertinoEmptyState(
            isConfigured: false,
            onConfigure: () {
              configureCalls += 1;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(CupertinoButton, 'Configure remote'));
    await tester.pump();

    expect(configureCalls, 1);
  });

  testWidgets('hides the configure CTA once the profile is configured', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: CupertinoEmptyState(
            isConfigured: true,
            onConfigure: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Configure remote'), findsNothing);
  });
}

void _noop() {}
