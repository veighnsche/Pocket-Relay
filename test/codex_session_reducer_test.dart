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
      expect(state.activeItems, isEmpty);
      expect(state.blocks, hasLength(1));
      final block = state.blocks.single as CodexTextBlock;
      expect(block.kind, CodexUiBlockKind.assistantMessage);
      expect(block.body, 'Hello, world');
      expect(block.isRunning, isFalse);
    },
  );

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

    expect(state.blocks.single, isA<CodexUserMessageBlock>());
    final block = state.blocks.single as CodexUserMessageBlock;
    expect(block.text, 'Ship the fix');
  });

  test('dedupes app-server user-message echoes against the local prompt', () {
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
        itemId: 'item_user',
        status: CodexRuntimeItemStatus.completed,
        snapshot: const <String, Object?>{'text': 'Ship the fix'},
      ),
    );

    expect(state.blocks, hasLength(1));
    expect(state.blocks.single, isA<CodexUserMessageBlock>());
    expect((state.blocks.single as CodexUserMessageBlock).text, 'Ship the fix');
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

    final block = state.blocks.single as CodexTextBlock;
    expect(block.body, 'The shell session');
    expect(block.isRunning, isTrue);
  });

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

    expect(state.blocks, hasLength(2));
    expect(state.blocks.first, isA<CodexStatusBlock>());
    expect(state.blocks.last, isA<CodexStatusBlock>());
    expect(
      (state.blocks.first as CodexStatusBlock).body,
      'Checking the patch set',
    );
    expect(
      (state.blocks.last as CodexStatusBlock).body,
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

    expect(state.blocks, isEmpty);

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

    expect(state.blocks.single, isA<CodexTextBlock>());
    final block = state.blocks.single as CodexTextBlock;
    expect(block.kind, CodexUiBlockKind.reasoning);
    expect(block.body, 'Inspecting the environment.');
  });

  test('opens and resolves approval requests', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

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
    final requestBlock = state.blocks.single as CodexApprovalRequestBlock;
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
    final resolvedBlock = state.blocks.single as CodexApprovalRequestBlock;
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
    final inputBlock = state.blocks.single as CodexUserInputRequestBlock;
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
    final submittedBlock = state.blocks.single as CodexUserInputRequestBlock;
    expect(submittedBlock.title, 'Input submitted');
    expect(submittedBlock.body, contains('Vince'));
    expect(submittedBlock.isResolved, isTrue);
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
    expect(state.turnId, isNull);
    expect(state.latestUsageSummary, 'input 12 · cached 3 · output 7');
    expect(state.turnTimers['turn_123']?.startedAt, now);
    expect(
      state.turnTimers['turn_123']?.elapsedAt(completedAt),
      const Duration(seconds: 5),
    );
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

    expect(state.turnId, isNull);
    expect(
      state.turnTimers['turn_123']?.elapsedAt(exitedAt),
      const Duration(seconds: 9),
    );
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

      final timer = state.turnTimers['turn_123'];
      expect(timer?.elapsedAt(completedAt), const Duration(seconds: 5));
      expect(
        (state.blocks.single as CodexTurnBoundaryBlock).elapsed,
        const Duration(seconds: 5),
      );
    },
  );

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

      expect(state.turnTimers['turn_123']?.isPaused, isTrue);
      expect(
        state.turnTimers['turn_123']?.elapsedAt(
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

      expect(state.turnTimers['turn_123']?.isPaused, isFalse);

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
        state.turnTimers['turn_123']?.elapsedAt(startedAt),
        const Duration(seconds: 9),
      );
      expect(
        (state.blocks.last as CodexTurnBoundaryBlock).elapsed,
        const Duration(seconds: 9),
      );
    },
  );

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
    expect(state.pendingThreadTokenUsageBlock, isNotNull);

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
    expect(state.pendingThreadTokenUsageBlock, isNotNull);

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

    expect(state.pendingThreadTokenUsageBlock, isNull);
    expect(state.blocks.whereType<CodexUsageBlock>(), hasLength(1));
    expect((state.blocks.first as CodexUsageBlock).title, 'Thread token usage');
    expect((state.blocks.first as CodexUsageBlock).body, contains('input 24'));
    expect(state.blocks.last, isA<CodexTurnBoundaryBlock>());
  });

  test('groups consecutive work-log entries in transcript blocks', () {
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

    expect(state.blocks.whereType<CodexWorkLogEntryBlock>(), hasLength(2));
    expect(state.transcriptBlocks, hasLength(1));
    final group = state.transcriptBlocks.single as CodexWorkLogGroupBlock;
    expect(group.entries, hasLength(2));
    expect(group.entries.first.title, 'git status');
    expect(group.entries.last.entryKind, CodexWorkLogEntryKind.webSearch);
  });

  test('renders proposed plan and changed files as dedicated blocks', () {
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

    expect(state.blocks.first, isA<CodexProposedPlanBlock>());
    final changedFiles = state.blocks.last as CodexChangedFilesBlock;
    expect(changedFiles.files.single.path, 'lib/main.dart');
    expect(changedFiles.unifiedDiff, contains('diff --git'));
  });
}
