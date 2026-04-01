import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/chat/transport/agent_adapter/testing/fake_agent_adapter_client.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_desktop_shell.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_mobile_shell.dart';

import '../support/builders/app_test_harness.dart';

void main() {
  registerAppTestStorageLifecycle();

  testWidgets(
    'uses the material renderer path by default on iOS',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(agentAdapterClient: appServerClient),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionWorkspaceMobileShell), findsOneWidget);
      expect(find.byType(ChatRootAdapter), findsOneWidget);
      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
      expect(find.byType(FlutterChatAppChrome), findsOneWidget);
      expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
      expect(find.byType(FlutterChatComposerRegion), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'uses the material renderer path by default on macOS',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        buildCatalogApp(agentAdapterClient: appServerClient),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionWorkspaceDesktopShell), findsOneWidget);
      expect(find.byType(ChatRootAdapter), findsOneWidget);
      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
      expect(find.byType(FlutterChatAppChrome), findsOneWidget);
      expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
      expect(find.byType(FlutterChatComposerRegion), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('uses system theme mode', (tester) async {
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

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.themeMode, ThemeMode.system);
  });
}
