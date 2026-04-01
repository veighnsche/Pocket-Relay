import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';

import '../support/builders/app_test_harness.dart';
import '../support/fakes/connection_settings_overlay_delegate.dart';

void main() {
  registerAppTestStorageLifecycle();

  testWidgets(
    'routes live settings through the material workspace settings renderer on iOS',
    (tester) async {
      final settingsOverlayDelegate = FakeConnectionSettingsOverlayDelegate();
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(
          settingsOverlayDelegate: settingsOverlayDelegate,
          agentAdapterClient: appServerClient,
        ),
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
    final appServerClient = FakeAgentAdapterClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      buildCatalogApp(
        agentAdapterClient: appServerClient,
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
