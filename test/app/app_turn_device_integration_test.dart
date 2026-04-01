import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';

import '../support/builders/app_test_harness.dart';

void main() {
  registerAppTestStorageLifecycle();

  testWidgets(
    'keeps the display awake only while a turn is actively ticking',
    (tester) async {
      final controller = FakeDisplayWakeLockController();
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(
          displayWakeLockController: controller,
          agentAdapterClient: appServerClient,
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.enabledStates, isEmpty);

      await tester.enterText(
        find.byKey(const ValueKey('composer_input')),
        'Keep the screen awake while this runs',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(controller.enabledStates, <bool>[true]);

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turn': <String, Object?>{'id': 'turn_1', 'status': 'completed'},
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.enabledStates, <bool>[true, false]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'disposes the active lane when the top-level app shell unmounts',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(agentAdapterClient: appServerClient),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(appServerClient.disconnectCalls, 1);
    },
  );
}
