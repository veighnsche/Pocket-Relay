import 'renderer_test_support.dart';

void main() {
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
              screen: screenContract(
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
            screen: screenContract(
              timelineSummaries: const <ChatTimelineSummaryContract>[
                ChatTimelineSummaryContract(
                  threadId: 'thread_root',
                  label: 'Main',
                  status: TranscriptAgentLifecycleState.running,
                  isPrimary: true,
                  isSelected: true,
                  isClosed: false,
                  hasUnreadActivity: false,
                  hasPendingRequests: false,
                ),
                ChatTimelineSummaryContract(
                  threadId: 'thread_child',
                  label: 'Reviewer',
                  status: TranscriptAgentLifecycleState.blockedOnApproval,
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

  testWidgets(
    'transcript region shows attached local image filenames for user messages',
    (tester) async {
      final imageDraft = const ChatComposerDraft(
        text: 'See [Image #1]',
        imageAttachments: <ChatComposerImageAttachment>[
          ChatComposerImageAttachment(
            imageUrl: 'data:image/png;base64,cmVmZXJlbmNl',
            displayName: 'reference.png',
            placeholder: '[Image #1]',
          ),
        ],
      ).normalized();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildPocketTheme(Brightness.light),
          home: Scaffold(
            body: FlutterChatTranscriptRegion(
              screen: screenContract(
                mainItems: <ChatTranscriptItemContract>[
                  ChatUserMessageItemContract(
                    block: TranscriptUserMessageBlock(
                      id: 'user_1',
                      createdAt: DateTime(2026, 3, 22, 12),
                      text: imageDraft.text,
                      deliveryState: TranscriptUserMessageDeliveryState.sent,
                      structuredDraft: imageDraft,
                    ),
                  ),
                ],
              ),
              platformBehavior: PocketPlatformBehavior.resolve(),
              onScreenAction: (_) {},
              onSelectTimeline: (_) {},
              onSelectConnectionMode: (_) {},
              onAutoFollowEligibilityChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('See [Image #1]'), findsOneWidget);
      expect(find.text('[Image #1] reference.png'), findsOneWidget);
    },
  );
}
