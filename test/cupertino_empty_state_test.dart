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

  testWidgets('uses adaptive grouped surfaces in dark mode', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        theme: CupertinoThemeData(brightness: Brightness.dark),
        home: CupertinoPageScaffold(
          child: CupertinoEmptyState(isConfigured: true, onConfigure: _noop),
        ),
      ),
    );

    final card = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('cupertino_empty_state_card')),
    );
    final context = tester.element(
      find.byKey(const ValueKey('cupertino_empty_state_card')),
    );
    final decoration = card.decoration as ShapeDecoration;
    final shape = decoration.shape as RoundedSuperellipseBorder;

    expect(
      decoration.color,
      CupertinoDynamicColor.resolve(
        CupertinoColors.secondarySystemGroupedBackground,
        context,
      ).withValues(alpha: 0.92),
    );
    expect(shape.borderRadius, const BorderRadius.all(Radius.circular(28)));
    expect(
      tester
          .widget<Text>(
            find.text('Remote Codex, cleaned up for a phone screen'),
          )
          .style
          ?.color,
      CupertinoDynamicColor.resolve(CupertinoColors.label, context),
    );
  });
}

void _noop() {}
