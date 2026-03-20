import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_overlay_delegate.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_region_policy.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_renderer_delegate.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/empty_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/settings/presentation/connection_settings_contract.dart';

import 'support/fake_codex_app_server_client.dart';

void main() {
  testWidgets('forwards connection settings requests through the callback', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    final requestedSettings = <ChatConnectionSettingsLaunchContract>[];
    final overlayDelegate = _FakeChatRootOverlayDelegate();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      _buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: overlayDelegate,
        onConnectionSettingsRequested: (payload) async {
          requestedSettings.add(payload);
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pumpAndSettle();

    expect(requestedSettings, hasLength(1));
    expect(requestedSettings.single.initialProfile, _configuredProfile());
    expect(
      requestedSettings.single.initialSecrets,
      const ConnectionSecrets(password: 'secret'),
    );
    expect(appServerClient.disconnectCalls, 0);
  });

  testWidgets('routes feedback effects through the overlay delegate', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient()
      ..sendUserMessageError = StateError('transport broke');
    final overlayDelegate = _FakeChatRootOverlayDelegate();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      _buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: overlayDelegate,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('composer_input')),
      'Hello Codex',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(overlayDelegate.transientFeedbackMessages, hasLength(1));
    expect(
      overlayDelegate.transientFeedbackMessages.single,
      contains('Could not send the prompt'),
    );
  });

  testWidgets(
    'sends prompts through the material composer path and clears the draft on success',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      final composerField = find.byKey(const ValueKey('composer_input'));
      await tester.enterText(composerField, 'Hello Codex');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(appServerClient.sentMessages, <String>['Hello Codex']);
      expect(tester.widget<TextField>(composerField).controller?.text, isEmpty);
    },
  );

  testWidgets(
    'retains the draft when sending fails through the material composer path',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..sendUserMessageError = StateError('transport broke');
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      final composerField = find.byKey(const ValueKey('composer_input'));
      await tester.enterText(composerField, 'Hello Codex');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(appServerClient.sentMessages, isEmpty);
      expect(
        tester.widget<TextField>(composerField).controller?.text,
        'Hello Codex',
      );
      expect(overlayDelegate.transientFeedbackMessages, hasLength(1));
    },
  );

  testWidgets('renders the material first-launch empty state on iOS', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient();
    addTearDown(appServerClient.close);

    await tester.pumpWidget(
      _buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: const FlutterChatRootOverlayDelegate(),
        savedProfile: SavedProfile(
          profile: ConnectionProfile.defaults(),
          secrets: const ConnectionSecrets(),
        ),
        platformBehavior: PocketPlatformBehavior.resolve(
          platform: TargetPlatform.iOS,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Configure remote'),
      findsOneWidget,
    );
  });

  testWidgets(
    'desktop empty-state route selection seeds the settings payload',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final appServerClient = FakeCodexAppServerClient();
      final requestedConnectionSettings =
          <ChatConnectionSettingsLaunchContract>[];
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          onConnectionSettingsRequested: (payload) async {
            requestedConnectionSettings.add(payload);
          },
          savedProfile: SavedProfile(
            profile: ConnectionProfile.defaults(),
            secrets: const ConnectionSecrets(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Local'));
      await tester.tap(find.text('Local'));
      await tester.pumpAndSettle();
      final configureButton = find.widgetWithText(
        FilledButton,
        'Configure connection',
      );
      await tester.ensureVisible(configureButton);
      await tester.tap(configureButton);
      await tester.pumpAndSettle();

      expect(requestedConnectionSettings, hasLength(1));
      expect(
        requestedConnectionSettings.single.initialProfile.connectionMode,
        ConnectionMode.local,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'routes changed-file diff openings through the overlay delegate',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/started',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'inProgress',
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'item/completed',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'item': <String, Object?>{
              'id': 'file_change_1',
              'type': 'fileChange',
              'status': 'completed',
              'changes': <Object?>[
                <String, Object?>{
                  'path': 'README.md',
                  'kind': <String, Object?>{'type': 'add'},
                  'diff': 'first line\nsecond line\n',
                },
              ],
            },
          },
        ),
      );
      appServerClient.emit(
        const CodexAppServerNotificationEvent(
          method: 'turn/diff/updated',
          params: <String, Object?>{
            'threadId': 'thread_123',
            'turnId': 'turn_1',
            'diff':
                'diff --git a/README.md b/README.md\n'
                'new file mode 100644\n'
                '--- /dev/null\n'
                '+++ b/README.md\n'
                '@@ -0,0 +1,2 @@\n'
                '+first line\n'
                '+second line\n',
          },
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.text('README.md'));
      await tester.pump();

      expect(overlayDelegate.changedFileDiffs, hasLength(1));
      expect(
        overlayDelegate.changedFileDiffs.single.displayPathLabel,
        'README.md',
      );
    },
  );

  testWidgets(
    'supports an injected renderer path while adapter callbacks still own behavior',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final requestedConnectionSettings =
          <ChatConnectionSettingsLaunchContract>[];
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      final rendererDelegate = _FakeChatRootRendererDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          rendererDelegate: rendererDelegate,
          onConnectionSettingsRequested: (payload) async {
            requestedConnectionSettings.add(payload);
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Injected app chrome'), findsOneWidget);
      expect(find.text('Injected transcript region'), findsOneWidget);
      expect(find.text('Injected composer region'), findsOneWidget);
      expect(find.text('Injected flutter screen shell'), findsOneWidget);
      expect(find.byType(FlutterChatAppChrome), findsNothing);
      expect(find.byType(FlutterChatTranscriptRegion), findsNothing);
      expect(find.byType(FlutterChatComposerRegion), findsNothing);

      await tester.tap(find.byKey(const ValueKey('fake_settings')));
      await tester.pumpAndSettle();

      expect(requestedConnectionSettings, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('fake_diff')));
      await tester.pump();

      expect(overlayDelegate.changedFileDiffs, hasLength(1));
      expect(
        overlayDelegate.changedFileDiffs.single.displayPathLabel,
        'Injected diff',
      );

      await tester.tap(find.byKey(const ValueKey('fake_send')));
      await tester.pumpAndSettle();

      expect(appServerClient.sentMessages, <String>['Injected prompt']);
      expect(
        rendererDelegate.screenShellRenderer,
        ChatRootScreenShellRenderer.flutter,
      );
      expect(
        rendererDelegate.renderersByRegion,
        <ChatRootRegion, ChatRootRegionRenderer>{
          ChatRootRegion.appChrome: ChatRootRegionRenderer.flutter,
          ChatRootRegion.transcript: ChatRootRegionRenderer.flutter,
          ChatRootRegion.composer: ChatRootRegionRenderer.flutter,
        },
      );
    },
  );

  testWidgets(
    'renders through the material shell foundation on every platform',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FlutterChatScreenRenderer), findsOneWidget);
      expect(find.byType(FlutterChatAppChrome), findsOneWidget);
      expect(find.byType(FlutterChatTranscriptRegion), findsOneWidget);
      expect(find.byType(FlutterChatComposerRegion), findsOneWidget);
    },
  );

  testWidgets(
    'applies the platform policy foundation for iOS without an explicit override',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      final rendererDelegate = _FakeChatRootRendererDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          rendererDelegate: rendererDelegate,
          regionPolicy: const ChatRootPlatformPolicy.allFlutter().policyFor(
            TargetPlatform.iOS,
          ),
          platformBehavior: PocketPlatformBehavior.resolve(
            platform: TargetPlatform.iOS,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        rendererDelegate.screenShellRenderer,
        ChatRootScreenShellRenderer.flutter,
      );
      expect(
        rendererDelegate.renderersByRegion,
        <ChatRootRegion, ChatRootRegionRenderer>{
          ChatRootRegion.appChrome: ChatRootRegionRenderer.flutter,
          ChatRootRegion.transcript: ChatRootRegionRenderer.flutter,
          ChatRootRegion.composer: ChatRootRegionRenderer.flutter,
        },
      );
      expect(find.text('Injected flutter screen shell'), findsOneWidget);
    },
  );

  testWidgets(
    'applies the platform policy foundation for macOS without an explicit override',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      final rendererDelegate = _FakeChatRootRendererDelegate();
      addTearDown(appServerClient.close);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          rendererDelegate: rendererDelegate,
          regionPolicy: const ChatRootPlatformPolicy.allFlutter().policyFor(
            TargetPlatform.macOS,
          ),
          platformBehavior: PocketPlatformBehavior.resolve(
            platform: TargetPlatform.macOS,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        rendererDelegate.screenShellRenderer,
        ChatRootScreenShellRenderer.flutter,
      );
      expect(
        rendererDelegate.renderersByRegion,
        <ChatRootRegion, ChatRootRegionRenderer>{
          ChatRootRegion.appChrome: ChatRootRegionRenderer.flutter,
          ChatRootRegion.transcript: ChatRootRegionRenderer.flutter,
          ChatRootRegion.composer: ChatRootRegionRenderer.flutter,
        },
      );
      expect(find.text('Injected flutter screen shell'), findsOneWidget);
    },
  );

  testWidgets('clears adapter-owned draft state when dependencies rebind', (
    tester,
  ) async {
    final firstClient = FakeCodexAppServerClient();
    final secondClient = FakeCodexAppServerClient();
    final overlayDelegate = _FakeChatRootOverlayDelegate();
    addTearDown(firstClient.close);
    addTearDown(secondClient.close);

    await tester.pumpWidget(
      _buildAdapterApp(
        appServerClient: firstClient,
        overlayDelegate: overlayDelegate,
        savedProfile: _savedProfile(),
      ),
    );
    await tester.pumpAndSettle();

    final composerField = find.byKey(const ValueKey('composer_input'));
    await tester.enterText(composerField, 'Stale draft');
    await tester.pump();

    await tester.pumpWidget(
      _buildAdapterApp(
        appServerClient: secondClient,
        overlayDelegate: overlayDelegate,
        savedProfile: _savedProfile(
          profile: _configuredProfile().copyWith(
            label: 'Fresh Box',
            host: 'fresh.example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(composerField).controller?.text, isEmpty);
  });

  testWidgets('ignores stale send completions after the adapter rebinds', (
    tester,
  ) async {
    final firstClient = FakeCodexAppServerClient()
      ..sendUserMessageGate = Completer<void>();
    final secondClient = FakeCodexAppServerClient();
    final overlayDelegate = _FakeChatRootOverlayDelegate();
    addTearDown(firstClient.close);
    addTearDown(secondClient.close);

    await tester.pumpWidget(
      _buildAdapterApp(
        appServerClient: firstClient,
        overlayDelegate: overlayDelegate,
        savedProfile: _savedProfile(),
      ),
    );
    await tester.pumpAndSettle();

    final composerField = find.byKey(const ValueKey('composer_input'));
    await tester.enterText(composerField, 'Old prompt');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump();

    await tester.pumpWidget(
      _buildAdapterApp(
        appServerClient: secondClient,
        overlayDelegate: overlayDelegate,
        savedProfile: _savedProfile(
          profile: _configuredProfile().copyWith(
            label: 'Fresh Box',
            host: 'fresh.example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(composerField, 'New draft');
    await tester.pump();

    firstClient.sendUserMessageGate?.complete();
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(composerField).controller?.text,
      'New draft',
    );
    expect(secondClient.sentMessages, isEmpty);
  });

  testWidgets(
    'keeps lane runtime alive when the adapter unmounts and remounts with the same binding',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient();
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      final laneBinding = _buildLaneBinding(
        appServerClient: appServerClient,
        savedProfile: _savedProfile(),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          laneBinding: laneBinding,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('composer_input')),
        'Persistent draft',
      );
      await tester.pump();

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump();

      expect(appServerClient.disconnectCalls, 0);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          laneBinding: laneBinding,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('composer_input')))
            .controller
            ?.text,
        'Persistent draft',
      );
    },
  );
}

Widget _buildAdapterApp({
  required FakeCodexAppServerClient appServerClient,
  required ChatRootOverlayDelegate overlayDelegate,
  Future<void> Function(ChatConnectionSettingsLaunchContract payload)?
  onConnectionSettingsRequested,
  ChatRootRendererDelegate rendererDelegate =
      const FlutterChatRootRendererDelegate(),
  PocketPlatformPolicy? platformPolicy,
  ChatRootRegionPolicy regionPolicy = const ChatRootRegionPolicy.allFlutter(),
  PocketPlatformBehavior? platformBehavior,
  ConnectionLaneBinding? laneBinding,
  CodexProfileStore? profileStore,
  CodexConversationStateStore? conversationStateStore,
  SavedProfile? savedProfile,
  ThemeData? theme,
}) {
  final resolvedPlatformPolicy =
      platformPolicy ??
      PocketPlatformPolicy(
        behavior: platformBehavior ?? PocketPlatformBehavior.resolve(),
        regionPolicy: regionPolicy,
      );
  return MaterialApp(
    theme: theme ?? buildPocketTheme(Brightness.light),
    home: _ChatRootAdapterHarness(
      laneBinding: laneBinding,
      appServerClient: appServerClient,
      profileStore: profileStore,
      conversationStateStore: conversationStateStore,
      savedProfile: savedProfile ?? _savedProfile(),
      platformPolicy: resolvedPlatformPolicy,
      overlayDelegate: overlayDelegate,
      onConnectionSettingsRequested:
          onConnectionSettingsRequested ?? (_) async {},
      rendererDelegate: rendererDelegate,
    ),
  );
}

ConnectionLaneBinding _buildLaneBinding({
  required FakeCodexAppServerClient appServerClient,
  required SavedProfile savedProfile,
  CodexProfileStore? profileStore,
  CodexConversationStateStore? conversationStateStore,
  PocketPlatformPolicy? platformPolicy,
}) {
  final resolvedPlatformPolicy =
      platformPolicy ??
      PocketPlatformPolicy(
        behavior: PocketPlatformBehavior.resolve(),
        regionPolicy: const ChatRootRegionPolicy.allFlutter(),
      );
  return ConnectionLaneBinding(
    connectionId: 'conn_primary',
    profileStore:
        profileStore ?? MemoryCodexProfileStore(initialValue: savedProfile),
    conversationStateStore:
        conversationStateStore ?? const DiscardingCodexConversationStateStore(),
    appServerClient: appServerClient,
    initialSavedProfile: savedProfile,
    supportsLocalConnectionMode:
        resolvedPlatformPolicy.supportsLocalConnectionMode,
  );
}

ConnectionProfile _configuredProfile() {
  return ConnectionProfile.defaults().copyWith(
    label: 'Dev Box',
    host: 'devbox.local',
    username: 'vince',
    workspaceDir: '/workspace',
  );
}

SavedProfile _savedProfile({
  ConnectionProfile? profile,
  ConnectionSecrets secrets = const ConnectionSecrets(password: 'secret'),
}) {
  return SavedProfile(
    profile: profile ?? _configuredProfile(),
    secrets: secrets,
  );
}

class _FakeChatRootOverlayDelegate implements ChatRootOverlayDelegate {
  _FakeChatRootOverlayDelegate();
  final List<ChatConnectionSettingsLaunchContract> connectionSettingsPayloads =
      <ChatConnectionSettingsLaunchContract>[];
  final List<ChatChangedFileDiffContract> changedFileDiffs =
      <ChatChangedFileDiffContract>[];
  final List<String> transientFeedbackMessages = <String>[];

  @override
  Future<ConnectionSettingsSubmitPayload?> openConnectionSettings({
    required BuildContext context,
    required ChatConnectionSettingsLaunchContract connectionSettings,
    required PocketPlatformBehavior platformBehavior,
  }) async {
    connectionSettingsPayloads.add(connectionSettings);
    return null;
  }

  @override
  Future<void> openChangedFileDiff({
    required BuildContext context,
    required ChatChangedFileDiffContract diff,
  }) async {
    changedFileDiffs.add(diff);
  }

  @override
  void showTransientFeedback({
    required BuildContext context,
    required String message,
  }) {
    transientFeedbackMessages.add(message);
  }
}

class _ChatRootAdapterHarness extends StatefulWidget {
  const _ChatRootAdapterHarness({
    required this.appServerClient,
    required this.savedProfile,
    required this.platformPolicy,
    required this.overlayDelegate,
    required this.onConnectionSettingsRequested,
    required this.rendererDelegate,
    this.laneBinding,
    this.profileStore,
    this.conversationStateStore,
  });

  final FakeCodexAppServerClient appServerClient;
  final SavedProfile savedProfile;
  final PocketPlatformPolicy platformPolicy;
  final ChatRootOverlayDelegate overlayDelegate;
  final Future<void> Function(ChatConnectionSettingsLaunchContract payload)
  onConnectionSettingsRequested;
  final ChatRootRendererDelegate rendererDelegate;
  final ConnectionLaneBinding? laneBinding;
  final CodexProfileStore? profileStore;
  final CodexConversationStateStore? conversationStateStore;

  bool get _usesExternalBinding => laneBinding != null;

  @override
  State<_ChatRootAdapterHarness> createState() =>
      _ChatRootAdapterHarnessState();
}

class _ChatRootAdapterHarnessState extends State<_ChatRootAdapterHarness> {
  ConnectionLaneBinding? _ownedLaneBinding;

  @override
  void initState() {
    super.initState();
    _rebindOwnedLaneBindingIfNeeded(force: true);
  }

  @override
  void didUpdateWidget(covariant _ChatRootAdapterHarness oldWidget) {
    super.didUpdateWidget(oldWidget);
    _rebindOwnedLaneBindingIfNeeded(
      force:
          oldWidget.laneBinding != widget.laneBinding ||
          oldWidget.appServerClient != widget.appServerClient ||
          oldWidget.profileStore != widget.profileStore ||
          oldWidget.conversationStateStore != widget.conversationStateStore ||
          oldWidget.savedProfile != widget.savedProfile ||
          oldWidget.platformPolicy != widget.platformPolicy,
    );
  }

  @override
  void dispose() {
    _ownedLaneBinding?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChatRootAdapter(
      laneBinding: widget.laneBinding ?? _ownedLaneBinding!,
      platformPolicy: widget.platformPolicy,
      onConnectionSettingsRequested: widget.onConnectionSettingsRequested,
      overlayDelegate: widget.overlayDelegate,
      rendererDelegate: widget.rendererDelegate,
    );
  }

  void _rebindOwnedLaneBindingIfNeeded({required bool force}) {
    if (!force) {
      return;
    }

    if (widget._usesExternalBinding) {
      final previousLaneBinding = _ownedLaneBinding;
      _ownedLaneBinding = null;
      previousLaneBinding?.dispose();
      return;
    }

    final nextLaneBinding = _buildLaneBinding(
      appServerClient: widget.appServerClient,
      profileStore: widget.profileStore,
      conversationStateStore: widget.conversationStateStore,
      savedProfile: widget.savedProfile,
      platformPolicy: widget.platformPolicy,
    );
    final previousLaneBinding = _ownedLaneBinding;
    _ownedLaneBinding = nextLaneBinding;
    previousLaneBinding?.dispose();
  }
}

class _FakeChatRootRendererDelegate implements ChatRootRendererDelegate {
  ChatRootScreenShellRenderer? screenShellRenderer;
  final renderersByRegion = <ChatRootRegion, ChatRootRegionRenderer>{};

  @override
  Widget buildScreenShell({
    required ChatRootScreenShellRenderer renderer,
    required ChatScreenContract screen,
    required PreferredSizeWidget appChrome,
    required Widget transcriptRegion,
    required Widget composerRegion,
    required Future<void> Function() onStopActiveTurn,
  }) {
    screenShellRenderer = renderer;
    return Scaffold(
      body: Column(
        children: [
          Text('Injected ${renderer.name} screen shell'),
          SizedBox(
            height: appChrome.preferredSize.height,
            width: double.infinity,
            child: appChrome,
          ),
          Expanded(child: transcriptRegion),
          composerRegion,
        ],
      ),
    );
  }

  @override
  PreferredSizeWidget buildAppChrome({
    required ChatRootRegionRenderer renderer,
    required ChatScreenContract screen,
    required ValueChanged<ChatScreenActionId> onScreenAction,
    List<ChatChromeMenuAction> supplementalMenuActions =
        const <ChatChromeMenuAction>[],
  }) {
    renderersByRegion[ChatRootRegion.appChrome] = renderer;
    return _FakePreferredAppChrome(
      child: Row(
        children: [
          const Expanded(child: Text('Injected app chrome')),
          TextButton(
            key: const ValueKey('fake_settings'),
            onPressed: () => onScreenAction(ChatScreenActionId.openSettings),
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildTranscriptRegion({
    required ChatRootRegionRenderer renderer,
    required PocketPlatformBehavior platformBehavior,
    required ChatScreenContract screen,
    required Object? surfaceChangeToken,
    required ValueChanged<ChatScreenActionId> onScreenAction,
    required ValueChanged<String> onSelectTimeline,
    required ValueChanged<ConnectionMode> onSelectConnectionMode,
    required ValueChanged<bool> onAutoFollowEligibilityChanged,
    void Function(ChatChangedFileDiffContract diff)? onOpenChangedFileDiff,
    Future<void> Function(String requestId)? onApproveRequest,
    Future<void> Function(String requestId)? onDenyRequest,
    Future<void> Function(String requestId, Map<String, List<String>> answers)?
    onSubmitUserInput,
    Future<void> Function(String blockId)? onSaveHostFingerprint,
  }) {
    renderersByRegion[ChatRootRegion.transcript] = renderer;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Injected transcript region'),
          TextButton(
            key: const ValueKey('fake_diff'),
            onPressed: () {
              onOpenChangedFileDiff?.call(
                const ChatChangedFileDiffContract(
                  id: 'diff_1',
                  displayPathLabel: 'Injected diff',
                  stats: ChatChangedFileStatsContract(
                    additions: 1,
                    deletions: 0,
                  ),
                  lines: <ChatChangedFileDiffLineContract>[
                    ChatChangedFileDiffLineContract(
                      text: '+injected line',
                      kind: ChatChangedFileDiffLineKind.addition,
                    ),
                  ],
                ),
              );
            },
            child: const Text('Open diff'),
          ),
        ],
      ),
    );
  }

  @override
  Widget buildComposerRegion({
    required ChatRootRegionRenderer renderer,
    required PocketPlatformBehavior platformBehavior,
    required ChatConversationRecoveryNoticeContract? conversationRecoveryNotice,
    required ChatComposerContract composer,
    required ValueChanged<String> onComposerDraftChanged,
    required Future<void> Function() onSendPrompt,
    required ValueChanged<ChatConversationRecoveryActionId>
    onConversationRecoveryAction,
  }) {
    renderersByRegion[ChatRootRegion.composer] = renderer;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Expanded(child: Text('Injected composer region')),
            TextButton(
              key: const ValueKey('fake_send'),
              onPressed: () async {
                onComposerDraftChanged('Injected prompt');
                await WidgetsBinding.instance.endOfFrame;
                await onSendPrompt();
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FakePreferredAppChrome extends StatelessWidget
    implements PreferredSizeWidget {
  const _FakePreferredAppChrome({required this.child});

  final Widget child;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: child);
  }
}
