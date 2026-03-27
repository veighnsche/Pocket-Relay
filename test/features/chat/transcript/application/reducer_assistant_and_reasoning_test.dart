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
      var state = CodexSessionState.initial();
      final now = DateTime(2026, 3, 14, 12);

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeTurnStartedEvent(
          createdAt: now,
          threadId: 'thread_123',
          turnId: 'turn_123',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemStartedEvent(
          createdAt: now,
          itemType: CodexCanonicalItemType.assistantMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          status: CodexRuntimeItemStatus.inProgress,
          detail: 'Draft response',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeContentDeltaEvent(
          createdAt: now,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          streamKind: CodexRuntimeContentStreamKind.assistantText,
          delta: 'Hello',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemCompletedEvent(
          createdAt: now,
          itemType: CodexCanonicalItemType.assistantMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          status: CodexRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'Hello, world'},
        ),
      );

      expect(state.connectionStatus, CodexRuntimeSessionState.running);
      expect(state.activeTurn, isNotNull);
      expect(state.activeTurn?.itemsById, isEmpty);
      expect(state.activeTurn?.artifacts, hasLength(1));
      final artifact =
          state.activeTurn!.artifacts.single as CodexTurnTextArtifact;
      expect(artifact.kind, CodexUiBlockKind.assistantMessage);
      expect(artifact.body, 'Hello, world');
      expect(state.blocks, isEmpty);
      final block = state.transcriptBlocks.single as CodexTextBlock;
      expect(block.kind, CodexUiBlockKind.assistantMessage);
      expect(block.body, 'Hello, world');
      expect(block.isRunning, isFalse);
    },
  );

  test('preserves bootstrapped turn state when turn start arrives late', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeContentDeltaEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_123',
        streamKind: CodexRuntimeContentStreamKind.assistantText,
        delta: 'Hello',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnStartedEvent(
        createdAt: now.add(const Duration(milliseconds: 50)),
        threadId: 'thread_123',
        turnId: 'turn_123',
      ),
    );

    expect(state.activeTurn?.turnId, 'turn_123');
    expect(state.activeTurn?.threadId, 'thread_123');
    expect(state.activeTurn?.artifacts, hasLength(1));
    expect(state.transcriptBlocks.single, isA<CodexTextBlock>());
    expect((state.transcriptBlocks.single as CodexTextBlock).body, 'Hello');
  });

  test('renders official user-message items as user transcript blocks', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: now,
        itemType: CodexCanonicalItemType.userMessage,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_user',
        status: CodexRuntimeItemStatus.completed,
        snapshot: const <String, Object?>{'text': 'Ship the fix'},
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks.single, isA<CodexUserMessageBlock>());
    final block = state.transcriptBlocks.single as CodexUserMessageBlock;
    expect(block.text, 'Ship the fix');
    expect(block.deliveryState, CodexUserMessageDeliveryState.sent);
  });

  test('preserves spaces while assistant text is still streaming', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemStartedEvent(
        createdAt: now,
        itemType: CodexCanonicalItemType.assistantMessage,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_streaming',
        status: CodexRuntimeItemStatus.inProgress,
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeContentDeltaEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_streaming',
        streamKind: CodexRuntimeContentStreamKind.assistantText,
        delta: 'The',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeContentDeltaEvent(
        createdAt: now.add(const Duration(milliseconds: 1)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_streaming',
        streamKind: CodexRuntimeContentStreamKind.assistantText,
        delta: ' shell',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeContentDeltaEvent(
        createdAt: now.add(const Duration(milliseconds: 2)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_streaming',
        streamKind: CodexRuntimeContentStreamKind.assistantText,
        delta: ' session',
      ),
    );

    final block = state.transcriptBlocks.single as CodexTextBlock;
    expect(block.body, 'The shell session');
    expect(block.isRunning, isTrue);
  });

  test(
    'starts a new assistant surface when the same item resumes after an intervening warning',
    () {
      final reducer = TranscriptReducer();
      var state = CodexSessionState.initial();
      final now = DateTime(2026, 3, 14, 12);

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemStartedEvent(
          createdAt: now,
          itemType: CodexCanonicalItemType.assistantMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_streaming',
          status: CodexRuntimeItemStatus.inProgress,
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeContentDeltaEvent(
          createdAt: now,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_streaming',
          streamKind: CodexRuntimeContentStreamKind.assistantText,
          delta: 'First',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeWarningEvent(
          createdAt: now.add(const Duration(milliseconds: 1)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          summary: 'Intervening warning',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 2)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_streaming',
          streamKind: CodexRuntimeContentStreamKind.assistantText,
          delta: 'Second',
        ),
      );

      expect(state.activeTurn?.artifacts, hasLength(3));
      final frozenArtifact =
          state.activeTurn!.artifacts.first as CodexTurnTextArtifact;
      expect(frozenArtifact.id, 'item_item_streaming');
      expect(frozenArtifact.body, 'First');
      expect(frozenArtifact.isStreaming, isFalse);

      expect(state.transcriptBlocks, hasLength(3));
      final firstBlock = state.transcriptBlocks.first as CodexTextBlock;
      expect(firstBlock.body, 'First');
      expect(firstBlock.isRunning, isFalse);
      expect(state.transcriptBlocks[1], isA<CodexStatusBlock>());
      final resumedBlock = state.transcriptBlocks.last as CodexTextBlock;
      expect(resumedBlock.id, isNot(firstBlock.id));
      expect(resumedBlock.body, 'Second');
      expect(resumedBlock.isRunning, isTrue);
    },
  );

  test('renders review and compaction items as status blocks', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: now,
        itemType: CodexCanonicalItemType.reviewEntered,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_review',
        status: CodexRuntimeItemStatus.completed,
        detail: 'Checking the patch set',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        itemType: CodexCanonicalItemType.contextCompaction,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_compaction',
        status: CodexRuntimeItemStatus.completed,
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks, hasLength(2));
    expect(state.transcriptBlocks.first, isA<CodexStatusBlock>());
    expect(state.transcriptBlocks.last, isA<CodexStatusBlock>());
    expect(
      (state.transcriptBlocks.first as CodexStatusBlock).body,
      'Checking the patch set',
    );
    expect(
      (state.transcriptBlocks.first as CodexStatusBlock).statusKind,
      CodexStatusBlockKind.review,
    );
    expect(
      (state.transcriptBlocks.last as CodexStatusBlock).body,
      'Codex compacted the current thread context.',
    );
    expect(
      (state.transcriptBlocks.last as CodexStatusBlock).statusKind,
      CodexStatusBlockKind.compaction,
    );
  });

  test('suppresses empty reasoning lifecycle blocks until text arrives', () {
    final reducer = TranscriptReducer();
    final now = DateTime(2026, 3, 14, 12);
    var state = CodexSessionState.initial();

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemStartedEvent(
        createdAt: now,
        itemType: CodexCanonicalItemType.reasoning,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_reasoning',
        status: CodexRuntimeItemStatus.inProgress,
      ),
    );

    expect(state.transcriptBlocks, isEmpty);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeContentDeltaEvent(
        createdAt: now.add(const Duration(milliseconds: 1)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_reasoning',
        streamKind: CodexRuntimeContentStreamKind.reasoningText,
        delta: 'Inspecting the environment.',
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks.single, isA<CodexTextBlock>());
    final block = state.transcriptBlocks.single as CodexTextBlock;
    expect(block.kind, CodexUiBlockKind.reasoning);
    expect(block.body, 'Inspecting the environment.');
  });
}
