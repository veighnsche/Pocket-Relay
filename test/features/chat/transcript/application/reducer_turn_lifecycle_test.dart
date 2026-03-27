import 'reducer_test_support.dart';

void main() {
  var monotonicNow = Duration.zero;

  setUp(() {
    monotonicNow = Duration.zero;
    CodexMonotonicClock.debugSetNowProvider(() => monotonicNow);
  });

  tearDown(() {
    CodexMonotonicClock.debugSetNowProvider(null);
  });

  test('tracks thread and turn ids and captures usage summaries', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);
    final completedAt = now.add(const Duration(seconds: 5));

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeThreadStartedEvent(
        createdAt: now,
        threadId: 'thread_123',
        providerThreadId: 'thread_123',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnStartedEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
      ),
    );
    expect(state.activeTurn?.timer.startedAt, now);
    monotonicNow = const Duration(seconds: 5);
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnCompletedEvent(
        createdAt: completedAt,
        threadId: 'thread_123',
        turnId: 'turn_123',
        state: CodexRuntimeTurnState.completed,
        usage: const CodexRuntimeTurnUsage(
          inputTokens: 12,
          cachedInputTokens: 3,
          outputTokens: 7,
        ),
      ),
    );

    expect(state.threadId, 'thread_123');
    expect(state.activeTurn, isNull);
    expect(state.blocks, hasLength(1));
    final boundary = state.blocks.last as CodexTurnBoundaryBlock;
    expect(boundary.elapsed, const Duration(seconds: 5));
  });

  test('finalizes the active turn timer when the session exits', () {
    final reducer = TranscriptReducer();
    final startedAt = DateTime(2026, 3, 14, 12);
    final exitedAt = startedAt.add(const Duration(seconds: 9));
    var state = CodexSessionState.initial();

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnStartedEvent(
        createdAt: startedAt,
        threadId: 'thread_123',
        turnId: 'turn_123',
      ),
    );

    monotonicNow = const Duration(seconds: 9);
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeSessionExitedEvent(
        createdAt: exitedAt,
        exitKind: CodexRuntimeSessionExitKind.error,
        reason: 'Socket closed',
      ),
    );

    expect(state.activeTurn, isNull);
    final errorBlock = state.blocks.single as CodexErrorBlock;
    expect(errorBlock.body, contains('Elapsed 0:09'));
  });

  test(
    'uses monotonic elapsed time instead of wall-clock span on completion',
    () {
      final reducer = TranscriptReducer();
      var state = CodexSessionState.initial();
      final startedAt = DateTime(2026, 3, 14, 12);
      final completedAt = startedAt.add(const Duration(minutes: 10));

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeTurnStartedEvent(
          createdAt: startedAt,
          threadId: 'thread_123',
          turnId: 'turn_123',
        ),
      );

      monotonicNow = const Duration(seconds: 5);
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeTurnCompletedEvent(
          createdAt: completedAt,
          threadId: 'thread_123',
          turnId: 'turn_123',
          state: CodexRuntimeTurnState.completed,
        ),
      );

      expect(
        (state.blocks.single as CodexTurnBoundaryBlock).elapsed,
        const Duration(seconds: 5),
      );
    },
  );

  test('commits the previous turn and boundary when a new turn starts', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final startedAt = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnStartedEvent(
        createdAt: startedAt,
        threadId: 'thread_123',
        turnId: 'turn_123',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: startedAt.add(const Duration(milliseconds: 1)),
        itemType: CodexCanonicalItemType.assistantMessage,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_123',
        status: CodexRuntimeItemStatus.completed,
        snapshot: const <String, Object?>{'text': 'First turn'},
      ),
    );

    monotonicNow = const Duration(seconds: 4);
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnStartedEvent(
        createdAt: startedAt.add(const Duration(seconds: 4)),
        threadId: 'thread_123',
        turnId: 'turn_456',
      ),
    );

    expect(state.activeTurn?.turnId, 'turn_456');
    expect(state.blocks, hasLength(2));
    expect(state.blocks.first, isA<CodexTextBlock>());
    expect((state.blocks.first as CodexTextBlock).body, 'First turn');
    expect(state.blocks.last, isA<CodexTurnBoundaryBlock>());
    expect(
      (state.blocks.last as CodexTurnBoundaryBlock).elapsed,
      const Duration(seconds: 4),
    );
  });

  test('ignores late completion events for an already rolled-over turn', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final startedAt = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: startedAt,
        itemType: CodexCanonicalItemType.assistantMessage,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_123',
        status: CodexRuntimeItemStatus.completed,
        snapshot: const <String, Object?>{'text': 'First turn'},
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnStartedEvent(
        createdAt: startedAt.add(const Duration(seconds: 1)),
        threadId: 'thread_123',
        turnId: 'turn_456',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeContentDeltaEvent(
        createdAt: startedAt.add(const Duration(seconds: 2)),
        threadId: 'thread_123',
        turnId: 'turn_456',
        itemId: 'item_456',
        streamKind: CodexRuntimeContentStreamKind.assistantText,
        delta: 'Second turn',
      ),
    );

    final baselineBlocks = List<CodexUiBlock>.from(state.blocks);
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnCompletedEvent(
        createdAt: startedAt.add(const Duration(seconds: 3)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        state: CodexRuntimeTurnState.completed,
      ),
    );

    expect(state.connectionStatus, CodexRuntimeSessionState.running);
    expect(state.activeTurn?.turnId, 'turn_456');
    expect(state.blocks, baselineBlocks);
    expect(state.transcriptBlocks.last, isA<CodexTextBlock>());
    expect((state.transcriptBlocks.last as CodexTextBlock).body, 'Second turn');
  });

  test(
    'pauses elapsed work time while approval is pending and resumes after resolution',
    () {
      final reducer = TranscriptReducer();
      var state = CodexSessionState.initial();
      final startedAt = DateTime(2026, 3, 14, 12);

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeTurnStartedEvent(
          createdAt: startedAt,
          threadId: 'thread_123',
          turnId: 'turn_123',
        ),
      );

      monotonicNow = const Duration(seconds: 4);
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeRequestOpenedEvent(
          createdAt: startedAt.add(const Duration(seconds: 4)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          requestId: 'approval_1',
          requestType: CodexCanonicalRequestType.execCommandApproval,
          detail: 'Approve command',
        ),
      );

      expect(state.activeTurn?.timer.isPaused, isTrue);
      expect(
        state.activeTurn?.timer.elapsedAt(
          startedAt.add(const Duration(seconds: 20)),
          monotonicNow: const Duration(seconds: 20),
        ),
        const Duration(seconds: 4),
      );

      monotonicNow = const Duration(seconds: 20);
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeRequestResolvedEvent(
          createdAt: startedAt.add(const Duration(seconds: 20)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          requestId: 'approval_1',
          requestType: CodexCanonicalRequestType.execCommandApproval,
        ),
      );

      expect(state.activeTurn?.timer.isPaused, isFalse);

      monotonicNow = const Duration(seconds: 25);
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeTurnCompletedEvent(
          createdAt: startedAt.add(const Duration(seconds: 25)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          state: CodexRuntimeTurnState.completed,
        ),
      );

      expect(
        (state.blocks.last as CodexTurnBoundaryBlock).elapsed,
        const Duration(seconds: 9),
      );
    },
  );

  test('commits the live turn before clearing thread state on close', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final startedAt = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnStartedEvent(
        createdAt: startedAt,
        threadId: 'thread_123',
        turnId: 'turn_123',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: startedAt.add(const Duration(milliseconds: 1)),
        itemType: CodexCanonicalItemType.assistantMessage,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_123',
        status: CodexRuntimeItemStatus.completed,
        snapshot: const <String, Object?>{'text': 'Before close'},
      ),
    );

    monotonicNow = const Duration(seconds: 3);
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeThreadStateChangedEvent(
        createdAt: startedAt.add(const Duration(seconds: 3)),
        threadId: 'thread_123',
        state: CodexRuntimeThreadState.closed,
      ),
    );

    expect(state.threadId, isNull);
    expect(state.activeTurn, isNull);
    expect(state.blocks, hasLength(2));
    expect(state.blocks.first, isA<CodexTextBlock>());
    expect(state.blocks.last, isA<CodexTurnBoundaryBlock>());
  });
}
