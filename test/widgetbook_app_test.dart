import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/widgetbook/pocket_relay_widgetbook.dart';

void main() {
  testWidgets('boots the Pocket Relay widgetbook catalog', (tester) async {
    await tester.pumpWidget(const PocketRelayWidgetbook());
    await tester.pumpAndSettle();

    expect(find.byType(PocketRelayWidgetbook), findsOneWidget);
    expect(find.text('Pocket Relay Widgetbook'), findsOneWidget);
    expect(find.text('Welcome to Widgetbook'), findsNothing);
  });
}
