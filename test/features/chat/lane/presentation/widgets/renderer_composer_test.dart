import 'renderer_test_support.dart';

void main() {
  testWidgets('forwards composer interactions through composer region', (
    tester,
  ) async {
    final draftValues = <ChatComposerDraft>[];
    var sendCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: Scaffold(
          body: FlutterChatComposerRegion(
            platformBehavior: PocketPlatformBehavior.resolve(),
            conversationRecoveryNotice: null,
            historicalConversationRestoreNotice: null,
            composer: screenContract().composer,
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

    expect(
      draftValues.map((draft) => draft.text).toList(growable: false),
      <String>['Plan phase 6'],
    );
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
            composer: screenContract().composer,
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
    var restartCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: FlutterChatScreenRenderer(
          platformBehavior: PocketPlatformBehavior.resolve(),
          screen: screenContract(
            turnIndicator: ChatTurnIndicatorContract(
              timer: TranscriptSessionTurnTimer(
                turnId: 'turn_1',
                startedAt: DateTime(2026, 3, 18, 12),
              ),
            ),
          ),
          appChrome: const TestAppChrome(),
          transcriptRegion: const Center(child: Text('Transcript region')),
          composerRegion: const Text('Composer region'),
          onStopActiveTurn: () async {
            stopCalls += 1;
          },
          laneRestartAction: const ChatLaneRestartActionContract(
            badgeLabel: 'Restart needed',
            label: 'Restart',
          ),
          onRestartLane: () async {
            restartCalls += 1;
          },
        ),
      ),
    );

    expect(find.textContaining('Elapsed'), findsOneWidget);
    expect(find.text('Restart needed'), findsOneWidget);
    expect(find.byKey(const ValueKey('stop_active_turn')), findsOneWidget);
    expect(find.byKey(const ValueKey('restart_lane')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stop_active_turn')));
    await tester.tap(find.byKey(const ValueKey('restart_lane')));
    await tester.pumpAndSettle();

    expect(stopCalls, 1);
    expect(restartCalls, 1);
  });

  testWidgets('renders an inline restart footer without an active turn', (
    tester,
  ) async {
    var restartCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPocketTheme(Brightness.light),
        home: FlutterChatScreenRenderer(
          platformBehavior: PocketPlatformBehavior.resolve(),
          screen: screenContract(),
          appChrome: const TestAppChrome(),
          transcriptRegion: const Center(child: Text('Transcript region')),
          composerRegion: const Text('Composer region'),
          onStopActiveTurn: () async {},
          laneRestartAction: const ChatLaneRestartActionContract(
            badgeLabel: 'Restart needed',
            label: 'Restart',
          ),
          onRestartLane: () async {
            restartCalls += 1;
          },
        ),
      ),
    );

    expect(find.text('Restart needed'), findsOneWidget);
    expect(find.byKey(const ValueKey('restart_lane')), findsOneWidget);
    expect(find.byKey(const ValueKey('stop_active_turn')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('restart_lane')));
    await tester.pumpAndSettle();

    expect(restartCalls, 1);
  });
}
