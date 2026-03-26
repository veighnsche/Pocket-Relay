import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/widgetbook/pocket_relay_widgetbook.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('boots the Pocket Relay widgetbook catalog', (tester) async {
    await tester.pumpWidget(const PocketRelayWidgetbook());
    await tester.pumpAndSettle();

    expect(find.byType(PocketRelayWidgetbook), findsOneWidget);
    expect(find.byType(WidgetbookScope), findsOneWidget);
    expect(find.text('Pocket Relay Widgetbook'), findsOneWidget);
  });

  testWidgets('restores the persisted Widgetbook theme selection', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('widgetbook.selected_theme', 'Pocket Dark');

    await tester.pumpWidget(const PocketRelayWidgetbook());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await tester.pumpAndSettle();

    final scope = tester.widget<WidgetbookScope>(find.byType(WidgetbookScope));
    final state = scope.notifier!;

    expect(state.queryParams['theme'], '{name:Pocket%20Dark}');
  });
}
