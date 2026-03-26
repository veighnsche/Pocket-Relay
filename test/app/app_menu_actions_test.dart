import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/builders/app_test_harness.dart';

void main() {
  registerAppTestStorageLifecycle();

  testWidgets(
    'presents top-level menu actions through the shared popup menu by default on iOS',
    (tester) async {
      await tester.pumpWidget(buildCatalogApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.text('New thread'), findsOneWidget);
      expect(find.text('Clear transcript'), findsOneWidget);
      expect(find.text('Saved connections'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
