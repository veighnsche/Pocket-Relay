import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';

import '../support/builders/app_test_harness.dart';
import '../support/fakes/connection_settings_overlay_delegate.dart';

void main() {
  registerAppTestStorageLifecycle();

  testWidgets(
    'routes live settings through the material workspace settings renderer on iOS',
    (tester) async {
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate();

      await tester.pumpWidget(
        buildCatalogApp(settingsOverlayDelegate: settingsOverlayDelegate),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();

      expect(settingsOverlayDelegate.launchedSettings, hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('settings sheet no longer shows a dark mode toggle', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCatalogApp(
        savedProfile: SavedProfile(
          profile: ConnectionProfile.defaults().copyWith(
            host: 'example.com',
            username: 'vince',
          ),
          secrets: const ConnectionSecrets(password: 'secret'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Dark mode'), findsNothing);
  });
}
