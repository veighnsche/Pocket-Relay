import 'root_adapter_test_support.dart';

void main() {
  testWidgets(
    'menu actions start a fresh thread and clear the transcript through the bound lane',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient();
      final overlayDelegate = FakeChatRootOverlayDelegate();
      final laneBinding = buildLaneBinding(
        agentAdapterClient: appServerClient,
        savedProfile: savedProfile(),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);

      await tester.pumpWidget(
        buildAdapterApp(
          agentAdapterClient: appServerClient,
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
      completeActiveTurn(appServerClient);
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
      completeActiveTurn(appServerClient, turnId: 'turn_2');
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
    'menu disables new thread and clear transcript while a turn is active',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient();
      final overlayDelegate = FakeChatRootOverlayDelegate();
      final laneBinding = buildLaneBinding(
        agentAdapterClient: appServerClient,
        savedProfile: savedProfile(),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);

      await tester.pumpWidget(
        buildAdapterApp(
          agentAdapterClient: appServerClient,
          overlayDelegate: overlayDelegate,
          laneBinding: laneBinding,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('composer_input')),
        'Keep running',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();

      final newThreadItem = tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('New thread'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );
      final clearTranscriptItem = tester.widget<PopupMenuItem<int>>(
        find.ancestor(
          of: find.text('Clear transcript'),
          matching: find.byType(PopupMenuItem<int>),
        ),
      );

      expect(newThreadItem.enabled, isFalse);
      expect(clearTranscriptItem.enabled, isFalse);
    },
  );

  testWidgets(
    'menu actions can branch the active conversation through the lane',
    (tester) async {
      final appServerClient = FakeAgentAdapterClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        )
        ..forkThreadId = 'thread_forked'
        ..threadHistoriesById['thread_forked'] = savedConversationThread(
          threadId: 'thread_forked',
        );
      final overlayDelegate = FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: savedProfile()),
        agentAdapterClient: appServerClient,
        initialSavedProfile: savedProfile(),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);
      await restoreConversationInLane(laneBinding, 'thread_saved');

      await tester.pumpWidget(
        buildAdapterApp(
          agentAdapterClient: appServerClient,
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
}
