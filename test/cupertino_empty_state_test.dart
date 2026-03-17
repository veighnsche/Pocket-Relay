import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
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
            connectionMode: ConnectionMode.remote,
            onConfigure: () {
              configureCalls += 1;
            },
          ),
        ),
      ),
    );

    final configureButton = find.widgetWithText(
      CupertinoButton,
      'Configure remote',
    );
    await tester.ensureVisible(configureButton);
    await tester.tap(configureButton);
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
            connectionMode: ConnectionMode.remote,
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
          child: CupertinoEmptyState(
            isConfigured: true,
            connectionMode: ConnectionMode.remote,
            onConfigure: _noop,
          ),
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
          .widget<Text>(find.text('Remote Codex, ready to continue'))
          .style
          ?.color,
      CupertinoDynamicColor.resolve(CupertinoColors.label, context),
    );
  });

  testWidgets(
    'macOS empty state advertises local and remote routes',
    (tester) async {
      final selectedModes = <ConnectionMode>[];

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: CupertinoEmptyState(
              isConfigured: false,
              connectionMode: ConnectionMode.remote,
              onConfigure: _noop,
              onSelectConnectionMode: selectedModes.add,
            ),
          ),
        ),
      );

      expect(
        find.text('Choose how this desktop reaches Codex'),
        findsOneWidget,
      );
      expect(find.text('Local'), findsOneWidget);
      expect(find.text('Remote'), findsOneWidget);
      expect(find.text('Desktop Relay'), findsNothing);
      expect(
        find.widgetWithText(CupertinoButton, 'Configure connection'),
        findsOneWidget,
      );

      await tester.tap(find.text('Local'));
      await tester.pump();

      expect(selectedModes, <ConnectionMode>[ConnectionMode.local]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}

void _noop() {}
