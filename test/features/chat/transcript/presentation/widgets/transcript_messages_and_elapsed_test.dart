import 'ui_block_surface_test_support.dart';

void main() {
  testWidgets(
    'renders assistant messages without a decorated transcript shell',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptTextBlock(
              id: 'assistant_1',
              kind: TranscriptUiBlockKind.assistantMessage,
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Codex',
              body: 'Plain assistant transcript.',
            ),
          ),
        ),
      );

      expect(find.text('Plain assistant transcript.'), findsOneWidget);
      expect(
        findDecoratedContainerColorForText(
          tester,
          'Plain assistant transcript.',
        ),
        isNull,
      );
    },
  );

  testWidgets(
    'renders user messages without header labels and with distinct bubble states',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Column(
            children: [
              entrySurface(
                block: TranscriptUserMessageBlock(
                  id: 'user_local_1',
                  createdAt: DateTime(2026, 3, 14, 12),
                  text: 'Draft prompt',
                  deliveryState: TranscriptUserMessageDeliveryState.localEcho,
                ),
              ),
              const SizedBox(height: 16),
              entrySurface(
                block: TranscriptUserMessageBlock(
                  id: 'user_session_1',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                  text: 'Delivered prompt',
                  deliveryState: TranscriptUserMessageDeliveryState.sent,
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('You'), findsNothing);
      expect(find.text('local echo'), findsNothing);
      expect(find.text('sent'), findsNothing);
      expect(find.text('Draft prompt'), findsOneWidget);
      expect(find.text('Delivered prompt'), findsOneWidget);

      final localBubble = findDecoratedContainerColorForText(
        tester,
        'Draft prompt',
      );
      final sentBubble = findDecoratedContainerColorForText(
        tester,
        'Delivered prompt',
      );

      expect(localBubble, isNotNull);
      expect(sentBubble, isNotNull);
      expect(localBubble, isNot(equals(sentBubble)));
      expect(
        findStyleForText(tester, 'Delivered prompt')?.color,
        const Color(0xFF1C1917),
      );
    },
  );

  testWidgets('uses readable user message text in dark mode', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        themeMode: ThemeMode.dark,
        child: entrySurface(
          block: TranscriptUserMessageBlock(
            id: 'user_dark_1',
            createdAt: DateTime(2026, 3, 14, 12),
            text: 'Dark prompt',
            deliveryState: TranscriptUserMessageDeliveryState.sent,
          ),
        ),
      ),
    );

    expect(
      findStyleForText(tester, 'Dark prompt')?.color,
      const Color(0xFFF4F2ED),
    );
  });

  testWidgets('renders a live elapsed footer as a standalone widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: TurnElapsedFooter(
          turnTimer: TranscriptSessionTurnTimer(
            turnId: 'turn_live',
            startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
          ),
        ),
      ),
    );

    expect(find.textContaining('Elapsed'), findsOneWidget);
  });

  testWidgets('renders a completed elapsed footer as a standalone widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: TurnElapsedFooter(
          turnTimer: TranscriptSessionTurnTimer(
            turnId: 'turn_done',
            startedAt: DateTime(2026, 3, 14, 12),
            completedAt: DateTime(2026, 3, 14, 12, 1, 8),
          ),
        ),
      ),
    );

    expect(find.text('Completed in 1:08'), findsOneWidget);
  });
}
