import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_policy.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_adapter.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_root_overlay_delegate.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/connection_lane_binding.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
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
    'long-pressing a saved user message opens a context menu and can continue from that prompt after rollback',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
        conversationStateStore: const DiscardingCodexConversationStateStore(),
        appServerClient: appServerClient,
        initialSavedProfile: _savedProfile(),
        initialConversationState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_saved',
        ),
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

      expect(find.text('Restore this'), findsOneWidget);

      appServerClient.threadHistoriesById['thread_saved'] =
          _rewoundConversationThread(threadId: 'thread_saved');

      await tester.longPress(find.text('Restore this'));
      await tester.pumpAndSettle();

      expect(find.text('Copy Prompt'), findsOneWidget);
      expect(find.text('Continue From Here'), findsOneWidget);
      await tester.tap(find.text('Continue From Here'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.textContaining('discard newer conversation turns'),
        findsOneWidget,
      );
      expect(
        find.textContaining('reload the selected prompt into the composer'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Local file changes are not reverted automatically',
        ),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(
        appServerClient.rollbackThreadCalls,
        <({String threadId, int numTurns})>[
          (threadId: 'thread_saved', numTurns: 2),
        ],
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('composer_input')))
            .controller
            ?.text,
        'Restore this',
      );
      expect(find.text('Restore this'), findsOneWidget);
      expect(find.text('Earlier answer only'), findsOneWidget);
    },
  );

  testWidgets(
    'long-press rollback failure keeps the transcript intact and shows feedback',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        )
        ..rollbackThreadError = StateError('transport broke');
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
        conversationStateStore: const DiscardingCodexConversationStateStore(),
        appServerClient: appServerClient,
        initialSavedProfile: _savedProfile(),
        initialConversationState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_saved',
        ),
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

      await tester.longPress(find.text('Restore this'));
      await tester.pumpAndSettle();

      expect(find.text('Copy Prompt'), findsOneWidget);
      expect(find.text('Continue From Here'), findsOneWidget);
      await tester.tap(find.text('Continue From Here'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(
        appServerClient.rollbackThreadCalls,
        <({String threadId, int numTurns})>[
          (threadId: 'thread_saved', numTurns: 2),
        ],
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('composer_input')))
            .controller
            ?.text,
        isEmpty,
      );
      expect(find.text('Restore this'), findsOneWidget);
      expect(find.text('Second prompt'), findsOneWidget);
      expect(find.text('Restored answer'), findsOneWidget);
      expect(find.text('Second answer'), findsOneWidget);
      expect(overlayDelegate.transientFeedbackMessages, hasLength(1));
      expect(
        overlayDelegate.transientFeedbackMessages.single,
        'Could not rewind this conversation to the selected prompt.',
      );
    },
  );

  testWidgets(
    'busy conversations do not surface continue from here in the long-press menu',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
        conversationStateStore: const DiscardingCodexConversationStateStore(),
        appServerClient: appServerClient,
        initialSavedProfile: _savedProfile(),
        initialConversationState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_saved',
        ),
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

      expect(
        await laneBinding.sessionController.sendPrompt('Keep running'),
        isTrue,
      );
      await tester.pumpAndSettle();

      expect(find.text('Keep running'), findsOneWidget);

      await tester.longPress(find.text('Restore this'));
      await tester.pumpAndSettle();

      expect(find.text('Copy Prompt'), findsOneWidget);
      expect(
        tester
            .widget<ListTile>(
              find.widgetWithText(ListTile, 'Continue From Here'),
            )
            .enabled,
        isFalse,
      );
    },
  );

  testWidgets(
    'secondary-clicking a saved desktop user message exposes continue from here',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        );
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
        conversationStateStore: const DiscardingCodexConversationStateStore(),
        appServerClient: appServerClient,
        initialSavedProfile: _savedProfile(),
        initialConversationState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_saved',
        ),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);

      await tester.pumpWidget(
        _buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          laneBinding: laneBinding,
          platformBehavior: PocketPlatformBehavior.resolve(
            platform: TargetPlatform.macOS,
          ),
        ),
      );
      await tester.pumpAndSettle();

      appServerClient.threadHistoriesById['thread_saved'] =
          _rewoundConversationThread(threadId: 'thread_saved');

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      addTearDown(gesture.removePointer);
      await gesture.down(tester.getCenter(find.text('Restore this')));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('Copy Prompt'), findsOneWidget);
      expect(find.text('Continue From Here'), findsOneWidget);
      await tester.tap(find.text('Continue From Here').last);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(
        appServerClient.rollbackThreadCalls,
        <({String threadId, int numTurns})>[
          (threadId: 'thread_saved', numTurns: 2),
        ],
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('composer_input')))
            .controller
            ?.text,
        'Restore this',
      );
      expect(find.text('Earlier answer only'), findsOneWidget);
    },
  );

  testWidgets(
    'menu actions start a fresh thread and clear the transcript through the bound lane',
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

      final composerField = find.byKey(const ValueKey('composer_input'));
      await tester.enterText(composerField, 'Hello Codex');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(find.text('Hello Codex'), findsOneWidget);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New thread'));
      await tester.pumpAndSettle();

      expect(find.text('Hello Codex'), findsNothing);
      expect(
        find.text('The next prompt will start a fresh Codex thread.'),
        findsOneWidget,
      );
      expect(
        laneBinding.transcriptFollowHost.contract.request?.source,
        ChatTranscriptFollowRequestSource.newThread,
      );

      await tester.enterText(composerField, 'Second transcript');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      expect(find.text('Second transcript'), findsOneWidget);

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear transcript'));
      await tester.pumpAndSettle();

      expect(find.text('Second transcript'), findsNothing);
      expect(
        laneBinding.transcriptFollowHost.contract.request?.source,
        ChatTranscriptFollowRequestSource.clearTranscript,
      );
      expect(laneBinding.sessionController.transcriptBlocks, isEmpty);
    },
  );

  testWidgets(
    'menu actions can branch the active conversation through the lane',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = _savedConversationThread(
          threadId: 'thread_saved',
        )
        ..forkThreadId = 'thread_forked'
        ..threadHistoriesById['thread_forked'] = _savedConversationThread(
          threadId: 'thread_forked',
        );
      final overlayDelegate = _FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: _savedProfile()),
        conversationStateStore: const DiscardingCodexConversationStateStore(),
        appServerClient: appServerClient,
        initialSavedProfile: _savedProfile(),
        initialConversationState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_saved',
        ),
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

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Branch conversation'));
      await tester.pumpAndSettle();

      expect(appServerClient.forkThreadRequests.single, (
        threadId: 'thread_saved',
        path: null,
        cwd: null,
        model: null,
        modelProvider: null,
        ephemeral: null,
        persistExtendedHistory: true,
      ));
      expect(
        laneBinding.sessionController.sessionState.rootThreadId,
        'thread_forked',
      );
      expect(find.text('Restore this'), findsOneWidget);
      expect(find.text('Second prompt'), findsOneWidget);
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
  PocketPlatformPolicy? platformPolicy,
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
      PocketPlatformPolicy(behavior: PocketPlatformBehavior.resolve());
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

