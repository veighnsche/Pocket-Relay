import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_mobile_shell.dart';

import '../support/builders/app_test_harness.dart';

void main() {
  registerAppTestStorageLifecycle();

  testWidgets('shows the Pocket Relay shell', (tester) async {
    await tester.pumpWidget(
      buildCatalogApp(
        savedProfile: SavedProfile(
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Developer Box'), findsOneWidget);
    expect(find.text('Configure remote'), findsWidgets);
    expect(find.byType(ConnectionWorkspaceMobileShell), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace_page_view')), findsOneWidget);
    expect(find.byType(ChatRootAdapter), findsOneWidget);
    expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
    expect(find.byType(FlutterChatAppChrome), findsOneWidget);
    expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
    expect(find.byType(FlutterChatComposerRegion), findsOneWidget);
  });

  testWidgets('boots the first saved connection from the catalog', (
    tester,
  ) async {
    final repository = MemoryCodexConnectionRepository(
      initialConnections: <SavedConnection>[
        buildSavedConnection(),
        SavedConnection(
          id: 'conn_secondary',
          profile: testSavedProfile().profile.copyWith(
            label: 'Second Box',
            host: 'second.local',
          ),
          secrets: const ConnectionSecrets(password: 'second-secret'),
        ),
      ],
    );

    await tester.pumpWidget(buildCatalogApp(connectionRepository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Dev Box'), findsOneWidget);
    expect(find.text('devbox.local'), findsOneWidget);
    expect(find.text('Second Box'), findsNothing);
    expect(find.text('second.local'), findsNothing);
  });

  testWidgets('boots an empty workspace into the dormant roster shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildCatalogApp(connectionRepository: MemoryCodexConnectionRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ConnectionWorkspaceMobileShell), findsOneWidget);
    expect(find.byKey(const ValueKey('workspace_page_view')), findsOneWidget);
    expect(find.byType(ChatRootAdapter), findsNothing);
    expect(find.text('No saved connections yet.'), findsOneWidget);
    expect(find.byKey(const ValueKey('add_connection')), findsOneWidget);
  });
}
