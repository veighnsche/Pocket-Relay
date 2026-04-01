import 'ui_block_surface_test_support.dart';

void main() {
  testWidgets('renders thread token usage as a compact usage strip', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptUsageBlock(
            id: 'usage_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Thread token usage',
            body:
                'Last: input 10946 · cached 9216 · output 510 · reasoning 288 · total 11456\n'
                'Total: input 21946 · cached 18216 · output 910 · reasoning 488 · total 23356\n'
                'Context window: 258400',
          ),
        ),
      ),
    );

    expect(find.text('Thread usage'), findsOneWidget);
    expect(find.text('ctx 258.4k'), findsOneWidget);
    expect(find.text('current'), findsAtLeastNWidgets(1));
    expect(find.text('total'), findsAtLeastNWidgets(1));
    expect(find.text('in'), findsOneWidget);
    expect(find.text('cache'), findsOneWidget);
    expect(find.text('out'), findsOneWidget);
    expect(find.text('rsn'), findsOneWidget);
    expect(find.text('all'), findsOneWidget);
    expect(find.text('1.7k'), findsOneWidget);
    expect(find.text('2.2k'), findsOneWidget);
    expect(find.text('9.2k'), findsOneWidget);
    expect(find.text('288'), findsOneWidget);
    expect(find.text('18.2k'), findsOneWidget);
    expect(find.text('422'), findsOneWidget);
    expect(find.text('488'), findsOneWidget);
    expect(find.text('4.6k'), findsOneWidget);
  });

  testWidgets(
    'renders duplicate thread token usage as current and total rows',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptUsageBlock(
              id: 'usage_2',
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Thread token usage',
              body:
                  'Last: input 12 · cached 3 · output 7\n'
                  'Total: input 12 · cached 3 · output 7',
            ),
          ),
        ),
      );

      expect(find.text('current'), findsAtLeastNWidgets(1));
      expect(find.text('total'), findsAtLeastNWidgets(1));
      expect(find.text('in'), findsOneWidget);
      expect(find.text('cache'), findsOneWidget);
      expect(find.text('out'), findsOneWidget);
      expect(find.text('rsn'), findsOneWidget);
      expect(find.text('all'), findsOneWidget);
      expect(find.text('9'), findsNWidgets(2));
      expect(find.text('3'), findsNWidgets(2));
      expect(find.text('7'), findsNWidgets(2));
      expect(find.text('16'), findsNWidgets(2));
      expect(find.text('-'), findsNWidgets(2));
    },
  );

  testWidgets('renders turn completion as a compact separator', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptTurnBoundaryBlock(
            id: 'turn_end_1',
            createdAt: DateTime(2026, 3, 14, 12),
          ),
        ),
      ),
    );

    expect(find.text('end'), findsOneWidget);
  });

  testWidgets('renders elapsed time in the turn completion separator', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptTurnBoundaryBlock(
            id: 'turn_end_2',
            createdAt: DateTime(2026, 3, 14, 12),
            elapsed: const Duration(minutes: 1, seconds: 5),
          ),
        ),
      ),
    );

    expect(find.text('end · 1:05'), findsOneWidget);
  });

  testWidgets(
    'renders deferred thread usage inside the turn completion surface',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptTurnBoundaryBlock(
              id: 'turn_end_usage_1',
              createdAt: DateTime(2026, 3, 14, 12),
              usage: TranscriptUsageBlock(
                id: 'usage_embedded_1',
                createdAt: DateTime(2026, 3, 14, 12),
                title: 'Thread token usage',
                body:
                    'Last: input 12 | Total: input 24\nContext window: 200000',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Thread usage'), findsOneWidget);
      expect(find.text('ctx 200k'), findsOneWidget);
      expect(find.text('end'), findsOneWidget);
    },
  );

  testWidgets('keeps the turn completion separator flush on wide layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildTestApp(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1200,
            child: entrySurface(
              block: TranscriptTurnBoundaryBlock(
                id: 'turn_end_flush_1',
                createdAt: DateTime(2026, 3, 14, 12),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(TurnBoundaryMarker.separatorRowKey)).width,
      1200,
    );
  });

  testWidgets('renders a live elapsed footer with the current duration', (
    tester,
  ) async {
    final startedAt = DateTime.now().subtract(const Duration(seconds: 5));

    await tester.pumpWidget(
      buildTestApp(
        child: TurnElapsedFooter(
          turnTimer: TranscriptSessionTurnTimer(
            turnId: 'turn_123',
            startedAt: startedAt,
          ),
        ),
      ),
    );

    expect(find.textContaining('Elapsed 0:05'), findsOneWidget);
  });
}
