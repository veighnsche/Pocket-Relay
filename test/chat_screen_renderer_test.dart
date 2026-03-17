import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/cupertino_chat_screen_renderer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/flutter_chat_screen_renderer.dart';

void main() {
  testWidgets('renders the explicit shell regions', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: FlutterChatScreenRenderer(
          screen: _screenContract(),
          appChrome: const _TestAppChrome(),
          transcriptRegion: const Center(child: Text('Transcript region')),
          composerRegion: const Text('Composer region'),
        ),
      ),
    );

    expect(find.text('Injected chrome'), findsOneWidget);
    expect(find.text('Transcript region'), findsOneWidget);
    expect(find.text('Composer region'), findsOneWidget);
  });

  testWidgets(
    'cupertino renderer installs obstructing chrome as the native navigation bar',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: CupertinoChatScreenRenderer(
            screen: _screenContract(),
            appChrome: const _TestCupertinoAppChrome(),
            transcriptRegion: const Center(child: Text('Transcript region')),
            composerRegion: const Text('Composer region'),
          ),
        ),
      );

      final scaffold = tester.widget<CupertinoPageScaffold>(
        find.byType(CupertinoPageScaffold),
      );

      expect(scaffold.navigationBar, isA<_TestCupertinoAppChrome>());
      expect(find.text('Injected cupertino chrome'), findsOneWidget);
      expect(find.text('Transcript region'), findsOneWidget);
      expect(find.text('Composer region'), findsOneWidget);
    },
  );

  testWidgets('forwards toolbar and menu actions through app chrome', (
    tester,
  ) async {
    final actions = <ChatScreenActionId>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          appBar: FlutterChatAppChrome(
            screen: _screenContract(),
            onScreenAction: actions.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Connection settings'));
    await tester.pump();

    await tester.tap(find.byType(PopupMenuButton<ChatScreenActionId>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New thread'));
    await tester.pumpAndSettle();

    expect(actions, <ChatScreenActionId>[
      ChatScreenActionId.openSettings,
      ChatScreenActionId.newThread,
    ]);
  });

  testWidgets(
    'forwards empty-state actions through transcript region',
    (tester) async {
      final actions = <ChatScreenActionId>[];
      final selectedModes = <ConnectionMode>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: Scaffold(
            body: FlutterChatTranscriptRegion(
              screen: _screenContract(
                isConfigured: false,
                emptyState: const ChatEmptyStateContract(
                  isConfigured: false,
                  connectionMode: ConnectionMode.remote,
                ),
              ),
              onScreenAction: actions.add,
              onSelectTimeline: (_) {},
              onSelectConnectionMode: selectedModes.add,
              onAutoFollowEligibilityChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Local'));
      await tester.pump();

      final configureButton = find.widgetWithText(
        FilledButton,
        'Configure connection',
      );
      await tester.ensureVisible(configureButton);
      await tester.tap(configureButton);
      await tester.pump();

      expect(selectedModes, <ConnectionMode>[ConnectionMode.local]);
      expect(actions, <ChatScreenActionId>[ChatScreenActionId.openSettings]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('renders timeline chips and forwards selection', (tester) async {
    final selectedTimelines = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          body: FlutterChatTranscriptRegion(
            screen: _screenContract(
              timelineSummaries: const <ChatTimelineSummaryContract>[
                ChatTimelineSummaryContract(
                  threadId: 'thread_root',
                  label: 'Main',
                  status: CodexAgentLifecycleState.running,
                  isPrimary: true,
                  isSelected: true,
                  isClosed: false,
                  hasUnreadActivity: false,
                  hasPendingRequests: false,
                ),
                ChatTimelineSummaryContract(
                  threadId: 'thread_child',
                  label: 'Reviewer',
                  status: CodexAgentLifecycleState.blockedOnApproval,
                  isPrimary: false,
                  isSelected: false,
                  isClosed: false,
                  hasUnreadActivity: true,
                  hasPendingRequests: true,
                ),
              ],
            ),
            onScreenAction: (_) {},
            onSelectTimeline: selectedTimelines.add,
            onSelectConnectionMode: (_) {},
            onAutoFollowEligibilityChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('timeline_thread_root')), findsOneWidget);
    expect(find.byKey(const ValueKey('timeline_thread_child')), findsOneWidget);
    expect(find.text('Reviewer'), findsOneWidget);
    expect(find.text('Waiting on approval'), findsOneWidget);
    expect(find.text('Needs action'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('timeline_thread_child')));
    await tester.pump();

    expect(selectedTimelines, <String>['thread_child']);
  });

  testWidgets('forwards composer interactions through composer region', (
    tester,
  ) async {
    final draftValues = <String>[];
    var sendCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          body: FlutterChatComposerRegion(
            conversationRecoveryNotice: null,
            composer: _screenContract().composer,
            onComposerDraftChanged: draftValues.add,
            onSendPrompt: () async {
              sendCalls += 1;
            },
            onStopActiveTurn: () async {},
            onConversationRecoveryAction: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Plan phase 6');
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(draftValues, <String>['Plan phase 6']);
    expect(sendCalls, 1);
  });
}

ChatScreenContract _screenContract({
  bool isConfigured = true,
  ChatEmptyStateContract? emptyState,
  List<ChatTimelineSummaryContract> timelineSummaries =
      const <ChatTimelineSummaryContract>[],
}) {
  return ChatScreenContract(
    isLoading: false,
    header: const ChatHeaderContract(
      title: 'Pocket Relay',
      subtitle: 'Dev Box · devbox.local',
    ),
    actions: const <ChatScreenActionContract>[
      ChatScreenActionContract(
        id: ChatScreenActionId.openSettings,
        label: 'Connection settings',
        placement: ChatScreenActionPlacement.toolbar,
        tooltip: 'Connection settings',
        icon: ChatScreenActionIcon.settings,
      ),
      ChatScreenActionContract(
        id: ChatScreenActionId.newThread,
        label: 'New thread',
        placement: ChatScreenActionPlacement.menu,
      ),
    ],
    timelineSummaries: timelineSummaries,
    transcriptSurface: ChatTranscriptSurfaceContract(
      isConfigured: isConfigured,
      mainItems: const <ChatTranscriptItemContract>[],
      pinnedItems: const <ChatTranscriptItemContract>[],
      pendingRequestPlacement: ChatPendingRequestPlacementContract(
        visibleApprovalRequest: null,
        visibleUserInputRequest: null,
      ),
      activePendingUserInputRequestIds: const <String>{},
      emptyState: emptyState,
    ),
    transcriptFollow: const ChatTranscriptFollowContract(
      isAutoFollowEnabled: true,
      resumeDistance: 80,
    ),
    composer: const ChatComposerContract(
      draftText: '',
      isTextInputEnabled: true,
      isPrimaryActionEnabled: true,
      isBusy: false,
      placeholder: 'Message Codex',
      primaryAction: ChatComposerPrimaryAction.send,
    ),
    connectionSettings: ChatConnectionSettingsLaunchContract(
      initialProfile: ConnectionProfile.defaults(),
      initialSecrets: const ConnectionSecrets(),
    ),
  );
}

class _TestAppChrome extends StatelessWidget implements PreferredSizeWidget {
  const _TestAppChrome();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Injected chrome'));
  }
}

class _TestCupertinoAppChrome extends StatelessWidget
    implements ObstructingPreferredSizeWidget {
  const _TestCupertinoAppChrome();

  @override
  Size get preferredSize => const Size.fromHeight(44);

  @override
  bool shouldFullyObstruct(BuildContext context) => true;

  @override
  Widget build(BuildContext context) {
    return const CupertinoNavigationBar(
      middle: Text('Injected cupertino chrome'),
    );
  }
}