CodexAppServerThreadHistory _savedConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_saved',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_saved',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restore this'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Restored answer'},
              ],
            },
          ],
        },
      ),
      CodexAppServerHistoryTurn(
        id: 'turn_second',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_user_second',
            type: 'user_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_user_second',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second prompt'},
              ],
            },
          ),
          CodexAppServerHistoryItem(
            id: 'item_assistant_second',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant_second',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second answer'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_second',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_user_second',
              'type': 'user_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second prompt'},
              ],
            },
            <String, Object?>{
              'id': 'item_assistant_second',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Second answer'},
              ],
            },
          ],
        },
      ),
    ],
  );
}

CodexAppServerThreadHistory _rewoundConversationThread({
  required String threadId,
}) {
  return CodexAppServerThreadHistory(
    id: threadId,
    name: 'Saved conversation',
    sourceKind: 'app-server',
    turns: const <CodexAppServerHistoryTurn>[
      CodexAppServerHistoryTurn(
        id: 'turn_before_restore_this',
        status: 'completed',
        items: <CodexAppServerHistoryItem>[
          CodexAppServerHistoryItem(
            id: 'item_assistant_earlier',
            type: 'agent_message',
            status: 'completed',
            raw: <String, dynamic>{
              'id': 'item_assistant_earlier',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Earlier answer only'},
              ],
            },
          ),
        ],
        raw: <String, dynamic>{
          'id': 'turn_before_restore_this',
          'status': 'completed',
          'items': <Object>[
            <String, Object?>{
              'id': 'item_assistant_earlier',
              'type': 'agent_message',
              'status': 'completed',
              'content': <Object>[
                <String, Object?>{'text': 'Earlier answer only'},
              ],
            },
          ],
        },
      ),
    ],
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
