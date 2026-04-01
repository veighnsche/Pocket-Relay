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

  test('appends repeated plan updates for the same turn', () {
    final reducer = TranscriptReducer();
    var state = TranscriptSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeTurnPlanUpdatedEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        explanation: 'Starting with the initial structure.',
        steps: const <TranscriptRuntimePlanStep>[
          TranscriptRuntimePlanStep(
            step: 'Inspect transcript ownership',
            status: TranscriptRuntimePlanStepStatus.inProgress,
          ),
        ],
      ),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeTurnPlanUpdatedEvent(
        createdAt: now.add(const Duration(seconds: 1)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        explanation: 'Refining after reading the reducer.',
        steps: const <TranscriptRuntimePlanStep>[
          TranscriptRuntimePlanStep(
            step: 'Inspect transcript ownership',
            status: TranscriptRuntimePlanStepStatus.completed,
          ),
          TranscriptRuntimePlanStep(
            step: 'Append visible plan updates',
            status: TranscriptRuntimePlanStepStatus.inProgress,
          ),
        ],
      ),
    );

    final plans = state.transcriptBlocks
        .whereType<TranscriptPlanUpdateBlock>()
        .toList(growable: false);

    expect(plans, hasLength(2));
    expect(plans.first.id, isNot(plans.last.id));
    expect(plans.first.explanation, 'Starting with the initial structure.');
    expect(plans.first.steps.single.step, 'Inspect transcript ownership');
    expect(plans.last.explanation, 'Refining after reading the reducer.');
    expect(plans.last.steps, hasLength(2));
    expect(
      plans.last.steps.first.status,
      TranscriptRuntimePlanStepStatus.completed,
    );
    expect(plans.last.steps.last.step, 'Append visible plan updates');
  });

  test(
    'keeps committed history ahead of the live tail instead of resorting by time',
    () {
      final reducer = TranscriptReducer();
      final startedAt = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        TranscriptSessionState.initial(),
        TranscriptRuntimeContentDeltaEvent(
          createdAt: startedAt,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          streamKind: TranscriptRuntimeContentStreamKind.assistantText,
          delta: 'Earlier live row',
        ),
      );

      state = reducer.addUserMessage(
        state,
        text: 'Later committed row',
        createdAt: startedAt.add(const Duration(seconds: 1)),
      );

      expect(state.transcriptBlocks, hasLength(2));
      expect(state.transcriptBlocks.first, isA<TranscriptUserMessageBlock>());
      expect(
        (state.transcriptBlocks.first as TranscriptUserMessageBlock).text,
        'Later committed row',
      );
      expect(state.transcriptBlocks.last, isA<TranscriptTextBlock>());
      expect(
        (state.transcriptBlocks.last as TranscriptTextBlock).body,
        'Earlier live row',
      );
    },
  );

  test('stores thread names in the workspace registry', () {
    final reducer = TranscriptReducer();
    final state = reducer.reduceRuntimeEvent(
      TranscriptSessionState.initial(),
      TranscriptRuntimeThreadStartedEvent(
        createdAt: DateTime(2026, 3, 14, 12),
        threadId: 'thread_child',
        providerThreadId: 'thread_child',
        threadName: 'Review Branch',
      ),
    );

    expect(state.threadRegistry['thread_child']?.threadName, 'Review Branch');
  });

  test('wait completion releases the parent timeline from waitingOnChild', () {
    final reducer = TranscriptReducer();
    final now = DateTime(2026, 3, 14, 12);
    final waitCall = const TranscriptRuntimeCollabAgentToolCall(
      tool: TranscriptRuntimeCollabAgentTool.wait,
      status: TranscriptRuntimeCollabAgentToolCallStatus.inProgress,
      senderThreadId: 'thread_root',
      receiverThreadIds: <String>['thread_child'],
    );
    final completedWaitCall = const TranscriptRuntimeCollabAgentToolCall(
      tool: TranscriptRuntimeCollabAgentTool.wait,
      status: TranscriptRuntimeCollabAgentToolCallStatus.completed,
      senderThreadId: 'thread_root',
      receiverThreadIds: <String>['thread_child'],
    );

    var state = reducer.reduceRuntimeEvent(
      TranscriptSessionState.initial(),
      TranscriptRuntimeThreadStartedEvent(
        createdAt: now,
        threadId: 'thread_root',
        providerThreadId: 'thread_root',
      ),
    );
    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeTurnStartedEvent(
        createdAt: now.add(const Duration(milliseconds: 1)),
        threadId: 'thread_root',
        turnId: 'turn_root_1',
      ),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeItemStartedEvent(
        createdAt: now.add(const Duration(milliseconds: 2)),
        itemType: TranscriptCanonicalItemType.collabAgentToolCall,
        threadId: 'thread_root',
        turnId: 'turn_root_1',
        itemId: 'wait_1',
        status: TranscriptRuntimeItemStatus.inProgress,
        collaboration: waitCall,
      ),
    );

    expect(
      state.timelineForThread('thread_root')?.lifecycleState,
      TranscriptAgentLifecycleState.waitingOnChild,
    );

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeItemCompletedEvent(
        createdAt: now.add(const Duration(milliseconds: 3)),
        itemType: TranscriptCanonicalItemType.collabAgentToolCall,
        threadId: 'thread_root',
        turnId: 'turn_root_1',
        itemId: 'wait_1',
        status: TranscriptRuntimeItemStatus.completed,
        collaboration: completedWaitCall,
      ),
    );

    expect(
      state.timelineForThread('thread_root')?.lifecycleState,
      TranscriptAgentLifecycleState.running,
    );
  });
}
