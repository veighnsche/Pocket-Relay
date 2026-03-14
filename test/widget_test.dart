import 'package:flutter/material.dart';
import 'package:pocket_relay/src/app.dart';
import 'package:pocket_relay/src/core/models/app_preferences.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
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
  });

  testWidgets('persists dark mode from the settings sheet', (tester) async {
    final profileStore = MemoryCodexProfileStore(
      initialValue: SavedProfile(
        profile: ConnectionProfile.defaults().copyWith(
          host: 'example.com',
          username: 'vince',
        ),
        secrets: const ConnectionSecrets(password: 'secret'),
        preferences: const AppPreferences(),
      ),
    );

    await tester.pumpWidget(
      PocketRelayApp(
        profileStore: profileStore,
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark mode'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final savedProfile = await profileStore.load();

    expect(app.themeMode, ThemeMode.dark);
    expect(savedProfile.preferences.isDarkMode, isTrue);
  });
}
