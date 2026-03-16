import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/app.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_app_chrome.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_composer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_transient_feedback.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';
import 'package:pocket_relay/src/features/settings/presentation/cupertino_connection_sheet.dart';

import 'support/fake_codex_app_server_client.dart';

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
    expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
    expect(find.byType(FlutterChatAppChrome), findsOneWidget);
    expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
    expect(find.byType(FlutterChatComposerRegion), findsOneWidget);
  });

  testWidgets(
    'uses the cupertino foundation path by default on iOS while transcript stays on the flutter region path',
    (tester) async {
      await tester.pumpWidget(
        PocketRelayApp(
          profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ChatRootAdapter), findsOneWidget);
      expect(find.byType(CupertinoChatScreenRenderer), findsOneWidget);
      expect(find.byType(CupertinoChatAppChrome), findsOneWidget);
      expect(find.byType(CupertinoChatComposerRegion), findsOneWidget);
      expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
      expect(find.byType(FlutterChatScreenRenderer), findsNothing);
      expect(find.byType(FlutterChatAppChrome), findsNothing);
      expect(find.byType(FlutterChatComposerRegion), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'uses the cupertino foundation path by default on macOS while transcript stays on the flutter region path',
    (tester) async {
      await tester.pumpWidget(
        PocketRelayApp(
          profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ChatRootAdapter), findsOneWidget);
      expect(find.byType(CupertinoChatScreenRenderer), findsOneWidget);
      expect(find.byType(CupertinoChatAppChrome), findsOneWidget);
      expect(find.byType(CupertinoChatComposerRegion), findsOneWidget);
      expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
      expect(find.byType(FlutterChatScreenRenderer), findsNothing);
      expect(find.byType(FlutterChatAppChrome), findsNothing);
      expect(find.byType(FlutterChatComposerRegion), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'shows a cupertino bootstrap shell while the profile is loading on iOS',
    (tester) async {
      final profileStore = _DeferredProfileStore();

      await tester.pumpWidget(PocketRelayApp(profileStore: profileStore));
      await tester.pump();

      expect(find.byType(CupertinoPageScaffold), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Scaffold), findsNothing);

      profileStore.complete(_savedProfile());
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoChatScreenRenderer), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

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

  testWidgets(
    'saves connection settings through the cupertino sheet by default on iOS',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        PocketRelayApp(
          profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
          appServerClient: appServerClient,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Connection settings'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoConnectionSheet), findsOneWidget);

      await tester.enterText(
        _settingsField(ConnectionSettingsFieldId.label),
        'iPhone Box',
      );
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoConnectionSheet), findsNothing);
      expect(find.text('iPhone Box · devbox.local'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'sends prompts through the cupertino composer by default on iOS',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        PocketRelayApp(
          profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
          appServerClient: appServerClient,
        ),
      );
      await tester.pumpAndSettle();

      final composerField = find.byType(CupertinoTextField).first;
      await tester.enterText(composerField, 'Hello Codex');
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(appServerClient.sentMessages, <String>['Hello Codex']);
      expect(
        tester.widget<CupertinoTextField>(composerField).controller?.text,
        isEmpty,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'shows cupertino feedback and retains the draft when sending fails by default on iOS',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..sendUserMessageError = StateError('transport broke');
      addTearDown(appServerClient.close);
      addTearDown(CupertinoTransientFeedbackPresenter.dismissActiveEntry);

      await tester.pumpWidget(
        PocketRelayApp(
          profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
          appServerClient: appServerClient,
        ),
      );
      await tester.pumpAndSettle();

      final composerField = find.byType(CupertinoTextField).first;
      await tester.enterText(composerField, 'Hello Codex');
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pump();

      expect(find.byType(CupertinoTransientFeedbackBanner), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.widget<CupertinoTextField>(composerField).controller?.text,
        'Hello Codex',
      );

      CupertinoTransientFeedbackPresenter.dismissActiveEntry();
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'presents top-level menu actions through the shared popup menu by default on iOS',
    (tester) async {
      await tester.pumpWidget(
        PocketRelayApp(
          profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoActionSheet), findsNothing);
      expect(find.text('New thread'), findsOneWidget);
      expect(find.text('Clear transcript'), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

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

Finder _settingsField(ConnectionSettingsFieldId fieldId) {
  return find.byKey(ValueKey<String>('connection_settings_${fieldId.name}'));
}

SavedProfile _savedProfile() {
  return SavedProfile(
    profile: ConnectionProfile.defaults().copyWith(
      label: 'Dev Box',
      host: 'devbox.local',
      username: 'vince',
    ),
    secrets: const ConnectionSecrets(password: 'secret'),
  );
}

class _DeferredProfileStore implements CodexProfileStore {
  final _completer = Completer<SavedProfile>();
  SavedProfile _savedProfile = SavedProfile(
    profile: ConnectionProfile.defaults(),
    secrets: const ConnectionSecrets(),
  );

  void complete(SavedProfile savedProfile) {
    _savedProfile = savedProfile;
    _completer.complete(savedProfile);
  }

  @override
  Future<SavedProfile> load() => _completer.future;

  @override
  Future<void> save(
    ConnectionProfile profile,
    ConnectionSecrets secrets,
  ) async {
    _savedProfile = _savedProfile.copyWith(profile: profile, secrets: secrets);
  }
}
