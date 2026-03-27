import 'root_adapter_test_support.dart';

void main() {
  testWidgets(
    'long-pressing a saved user message opens a context menu and can continue from that prompt after rollback',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        );
      final overlayDelegate = FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: savedProfile()),
        appServerClient: appServerClient,
        initialSavedProfile: savedProfile(),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);
      await restoreConversationInLane(laneBinding, 'thread_saved');

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          laneBinding: laneBinding,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Restore this'), findsOneWidget);

      appServerClient.threadHistoriesById['thread_saved'] =
          rewoundConversationThread(threadId: 'thread_saved');

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
    'eligible saved prompts expose continue from here through the touch action sheet',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        );
      final overlayDelegate = FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: savedProfile()),
        appServerClient: appServerClient,
        initialSavedProfile: savedProfile(),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);
      await restoreConversationInLane(laneBinding, 'thread_saved');

      await tester.pumpWidget(
        buildAdapterApp(
          appServerClient: appServerClient,
          overlayDelegate: overlayDelegate,
          laneBinding: laneBinding,
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Restore this'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ListTile>(
              find.widgetWithText(ListTile, 'Continue From Here'),
            )
            .enabled,
        isTrue,
      );

      await tester.tap(find.text('Copy Prompt'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('Second prompt'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ListTile>(
              find.widgetWithText(ListTile, 'Continue From Here'),
            )
            .enabled,
        isTrue,
      );
    },
  );

  testWidgets('continue from here can rewind from a later saved prompt', (
    tester,
  ) async {
    final appServerClient = FakeCodexAppServerClient()
      ..threadHistoriesById['thread_saved'] = savedConversationThread(
        threadId: 'thread_saved',
      );
    final overlayDelegate = FakeChatRootOverlayDelegate();
    final laneBinding = ConnectionLaneBinding(
      connectionId: 'conn_primary',
      profileStore: MemoryCodexProfileStore(initialValue: savedProfile()),
      appServerClient: appServerClient,
      initialSavedProfile: savedProfile(),
    );
    addTearDown(appServerClient.close);
    addTearDown(laneBinding.dispose);
    await restoreConversationInLane(laneBinding, 'thread_saved');

    await tester.pumpWidget(
      buildAdapterApp(
        appServerClient: appServerClient,
        overlayDelegate: overlayDelegate,
        laneBinding: laneBinding,
      ),
    );
    await tester.pumpAndSettle();

    appServerClient.threadHistoriesById['thread_saved'] =
        partiallyRewoundConversationThread(threadId: 'thread_saved');

    await tester.longPress(find.text('Second prompt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue From Here'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(
      appServerClient.rollbackThreadCalls,
      <({String threadId, int numTurns})>[
        (threadId: 'thread_saved', numTurns: 1),
      ],
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('composer_input')))
          .controller
          ?.text,
      'Second prompt',
    );
    expect(find.text('Restore this'), findsOneWidget);
    expect(find.text('Restored answer'), findsOneWidget);
    expect(find.text('Second prompt'), findsOneWidget);
    expect(find.text('Second answer'), findsNothing);
  });

  testWidgets(
    'long-press rollback failure keeps the transcript intact and shows feedback',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        )
        ..rollbackThreadError = StateError('transport broke');
      final overlayDelegate = FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: savedProfile()),
        appServerClient: appServerClient,
        initialSavedProfile: savedProfile(),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);
      await restoreConversationInLane(laneBinding, 'thread_saved');

      await tester.pumpWidget(
        buildAdapterApp(
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
        '[PR-CHAT-1202] Continue from prompt failed. Could not rewind this conversation to the selected prompt.',
      );
    },
  );

  testWidgets(
    'busy conversations do not surface continue from here in the long-press menu',
    (tester) async {
      final appServerClient = FakeCodexAppServerClient()
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        );
      final overlayDelegate = FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: savedProfile()),
        appServerClient: appServerClient,
        initialSavedProfile: savedProfile(),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);
      await restoreConversationInLane(laneBinding, 'thread_saved');

      await tester.pumpWidget(
        buildAdapterApp(
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
        ..threadHistoriesById['thread_saved'] = savedConversationThread(
          threadId: 'thread_saved',
        );
      final overlayDelegate = FakeChatRootOverlayDelegate();
      final laneBinding = ConnectionLaneBinding(
        connectionId: 'conn_primary',
        profileStore: MemoryCodexProfileStore(initialValue: savedProfile()),
        appServerClient: appServerClient,
        initialSavedProfile: savedProfile(),
      );
      addTearDown(appServerClient.close);
      addTearDown(laneBinding.dispose);
      await restoreConversationInLane(laneBinding, 'thread_saved');

      await tester.pumpWidget(
        buildAdapterApp(
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
          rewoundConversationThread(threadId: 'thread_saved');

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
}
