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

  test(
    'creates and updates assistant entries from lifecycle and delta events',
    () {
      final reducer = TranscriptReducer();
      var state = TranscriptSessionState.initial();
      final now = DateTime(2026, 3, 14, 12);

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeTurnStartedEvent(
          createdAt: now,
          threadId: 'thread_123',
          turnId: 'turn_123',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemStartedEvent(
          createdAt: now,
          itemType: TranscriptCanonicalItemType.assistantMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          status: TranscriptRuntimeItemStatus.inProgress,
          detail: 'Draft response',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          streamKind: TranscriptRuntimeContentStreamKind.assistantText,
          delta: 'Hello',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now,
          itemType: TranscriptCanonicalItemType.assistantMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'Hello, world'},
        ),
      );

      expect(state.connectionStatus, TranscriptRuntimeSessionState.running);
      expect(state.activeTurn, isNotNull);
      expect(state.activeTurn?.itemsById, isEmpty);
      expect(state.activeTurn?.artifacts, hasLength(1));
      final artifact =
          state.activeTurn!.artifacts.single as TranscriptTurnTextArtifact;
      expect(artifact.kind, TranscriptUiBlockKind.assistantMessage);
      expect(artifact.body, 'Hello, world');
      expect(state.blocks, isEmpty);
      final block = state.transcriptBlocks.single as TranscriptTextBlock;
      expect(block.kind, TranscriptUiBlockKind.assistantMessage);
      expect(block.body, 'Hello, world');
      expect(block.isRunning, isFalse);
    },
  );

  test('preserves bootstrapped turn state when turn start arrives late', () {
    final reducer = TranscriptReducer();
    var state = TranscriptSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeContentDeltaEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_123',
        streamKind: TranscriptRuntimeContentStreamKind.assistantText,
        delta: 'Hello',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeTurnStartedEvent(
        createdAt: now.add(const Duration(milliseconds: 50)),
        threadId: 'thread_123',
        turnId: 'turn_123',
      ),
    );

    expect(state.activeTurn?.turnId, 'turn_123');
    expect(state.activeTurn?.threadId, 'thread_123');
    expect(state.activeTurn?.artifacts, hasLength(1));
    expect(state.transcriptBlocks.single, isA<TranscriptTextBlock>());
    expect(
      (state.transcriptBlocks.single as TranscriptTextBlock).body,
      'Hello',
    );
  });

  test('renders official user-message items as user transcript blocks', () {
    final reducer = TranscriptReducer();
    var state = TranscriptSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeItemCompletedEvent(
        createdAt: now,
        itemType: TranscriptCanonicalItemType.userMessage,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_user',
        status: TranscriptRuntimeItemStatus.completed,
        snapshot: const <String, Object?>{'text': 'Ship the fix'},
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks.single, isA<TranscriptUserMessageBlock>());
    final block = state.transcriptBlocks.single as TranscriptUserMessageBlock;
    expect(block.text, 'Ship the fix');
    expect(block.deliveryState, TranscriptUserMessageDeliveryState.sent);
  });

  test('preserves spaces while assistant text is still streaming', () {
    final reducer = TranscriptReducer();
    var state = TranscriptSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeItemStartedEvent(
        createdAt: now,
        itemType: TranscriptCanonicalItemType.assistantMessage,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_streaming',
        status: TranscriptRuntimeItemStatus.inProgress,
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeContentDeltaEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_streaming',
        streamKind: TranscriptRuntimeContentStreamKind.assistantText,
        delta: 'The',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeContentDeltaEvent(
        createdAt: now.add(const Duration(milliseconds: 1)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_streaming',
        streamKind: TranscriptRuntimeContentStreamKind.assistantText,
        delta: ' shell',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeContentDeltaEvent(
        createdAt: now.add(const Duration(milliseconds: 2)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_streaming',
        streamKind: TranscriptRuntimeContentStreamKind.assistantText,
        delta: ' session',
      ),
    );

    final block = state.transcriptBlocks.single as TranscriptTextBlock;
    expect(block.body, 'The shell session');
    expect(block.isRunning, isTrue);
  });

  test(
    'starts a new assistant surface when the same item resumes after an intervening warning',
    () {
      final reducer = TranscriptReducer();
      var state = TranscriptSessionState.initial();
      final now = DateTime(2026, 3, 14, 12);

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemStartedEvent(
          createdAt: now,
          itemType: TranscriptCanonicalItemType.assistantMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_streaming',
          status: TranscriptRuntimeItemStatus.inProgress,
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_streaming',
          streamKind: TranscriptRuntimeContentStreamKind.assistantText,
          delta: 'First',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeWarningEvent(
          createdAt: now.add(const Duration(milliseconds: 1)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          summary: 'Intervening warning',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 2)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_streaming',
          streamKind: TranscriptRuntimeContentStreamKind.assistantText,
          delta: 'Second',
        ),
      );

      expect(state.activeTurn?.artifacts, hasLength(3));
      final frozenArtifact =
          state.activeTurn!.artifacts.first as TranscriptTurnTextArtifact;
      expect(frozenArtifact.id, 'item_item_streaming');
      expect(frozenArtifact.body, 'First');
      expect(frozenArtifact.isStreaming, isFalse);

      expect(state.transcriptBlocks, hasLength(3));
      final firstBlock = state.transcriptBlocks.first as TranscriptTextBlock;
      expect(firstBlock.body, 'First');
      expect(firstBlock.isRunning, isFalse);
      expect(state.transcriptBlocks[1], isA<TranscriptStatusBlock>());
      final resumedBlock = state.transcriptBlocks.last as TranscriptTextBlock;
      expect(resumedBlock.id, isNot(firstBlock.id));
      expect(resumedBlock.body, 'Second');
      expect(resumedBlock.isRunning, isTrue);
    },
  );

  test('renders review and compaction items as status blocks', () {
    final reducer = TranscriptReducer();
    var state = TranscriptSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeItemCompletedEvent(
        createdAt: now,
        itemType: TranscriptCanonicalItemType.reviewEntered,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_review',
        status: TranscriptRuntimeItemStatus.completed,
        detail: 'Checking the patch set',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeItemCompletedEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        itemType: TranscriptCanonicalItemType.contextCompaction,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_compaction',
        status: TranscriptRuntimeItemStatus.completed,
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks, hasLength(2));
    expect(state.transcriptBlocks.first, isA<TranscriptStatusBlock>());
    expect(state.transcriptBlocks.last, isA<TranscriptStatusBlock>());
    expect(
      (state.transcriptBlocks.first as TranscriptStatusBlock).body,
      'Checking the patch set',
    );
    expect(
      (state.transcriptBlocks.first as TranscriptStatusBlock).statusKind,
      TranscriptStatusBlockKind.review,
    );
    expect(
      (state.transcriptBlocks.last as TranscriptStatusBlock).body,
      'Codex compacted the current thread context.',
    );
    expect(
      (state.transcriptBlocks.last as TranscriptStatusBlock).statusKind,
      TranscriptStatusBlockKind.compaction,
    );
  });

  test('suppresses empty reasoning lifecycle blocks until text arrives', () {
    final reducer = TranscriptReducer();
    final now = DateTime(2026, 3, 14, 12);
    var state = TranscriptSessionState.initial();

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeItemStartedEvent(
        createdAt: now,
        itemType: TranscriptCanonicalItemType.reasoning,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_reasoning',
        status: TranscriptRuntimeItemStatus.inProgress,
      ),
    );

    expect(state.transcriptBlocks, isEmpty);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeContentDeltaEvent(
        createdAt: now.add(const Duration(milliseconds: 1)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_reasoning',
        streamKind: TranscriptRuntimeContentStreamKind.reasoningText,
        delta: 'Inspecting the environment.',
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks.single, isA<TranscriptTextBlock>());
    final block = state.transcriptBlocks.single as TranscriptTextBlock;
    expect(block.kind, TranscriptUiBlockKind.reasoning);
    expect(block.body, 'Inspecting the environment.');
  });
}
