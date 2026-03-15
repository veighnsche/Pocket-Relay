import 'package:flutter/material.dart';
import 'package:pocket_relay/src/app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Pocket Relay shell', (tester) async {
    await tester.pumpWidget(
      PocketRelayApp(
        profileStore: MemoryCodexProfileStore(
          initialValue: SavedProfile(
            profile: ConnectionProfile.defaults(),
            secrets: const ConnectionSecrets(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Pocket Relay'), findsOneWidget);
    expect(find.text('Configure remote'), findsWidgets);
    expect(find.byType(ChatRootAdapter), findsOneWidget);
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
  });

  testWidgets('uses system theme mode', (tester) async {
    final profileStore = MemoryCodexProfileStore(
      initialValue: SavedProfile(
        profile: ConnectionProfile.defaults().copyWith(
          host: 'example.com',
          username: 'vince',
        ),
        secrets: const ConnectionSecrets(password: 'secret'),
      ),
    );

    await tester.pumpWidget(PocketRelayApp(profileStore: profileStore));

    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.themeMode, ThemeMode.system);
  });

  testWidgets('settings sheet no longer shows a dark mode toggle', (
    tester,
  ) async {
    final profileStore = MemoryCodexProfileStore(
      initialValue: SavedProfile(
        profile: ConnectionProfile.defaults().copyWith(
          host: 'example.com',
          username: 'vince',
        ),
        secrets: const ConnectionSecrets(password: 'secret'),
      ),
    );

    await tester.pumpWidget(PocketRelayApp(profileStore: profileStore));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pumpAndSettle();

    expect(find.text('Appearance'), findsNothing);
    expect(find.text('Dark mode'), findsNothing);
  });
}
