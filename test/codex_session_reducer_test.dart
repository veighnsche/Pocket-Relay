import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/utils/monotonic_clock.dart';
import 'package:pocket_relay/src/features/chat/application/transcript_reducer.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';

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

  test(
    'does not rewrite a local echo after later transcript history exists',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.addUserMessage(
        CodexSessionState.initial(),
        text: 'Ship the fix',
        createdAt: now,
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeWarningEvent(
          createdAt: now.add(const Duration(milliseconds: 5)),
          summary: 'Connected to the remote session.',
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          itemType: CodexCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user',
          status: CodexRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'Ship the fix'},
        ),
      );

      final committedUserMessages = state.blocks
          .whereType<CodexUserMessageBlock>()
          .toList(growable: false);
      expect(committedUserMessages, hasLength(1));
      expect(
        committedUserMessages.single.deliveryState,
        CodexUserMessageDeliveryState.localEcho,
      );

      final userMessages = state.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .toList(growable: false);
      expect(userMessages, hasLength(1));
      expect(userMessages.single.text, 'Ship the fix');
      expect(
        userMessages.single.deliveryState,
        CodexUserMessageDeliveryState.localEcho,
      );
      expect(userMessages.single.providerItemId, isNull);
      expect(
        state.transcriptBlocks.whereType<CodexStatusBlock>(),
        hasLength(1),
      );
    },
  );

  test('promotes the local echo while it is still the transcript tail', () {
    final reducer = TranscriptReducer();
    final now = DateTime(2026, 3, 14, 12);
    var state = reducer.addUserMessage(
      CodexSessionState.initial(),
      text: 'Ship the fix',
      createdAt: now,
    );

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: now.add(const Duration(milliseconds: 10)),
        itemType: CodexCanonicalItemType.userMessage,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_user_tail',
        status: CodexRuntimeItemStatus.completed,
        snapshot: const <String, Object?>{'text': 'Ship the fix'},
      ),
    );

    final userMessages = state.transcriptBlocks
        .whereType<CodexUserMessageBlock>()
        .toList(growable: false);
    expect(userMessages, hasLength(1));
    expect(
      userMessages.single.deliveryState,
      CodexUserMessageDeliveryState.sent,
    );
    expect(userMessages.single.providerItemId, 'item_user_tail');
  });

  test(
    'keeps a single sent user block when the same app-server item is updated and then completed',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.addUserMessage(
        CodexSessionState.initial(),
        text: 'this is a second test',
        createdAt: now,
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemUpdatedEvent(
          createdAt: now.add(const Duration(milliseconds: 5)),
          itemType: CodexCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user_2',
          status: CodexRuntimeItemStatus.inProgress,
          snapshot: const <String, Object?>{'text': 'this is a second test'},
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          itemType: CodexCanonicalItemType.userMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_user_2',
          status: CodexRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'this is a second test'},
        ),
      );

      final userMessages = state.transcriptBlocks
          .whereType<CodexUserMessageBlock>()
          .toList(growable: false);
      expect(userMessages, hasLength(1));
      expect(userMessages.single.text, 'this is a second test');
      expect(
        userMessages.single.deliveryState,
        CodexUserMessageDeliveryState.sent,
      );
      expect(userMessages.single.providerItemId, 'item_user_2');
    },
  );

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
    'starts a new assistant card when the same item resumes after an intervening warning',
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
      (state.transcriptBlocks.last as CodexStatusBlock).body,
      'Codex compacted the current thread context.',
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

  test(
    'renders reasoning from completed snapshot summaries without deltas',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      final state = reducer.reduceRuntimeEvent(
        CodexSessionState.initial(),
        CodexRuntimeItemCompletedEvent(
          createdAt: now,
          itemType: CodexCanonicalItemType.reasoning,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_reasoning',
          status: CodexRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{
            'summary': <Object?>[
              <String, Object?>{
                'type': 'summary_text',
                'text': 'Inspecting the environment.',
              },
            ],
          },
        ),
      );

      expect(state.transcriptBlocks.single, isA<CodexTextBlock>());
      final block = state.transcriptBlocks.single as CodexTextBlock;
      expect(block.kind, CodexUiBlockKind.reasoning);
      expect(block.body, 'Inspecting the environment.');
      expect(block.isRunning, isFalse);
    },
  );

  test('opens and resolves approval requests', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnStartedEvent(
        createdAt: now.subtract(const Duration(seconds: 1)),
        threadId: 'thread_123',
        turnId: 'turn_123',
      ),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeRequestOpenedEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_123',
        requestId: 'i:99',
        requestType: CodexCanonicalRequestType.fileChangeApproval,
        detail: 'Write files',
      ),
    );

    expect(state.pendingApprovalRequests.keys, contains('i:99'));
    expect(state.activeTurn?.pendingApprovalRequests.keys, contains('i:99'));
    expect(state.activeTurn?.status, CodexActiveTurnStatus.blocked);
    final requestBlock = state.primaryPendingApprovalBlock!;
    expect(requestBlock.title, 'File change approval');

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeRequestResolvedEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_123',
        requestId: 'i:99',
        requestType: CodexCanonicalRequestType.fileChangeApproval,
      ),
    );

    expect(state.pendingApprovalRequests, isEmpty);
    expect(state.activeTurn?.pendingApprovalRequests, isEmpty);
    expect(state.activeTurn?.status, CodexActiveTurnStatus.running);
    expect(state.primaryPendingApprovalBlock, isNull);
    final resolvedBlock =
        state.transcriptBlocks.single as CodexApprovalRequestBlock;
    expect(resolvedBlock.title, 'File change approval resolved');
    expect(resolvedBlock.isResolved, isTrue);
  });

  test('opens and resolves user-input requests', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeUserInputRequestedEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_123',
        requestId: 's:user-input-1',
        questions: const <CodexRuntimeUserInputQuestion>[
          CodexRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Name',
            question: 'What is your name?',
          ),
        ],
      ),
    );

    expect(state.pendingUserInputRequests.keys, contains('s:user-input-1'));
    final inputBlock = state.primaryPendingUserInputBlock!;
    expect(inputBlock.title, 'Input required');

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeUserInputResolvedEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_123',
        requestId: 's:user-input-1',
        answers: const <String, List<String>>{
          'q1': <String>['Vince'],
        },
      ),
    );

    expect(state.pendingUserInputRequests, isEmpty);
    expect(state.primaryPendingUserInputBlock, isNull);
    final submittedBlock =
        state.transcriptBlocks.single as CodexUserInputRequestBlock;
    expect(submittedBlock.title, 'Input submitted');
    expect(submittedBlock.body, contains('Vince'));
    expect(submittedBlock.isResolved, isTrue);
  });

  test(
    'coalesces duplicate user-input resolution events into one request block',
    () {
      final reducer = TranscriptReducer();
      var state = CodexSessionState.initial();
      final now = DateTime(2026, 3, 14, 12);

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeUserInputRequestedEvent(
          createdAt: now,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          requestId: 's:user-input-1',
          questions: const <CodexRuntimeUserInputQuestion>[
            CodexRuntimeUserInputQuestion(
              id: 'q1',
              header: 'Name',
              question: 'What is your name?',
            ),
          ],
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeRequestResolvedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          requestId: 's:user-input-1',
          requestType: CodexCanonicalRequestType.toolUserInput,
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeUserInputResolvedEvent(
          createdAt: now.add(const Duration(milliseconds: 20)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          requestId: 's:user-input-1',
          answers: const <String, List<String>>{
            'q1': <String>['Vince'],
          },
        ),
      );

      final resolvedBlocks = state.transcriptBlocks
          .whereType<CodexUserInputRequestBlock>()
          .toList(growable: false);
      expect(resolvedBlocks, hasLength(1));
      expect(resolvedBlocks.single.id, 'request_s:user-input-1');
      expect(resolvedBlocks.single.title, 'Input submitted');
      expect(resolvedBlocks.single.body, contains('Vince'));
      expect(
        state.transcriptBlocks.map((block) => block.id).toSet().length,
        state.transcriptBlocks.length,
      );
    },
  );

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
    expect(state.latestUsageSummary, 'input 12 · cached 3 · output 7');
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

  test('keeps warnings and errors non-fatal to the UI state', () {
    final reducer = TranscriptReducer();
    var state = const CodexSessionState(
      connectionStatus: CodexRuntimeSessionState.ready,
    );
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeWarningEvent(
        createdAt: now,
        summary: 'Config warning',
        details: 'Bad config value',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeErrorEvent(
        createdAt: now,
        message: 'Command failed',
        errorClass: CodexRuntimeErrorClass.providerError,
      ),
    );

    expect(state.connectionStatus, CodexRuntimeSessionState.ready);
    expect(state.blocks, hasLength(2));
    expect(state.blocks.first, isA<CodexStatusBlock>());
    expect(state.blocks.last, isA<CodexErrorBlock>());
  });

  test('hides non-signal status events and defers thread token usage', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeStatusEvent(
        createdAt: now,
        rawMethod: 'unknown/method',
        title: 'Unknown Method',
        message: 'Received unknown method.',
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks, isEmpty);

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
      CodexRuntimeStatusEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        threadId: 'thread_123',
        rawMethod: 'thread/tokenUsage/updated',
        title: 'Thread token usage',
        message: 'Last: input 10 | Total: input 20\nContext window: 200000',
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks, isEmpty);
    expect(state.activeTurn?.pendingThreadTokenUsageBlock, isNotNull);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeStatusEvent(
        createdAt: now.add(const Duration(seconds: 2)),
        threadId: 'thread_123',
        rawMethod: 'thread/tokenUsage/updated',
        title: 'Thread token usage',
        message: 'Last: input 12 | Total: input 24\nContext window: 200000',
      ),
    );

    expect(state.blocks, isEmpty);
    expect(
      state.activeTurn?.pendingThreadTokenUsageBlock?.body,
      contains('input 24'),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnCompletedEvent(
        createdAt: now.add(const Duration(seconds: 3)),
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

    expect(state.activeTurn, isNull);
    expect(state.blocks, hasLength(1));
    final boundary = state.blocks.single as CodexTurnBoundaryBlock;
    expect(boundary.usage, isNotNull);
    expect(boundary.usage?.title, 'Thread token usage');
    expect(boundary.usage?.body, contains('input 24'));
    expect(state.transcriptBlocks, hasLength(1));
    expect(state.transcriptBlocks.single, isA<CodexTurnBoundaryBlock>());
  });

  test('keeps changed files above the turn-end usage footer', () {
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
      CodexRuntimeStatusEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        threadId: 'thread_123',
        rawMethod: 'thread/tokenUsage/updated',
        title: 'Thread token usage',
        message: 'Last: input 12 | Total: input 24\nContext window: 200000',
      ),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: now.add(const Duration(seconds: 2)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'file_change_1',
        itemType: CodexCanonicalItemType.fileChange,
        status: CodexRuntimeItemStatus.completed,
        snapshot: const <String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'path': 'lib/main.dart',
              'kind': <String, Object?>{'type': 'update'},
              'diff':
                  '--- a/lib/main.dart\n'
                  '+++ b/lib/main.dart\n'
                  '@@ -1 +1 @@\n'
                  '-old\n'
                  '+new\n',
            },
          ],
        },
      ),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnCompletedEvent(
        createdAt: now.add(const Duration(seconds: 3)),
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

    expect(state.transcriptBlocks, hasLength(2));
    expect(state.transcriptBlocks.first, isA<CodexChangedFilesBlock>());
    final boundary = state.transcriptBlocks.last as CodexTurnBoundaryBlock;
    expect(boundary.usage, isNotNull);
    expect(boundary.usage?.title, 'Thread token usage');
  });

  test(
    'creates active turn state on turn start and tracks reasoning/work flags',
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
        CodexRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 1)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_reasoning',
          streamKind: CodexRuntimeContentStreamKind.reasoningText,
          delta: 'Thinking through the patch.',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemStartedEvent(
          createdAt: now.add(const Duration(seconds: 1)),
          itemType: CodexCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_command',
          status: CodexRuntimeItemStatus.inProgress,
          detail: 'git status',
        ),
      );

      expect(state.activeTurn, isNotNull);
      expect(state.activeTurn?.turnId, 'turn_123');
      expect(state.activeTurn?.threadId, 'thread_123');
      expect(state.activeTurn?.timer.turnId, 'turn_123');
      expect(state.activeTurn?.hasReasoning, isTrue);
      expect(state.activeTurn?.hasWork, isTrue);
      expect(state.activeTurn?.artifacts, hasLength(2));
      expect(state.activeTurn?.artifacts.first, isA<CodexTurnTextArtifact>());
      expect(state.activeTurn?.artifacts.last, isA<CodexTurnWorkArtifact>());
    },
  );

  test('groups consecutive work-log entries in one live work artifact', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemStartedEvent(
        createdAt: now,
        itemType: CodexCanonicalItemType.commandExecution,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_command',
        status: CodexRuntimeItemStatus.inProgress,
        detail: 'git status',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: now,
        itemType: CodexCanonicalItemType.commandExecution,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_command',
        status: CodexRuntimeItemStatus.completed,
        snapshot: const <String, Object?>{
          'result': <String, Object?>{'output': 'On branch main'},
          'exitCode': 0,
        },
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemStartedEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        itemType: CodexCanonicalItemType.webSearch,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_search',
        status: CodexRuntimeItemStatus.completed,
        detail: 'Search docs',
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.activeTurn?.artifacts, hasLength(1));
    final artifact =
        state.activeTurn!.artifacts.single as CodexTurnWorkArtifact;
    expect(artifact.entries, hasLength(2));
    expect(artifact.entries.first.title, 'git status');
    expect(artifact.entries.last.entryKind, CodexWorkLogEntryKind.webSearch);
    expect(state.transcriptBlocks, hasLength(1));
    final group = state.transcriptBlocks.single as CodexWorkLogGroupBlock;
    expect(group.entries, hasLength(2));
    expect(group.entries.first.title, 'git status');
    expect(group.entries.last.entryKind, CodexWorkLogEntryKind.webSearch);
  });

  test(
    'starts a new work group when a resolved request interrupts work history',
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
        CodexRuntimeItemCompletedEvent(
          createdAt: now,
          itemType: CodexCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_command_1',
          status: CodexRuntimeItemStatus.completed,
          detail: 'git status',
          snapshot: const <String, Object?>{
            'result': <String, Object?>{'output': 'clean'},
            'exitCode': 0,
          },
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeRequestOpenedEvent(
          createdAt: now.add(const Duration(milliseconds: 100)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_command_1',
          requestId: 'approval_1',
          requestType: CodexCanonicalRequestType.fileChangeApproval,
          detail: 'Write files',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeRequestResolvedEvent(
          createdAt: now.add(const Duration(milliseconds: 200)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_command_1',
          requestId: 'approval_1',
          requestType: CodexCanonicalRequestType.fileChangeApproval,
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 300)),
          itemType: CodexCanonicalItemType.webSearch,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_search_2',
          status: CodexRuntimeItemStatus.completed,
          detail: 'Search docs',
        ),
      );

      expect(state.activeTurn?.artifacts, hasLength(3));
      expect(state.activeTurn?.artifacts.first, isA<CodexTurnWorkArtifact>());
      expect(state.activeTurn?.artifacts[1], isA<CodexTurnBlockArtifact>());
      expect(state.activeTurn?.artifacts.last, isA<CodexTurnWorkArtifact>());

      final firstWork =
          state.activeTurn!.artifacts.first as CodexTurnWorkArtifact;
      final resolvedRequestBlock =
          (state.activeTurn!.artifacts[1] as CodexTurnBlockArtifact).block
              as CodexApprovalRequestBlock;
      final resumedWork =
          state.activeTurn!.artifacts.last as CodexTurnWorkArtifact;

      expect(firstWork.entries, hasLength(1));
      expect(firstWork.entries.single.title, 'git status');
      expect(firstWork.entries.single.isRunning, isFalse);
      expect(resolvedRequestBlock.isResolved, isTrue);
      expect(resolvedRequestBlock.title, 'File change approval resolved');
      expect(resumedWork.entries, hasLength(1));
      expect(
        resumedWork.entries.single.entryKind,
        CodexWorkLogEntryKind.webSearch,
      );

      expect(state.transcriptBlocks, hasLength(3));
      expect(state.transcriptBlocks.first, isA<CodexWorkLogGroupBlock>());
      expect(state.transcriptBlocks[1], isA<CodexApprovalRequestBlock>());
      expect(state.transcriptBlocks.last, isA<CodexWorkLogGroupBlock>());
    },
  );

  test('keeps turn diff snapshots out of visible transcript history', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeContentDeltaEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'plan_1',
        streamKind: CodexRuntimeContentStreamKind.planText,
        delta: '# Ship it\n\n- add widgets',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnDiffUpdatedEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        unifiedDiff:
            'diff --git a/lib/main.dart b/lib/main.dart\n'
            '--- a/lib/main.dart\n'
            '+++ b/lib/main.dart\n'
            '@@ -1 +1 @@\n'
            '-old\n'
            '+new\n',
      ),
    );

    expect(state.blocks, isEmpty);
    expect(state.transcriptBlocks, hasLength(1));
    expect(state.transcriptBlocks.single, isA<CodexProposedPlanBlock>());
    expect(state.activeTurn?.turnDiffSnapshot, isNotNull);
    expect(
      state.activeTurn?.turnDiffSnapshot?.unifiedDiff,
      contains('diff --git a/lib/main.dart b/lib/main.dart'),
    );
  });

  test(
    'replaces the active turn diff snapshot when repeated updates arrive',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        CodexSessionState.initial(),
        CodexRuntimeTurnStartedEvent(
          createdAt: now,
          threadId: 'thread_123',
          turnId: 'turn_123',
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeTurnDiffUpdatedEvent(
          createdAt: now.add(const Duration(milliseconds: 100)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          unifiedDiff:
              'diff --git a/README.md b/README.md\n'
              '--- a/README.md\n'
              '+++ b/README.md\n'
              '@@ -1 +1 @@\n'
              '-old\n'
              '+new\n',
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeTurnDiffUpdatedEvent(
          createdAt: now.add(const Duration(milliseconds: 200)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          unifiedDiff:
              'diff --git a/README.md b/README.md\n'
              '--- a/README.md\n'
              '+++ b/README.md\n'
              '@@ -1 +1,2 @@\n'
              '-old\n'
              '+new\n'
              '+second\n',
        ),
      );

      expect(state.blocks, isEmpty);
      expect(state.transcriptBlocks, isEmpty);
      expect(
        state.activeTurn?.turnDiffSnapshot?.createdAt,
        now.add(const Duration(milliseconds: 200)),
      );
      expect(
        state.activeTurn?.turnDiffSnapshot?.unifiedDiff,
        contains('+second'),
      );
    },
  );

  test(
    'ignores mismatched turn diff snapshots instead of rolling back turns',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        CodexSessionState.initial(),
        CodexRuntimeTurnStartedEvent(
          createdAt: now,
          threadId: 'thread_123',
          turnId: 'turn_456',
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 50)),
          threadId: 'thread_123',
          turnId: 'turn_456',
          itemId: 'item_456',
          streamKind: CodexRuntimeContentStreamKind.assistantText,
          delta: 'Current turn',
        ),
      );

      final baselineBlocks = List<CodexUiBlock>.from(state.blocks);
      final baselineArtifacts = List<CodexTurnArtifact>.from(
        state.activeTurn?.artifacts ?? const <CodexTurnArtifact>[],
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeTurnDiffUpdatedEvent(
          createdAt: now.add(const Duration(seconds: 1)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          unifiedDiff:
              'diff --git a/README.md b/README.md\n'
              '--- a/README.md\n'
              '+++ b/README.md\n'
              '@@ -1 +1 @@\n'
              '-old\n'
              '+new\n',
        ),
      );

      expect(state.activeTurn?.turnId, 'turn_456');
      expect(state.activeTurn?.artifacts, baselineArtifacts);
      expect(state.activeTurn?.turnDiffSnapshot, isNull);
      expect(state.blocks, baselineBlocks);
      expect(state.transcriptBlocks.last, isA<CodexTextBlock>());
      expect(
        (state.transcriptBlocks.last as CodexTextBlock).body,
        'Current turn',
      );
    },
  );

  test('renders a multi-file file-change item as one changed-files block', () {
    final reducer = TranscriptReducer();
    final now = DateTime(2026, 3, 14, 12);

    final state = reducer.reduceRuntimeEvent(
      CodexSessionState.initial(),
      CodexRuntimeItemCompletedEvent(
        createdAt: now,
        itemType: CodexCanonicalItemType.fileChange,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'file_change_1',
        status: CodexRuntimeItemStatus.completed,
        snapshot: const <String, Object?>{
          'changes': <Object?>[
            <String, Object?>{
              'path': 'README.md',
              'kind': <String, Object?>{'type': 'add'},
              'diff': 'first line\nsecond line\n',
            },
            <String, Object?>{
              'path': 'lib/app.dart',
              'kind': <String, Object?>{'type': 'update', 'move_path': null},
              'diff':
                  '--- a/lib/app.dart\n'
                  '+++ b/lib/app.dart\n'
                  '@@ -1 +1,2 @@\n'
                  '-old\n'
                  '+new\n'
                  '+second\n',
            },
          ],
        },
      ),
    );

    expect(state.transcriptBlocks, hasLength(1));
    final changedFiles =
        state.transcriptBlocks.single as CodexChangedFilesBlock;
    expect(changedFiles.files, hasLength(2));
    expect(changedFiles.files.first.path, 'README.md');
    expect(changedFiles.files.first.additions, 2);
    expect(changedFiles.files.last.path, 'lib/app.dart');
    expect(changedFiles.files.last.additions, 2);
    expect(changedFiles.files.last.deletions, 1);
    expect(
      changedFiles.unifiedDiff,
      contains('diff --git a/README.md b/README.md'),
    );
    expect(
      changedFiles.unifiedDiff,
      contains('diff --git a/lib/app.dart b/lib/app.dart'),
    );
  });

  test(
    'starts a new changed-files card when the same file-change item resumes after an intervening warning',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        CodexSessionState.initial(),
        CodexRuntimeItemStartedEvent(
          createdAt: now,
          itemType: CodexCanonicalItemType.fileChange,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_1',
          status: CodexRuntimeItemStatus.inProgress,
          snapshot: const <String, Object?>{
            'changes': <Object?>[
              <String, Object?>{
                'path': 'README.md',
                'kind': <String, Object?>{'type': 'add'},
                'diff': 'first line\n',
              },
            ],
          },
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
        CodexRuntimeItemUpdatedEvent(
          createdAt: now.add(const Duration(milliseconds: 2)),
          itemType: CodexCanonicalItemType.fileChange,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_1',
          status: CodexRuntimeItemStatus.inProgress,
          snapshot: const <String, Object?>{
            'changes': <Object?>[
              <String, Object?>{
                'path': 'README.md',
                'kind': <String, Object?>{'type': 'add'},
                'diff': 'first line\n',
              },
              <String, Object?>{
                'path': 'lib/app.dart',
                'kind': <String, Object?>{'type': 'update'},
                'diff':
                    '--- a/lib/app.dart\n'
                    '+++ b/lib/app.dart\n'
                    '@@ -1 +1 @@\n'
                    '-old\n'
                    '+new\n',
              },
            ],
          },
        ),
      );

      final changedFilesBlocks = state.transcriptBlocks
          .whereType<CodexChangedFilesBlock>()
          .toList(growable: false);
      expect(changedFilesBlocks, hasLength(2));
      expect(changedFilesBlocks.first.files.single.path, 'README.md');
      expect(changedFilesBlocks.first.isRunning, isFalse);
      expect(changedFilesBlocks.last.files, hasLength(2));
      expect(changedFilesBlocks.last.files.first.path, 'README.md');
      expect(changedFilesBlocks.last.files.last.path, 'lib/app.dart');
      expect(changedFilesBlocks.last.isRunning, isTrue);
    },
  );

  test(
    'keeps the structured diff when file-change output deltas contain plain text',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        CodexSessionState.initial(),
        CodexRuntimeItemStartedEvent(
          createdAt: now,
          itemType: CodexCanonicalItemType.fileChange,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_1',
          status: CodexRuntimeItemStatus.inProgress,
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 100)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_1',
          streamKind: CodexRuntimeContentStreamKind.fileChangeOutput,
          delta: 'apply_patch exited successfully',
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(seconds: 1)),
          itemType: CodexCanonicalItemType.fileChange,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_1',
          status: CodexRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{
            'changes': <Object?>[
              <String, Object?>{
                'path': 'README.md',
                'kind': <String, Object?>{'type': 'add'},
                'diff': 'first line\nsecond line\n',
              },
            ],
          },
        ),
      );

      expect(state.transcriptBlocks, hasLength(1));
      final changedFiles =
          state.transcriptBlocks.single as CodexChangedFilesBlock;
      expect(changedFiles.files, hasLength(1));
      expect(changedFiles.files.single.path, 'README.md');
      expect(
        changedFiles.unifiedDiff,
        contains('diff --git a/README.md b/README.md'),
      );
      expect(changedFiles.unifiedDiff, contains('+first line'));
    },
  );

  test(
    'keeps file-change history immutable when turn diff snapshots arrive',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        CodexSessionState.initial(),
        CodexRuntimeItemCompletedEvent(
          createdAt: now,
          itemType: CodexCanonicalItemType.fileChange,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_1',
          status: CodexRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{
            'changes': <Object?>[
              <String, Object?>{
                'path': 'README.md',
                'kind': <String, Object?>{'type': 'add'},
                'diff': 'first line\n',
              },
            ],
          },
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeTurnDiffUpdatedEvent(
          createdAt: now.add(const Duration(seconds: 1)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          unifiedDiff:
              'diff --git a/README.md b/README.md\n'
              'new file mode 100644\n'
              '--- /dev/null\n'
              '+++ b/README.md\n'
              '@@ -0,0 +1,2 @@\n'
              '+first line\n'
              '+second line\n',
        ),
      );

      final changedFilesBlocks = state.transcriptBlocks
          .whereType<CodexChangedFilesBlock>()
          .toList(growable: false);
      expect(changedFilesBlocks, hasLength(1));
      expect(changedFilesBlocks.single.files.single.path, 'README.md');
      expect(changedFilesBlocks.single.files.single.additions, 1);
      expect(changedFilesBlocks.single.unifiedDiff, contains('+first line'));
      expect(
        changedFilesBlocks.single.unifiedDiff,
        isNot(contains('+second line')),
      );
      expect(state.activeTurn?.turnDiffSnapshot, isNotNull);
      expect(
        state.activeTurn?.turnDiffSnapshot?.unifiedDiff,
        contains('+second line'),
      );
    },
  );

  test(
    'keeps a running file-change item visible when turn diff snapshots update',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        CodexSessionState.initial(),
        CodexRuntimeItemStartedEvent(
          createdAt: now,
          itemType: CodexCanonicalItemType.fileChange,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_1',
          status: CodexRuntimeItemStatus.inProgress,
          snapshot: const <String, Object?>{
            'changes': <Object?>[
              <String, Object?>{
                'path': 'README.md',
                'kind': <String, Object?>{'type': 'add'},
                'diff': 'first line\n',
              },
            ],
          },
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeTurnDiffUpdatedEvent(
          createdAt: now.add(const Duration(seconds: 1)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          unifiedDiff:
              'diff --git a/README.md b/README.md\n'
              'new file mode 100644\n'
              '--- /dev/null\n'
              '+++ b/README.md\n'
              '@@ -0,0 +1,2 @@\n'
              '+first line\n'
              '+second line\n',
        ),
      );

      final changedFilesBlocks = state.transcriptBlocks
          .whereType<CodexChangedFilesBlock>()
          .toList(growable: false);
      expect(changedFilesBlocks, hasLength(1));
      expect(changedFilesBlocks.single.isRunning, isTrue);
      expect(state.activeTurn?.turnDiffSnapshot, isNotNull);
      expect(
        state.activeTurn?.turnDiffSnapshot?.unifiedDiff,
        contains('+second line'),
      );
    },
  );

  test('appends repeated plan updates for the same turn', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnPlanUpdatedEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        explanation: 'Starting with the initial structure.',
        steps: const <CodexRuntimePlanStep>[
          CodexRuntimePlanStep(
            step: 'Inspect transcript ownership',
            status: CodexRuntimePlanStepStatus.inProgress,
          ),
        ],
      ),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnPlanUpdatedEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        explanation: 'Refining after reading the reducer.',
        steps: const <CodexRuntimePlanStep>[
          CodexRuntimePlanStep(
            step: 'Inspect transcript ownership',
            status: CodexRuntimePlanStepStatus.completed,
          ),
          CodexRuntimePlanStep(
            step: 'Append visible plan updates',
            status: CodexRuntimePlanStepStatus.inProgress,
          ),
        ],
      ),
    );

    final plans = state.transcriptBlocks
        .whereType<CodexPlanUpdateBlock>()
        .toList(growable: false);

    expect(plans, hasLength(2));
    expect(plans.first.id, isNot(plans.last.id));
    expect(plans.first.explanation, 'Starting with the initial structure.');
    expect(plans.first.steps.single.step, 'Inspect transcript ownership');
    expect(plans.last.explanation, 'Refining after reading the reducer.');
    expect(plans.last.steps, hasLength(2));
    expect(plans.last.steps.first.status, CodexRuntimePlanStepStatus.completed);
    expect(plans.last.steps.last.step, 'Append visible plan updates');
  });

  test(
    'keeps committed history ahead of the live tail instead of resorting by time',
    () {
      final reducer = TranscriptReducer();
      final startedAt = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        CodexSessionState.initial(),
        CodexRuntimeContentDeltaEvent(
          createdAt: startedAt,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          streamKind: CodexRuntimeContentStreamKind.assistantText,
          delta: 'Earlier live row',
        ),
      );

      state = reducer.addUserMessage(
        state,
        text: 'Later committed row',
        createdAt: startedAt.add(const Duration(seconds: 1)),
      );

      expect(state.transcriptBlocks, hasLength(2));
      expect(state.transcriptBlocks.first, isA<CodexUserMessageBlock>());
      expect(
        (state.transcriptBlocks.first as CodexUserMessageBlock).text,
        'Later committed row',
      );
      expect(state.transcriptBlocks.last, isA<CodexTextBlock>());
      expect(
        (state.transcriptBlocks.last as CodexTextBlock).body,
        'Earlier live row',
      );
    },
  );
}
