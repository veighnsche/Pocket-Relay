import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_chrome_menu_action.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/widgets/flutter_chat_screen_renderer.dart';

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
          onStopActiveTurn: () async {},
        ),
      ),
    );

    expect(find.text('Injected chrome'), findsOneWidget);
    expect(find.text('Transcript region'), findsOneWidget);
    expect(find.text('Composer region'), findsOneWidget);
  });

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

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New thread'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Branch conversation'));
    await tester.pumpAndSettle();

    expect(actions, <ChatScreenActionId>[
      ChatScreenActionId.openSettings,
      ChatScreenActionId.newThread,
      ChatScreenActionId.branchConversation,
    ]);
  });

  testWidgets('app chrome supports supplemental workspace menu actions', (
    tester,
  ) async {
    final laneActions = <ChatScreenActionId>[];
    var openedDormantConnections = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          appBar: FlutterChatAppChrome(
            screen: _screenContract(),
            onScreenAction: laneActions.add,
            supplementalMenuActions: <ChatChromeMenuAction>[
              ChatChromeMenuAction(
                label: 'Saved connections',
                onSelected: () {
                  openedDormantConnections = true;
                },
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PopupMenuButton<int>));
    await tester.pumpAndSettle();

    expect(find.text('New thread'), findsOneWidget);
    expect(find.text('Branch conversation'), findsOneWidget);
    expect(find.text('Saved connections'), findsOneWidget);

    await tester.tap(find.text('Saved connections'));
    await tester.pumpAndSettle();

    expect(openedDormantConnections, isTrue);
    expect(laneActions, isEmpty);
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
              platformBehavior: PocketPlatformBehavior.resolve(
                platform: TargetPlatform.macOS,
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
            platformBehavior: PocketPlatformBehavior.resolve(),
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
            platformBehavior: PocketPlatformBehavior.resolve(),
            conversationRecoveryNotice: null,
            historicalConversationRestoreNotice: null,
            composer: _screenContract().composer,
            onComposerDraftChanged: draftValues.add,
            onSendPrompt: () async {
              sendCalls += 1;
            },
            onConversationRecoveryAction: (_) {},
            onHistoricalConversationRestoreAction: (_) {},
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Plan phase 6');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pumpAndSettle();

    expect(draftValues, <String>['Plan phase 6']);
    expect(sendCalls, 1);
  });

  testWidgets('renders historical restore actions through composer region', (
    tester,
  ) async {
    final actions = <ChatHistoricalConversationRestoreActionId>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          body: FlutterChatComposerRegion(
            platformBehavior: PocketPlatformBehavior.resolve(),
            conversationRecoveryNotice: null,
            historicalConversationRestoreNotice:
                const ChatHistoricalConversationRestoreNoticeContract(
                  title: 'Transcript history unavailable',
                  message: 'Codex did not return enough transcript content.',
                  isLoading: false,
                  actions: <ChatHistoricalConversationRestoreActionContract>[
                    ChatHistoricalConversationRestoreActionContract(
                      id: ChatHistoricalConversationRestoreActionId
                          .retryRestore,
                      label: 'Retry load',
                      isPrimary: true,
                    ),
                  ],
                ),
            composer: _screenContract().composer,
            onComposerDraftChanged: (_) {},
            onSendPrompt: () async {},
            onConversationRecoveryAction: (_) {},
            onHistoricalConversationRestoreAction: actions.add,
          ),
        ),
      ),
    );

    expect(find.text('Transcript history unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry load'));
    await tester.pump();

    expect(actions, <ChatHistoricalConversationRestoreActionId>[
      ChatHistoricalConversationRestoreActionId.retryRestore,
    ]);
  });

  testWidgets('renders stop beside the elapsed badge and forwards the action', (
    tester,
  ) async {
    var stopCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: FlutterChatScreenRenderer(
          screen: _screenContract(
            turnIndicator: ChatTurnIndicatorContract(
              timer: CodexSessionTurnTimer(
                turnId: 'turn_1',
                startedAt: DateTime(2026, 3, 18, 12),
              ),
            ),
          ),
          appChrome: const _TestAppChrome(),
          transcriptRegion: const Center(child: Text('Transcript region')),
          composerRegion: const Text('Composer region'),
          onStopActiveTurn: () async {
            stopCalls += 1;
          },
        ),
      ),
    );

    expect(find.textContaining('Elapsed'), findsOneWidget);
    expect(find.byKey(const ValueKey('stop_active_turn')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stop_active_turn')));
    await tester.pumpAndSettle();

    expect(stopCalls, 1);
  });
}

ChatScreenContract _screenContract({
  bool isConfigured = true,
  ChatEmptyStateContract? emptyState,
  List<ChatTimelineSummaryContract> timelineSummaries =
      const <ChatTimelineSummaryContract>[],
  ChatTurnIndicatorContract? turnIndicator,
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
      ChatScreenActionContract(
        id: ChatScreenActionId.branchConversation,
        label: 'Branch conversation',
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
      isSendActionEnabled: true,
      placeholder: 'Message Codex',
    ),
    connectionSettings: ChatConnectionSettingsLaunchContract(
      initialProfile: ConnectionProfile.defaults(),
      initialSecrets: const ConnectionSecrets(),
    ),
    turnIndicator: turnIndicator,
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
