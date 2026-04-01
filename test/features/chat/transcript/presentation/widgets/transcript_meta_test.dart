import 'ui_block_surface_test_support.dart';

void main() {
  testWidgets(
    'shows a top-of-transcript limit notice when older items are hidden',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            height: 200,
            child: TranscriptList(
              surface: surfaceContract(
                mainItems: <TranscriptUiBlock>[
                  TranscriptTextBlock(
                    id: 'assistant_latest_1',
                    kind: TranscriptUiBlockKind.assistantMessage,
                    createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                    title: 'Codex',
                    body: 'Latest message 1',
                  ),
                  TranscriptTextBlock(
                    id: 'assistant_latest_2',
                    kind: TranscriptUiBlockKind.assistantMessage,
                    createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                    title: 'Codex',
                    body: 'Latest message 2',
                  ),
                ],
                totalMainItemCount: 5,
              ),
              followBehavior: defaultFollowBehavior,
              platformBehavior: PocketPlatformBehavior.resolve(),
              onConfigure: () {},
              onAutoFollowEligibilityChanged: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.text(
          'Showing the most recent 2 of 5 transcript items. Older activity is not shown in this view.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'does not show a transcript limit notice when nothing is hidden',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: SizedBox(
            height: 200,
            child: TranscriptList(
              surface: surfaceContract(
                mainItems: <TranscriptUiBlock>[
                  TranscriptTextBlock(
                    id: 'assistant_latest_1',
                    kind: TranscriptUiBlockKind.assistantMessage,
                    createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                    title: 'Codex',
                    body: 'Latest message 1',
                  ),
                ],
              ),
              followBehavior: defaultFollowBehavior,
              platformBehavior: PocketPlatformBehavior.resolve(),
              onConfigure: () {},
              onAutoFollowEligibilityChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Showing the most recent'), findsNothing);
    },
  );

  testWidgets(
    'renders proposed plans with extracted title and collapse control',
    (tester) async {
      final markdownLines = <String>[
        '# Ship mobile widgets',
        '',
        '## Summary',
        '',
        for (var index = 0; index < 24; index += 1)
          '- Step ${index + 1} for the rollout',
      ];

      await tester.pumpWidget(
        buildTestApp(
          child: SingleChildScrollView(
            child: entrySurface(
              block: TranscriptProposedPlanBlock(
                id: 'plan_1',
                createdAt: DateTime(2026, 3, 14, 12),
                title: 'Proposed plan',
                markdown: markdownLines.join('\n'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ship mobile widgets'), findsOneWidget);
      expect(find.text('Summary'), findsNothing);
      expect(find.text('Expand plan'), findsOneWidget);
      expect(
        findDecoratedContainerColorForText(tester, 'Step 1 for the rollout'),
        isNull,
      );

      await tester.tap(find.text('Expand plan'));
      await tester.pumpAndSettle();

      expect(find.text('Collapse plan'), findsOneWidget);
    },
  );

  testWidgets(
    'keys transcript surfaces by block id so local state does not leak',
    (tester) async {
      final markdownLines = <String>[
        '# Ship mobile widgets',
        '',
        '## Summary',
        '',
        for (var index = 0; index < 24; index += 1)
          '- Step ${index + 1} for the rollout',
      ];

      await tester.pumpWidget(
        buildTestApp(
          child: TranscriptList(
            surface: surfaceContract(
              mainItems: <TranscriptUiBlock>[
                TranscriptProposedPlanBlock(
                  id: 'plan_1',
                  createdAt: DateTime(2026, 3, 14, 12),
                  title: 'Proposed plan',
                  markdown: markdownLines.join('\n'),
                ),
              ],
            ),
            followBehavior: defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'plan_1',
          ),
        ),
      );

      await tester.tap(find.text('Expand plan'));
      await tester.pumpAndSettle();
      expect(find.text('Collapse plan'), findsOneWidget);

      await tester.pumpWidget(
        buildTestApp(
          child: TranscriptList(
            surface: surfaceContract(
              mainItems: <TranscriptUiBlock>[
                TranscriptProposedPlanBlock(
                  id: 'plan_2',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 5),
                  title: 'Proposed plan',
                  markdown: markdownLines.join('\n'),
                ),
              ],
            ),
            followBehavior: defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'plan_2',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expand plan'), findsOneWidget);
      expect(find.text('Collapse plan'), findsNothing);
    },
  );

  testWidgets(
    'routes follow eligibility and follow requests through the transcript contract',
    (tester) async {
      bool? isNearBottom;
      final blocks = List<TranscriptUiBlock>.generate(
        24,
        (index) => TranscriptTextBlock(
          id: 'assistant_$index',
          kind: TranscriptUiBlockKind.assistantMessage,
          createdAt: DateTime(2026, 3, 14, 12, 0, index),
          title: 'Codex',
          body: 'Assistant message $index',
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: TranscriptList(
            surface: surfaceContract(mainItems: blocks),
            followBehavior: defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (value) {
              isNearBottom = value;
            },
            surfaceChangeToken: 'initial',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableState = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollableState.position.jumpTo(scrollableState.position.maxScrollExtent);
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, 320));
      await tester.pumpAndSettle();

      expect(isNearBottom, isFalse);
      expect(
        scrollableState.position.pixels,
        lessThan(scrollableState.position.maxScrollExtent),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: TranscriptList(
            surface: surfaceContract(mainItems: blocks),
            followBehavior: followBehavior(
              requestId: 1,
              source: ChatTranscriptFollowRequestSource.sendPrompt,
            ),
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (value) {
              isNearBottom = value;
            },
            surfaceChangeToken: 'initial',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        scrollableState.position.pixels,
        closeTo(scrollableState.position.maxScrollExtent, 1),
      );
    },
  );
}
