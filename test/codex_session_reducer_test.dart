import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/services/codex_session_reducer.dart';

void main() {
  test(
    'creates and updates assistant entries from lifecycle and delta events',
    () {
      final reducer = CodexSessionReducer();
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

  test('opens and resolves approval requests', () {
    final reducer = CodexSessionReducer();
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
    final reducer = CodexSessionReducer();
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
    final reducer = CodexSessionReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

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
    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeTurnCompletedEvent(
        createdAt: now,
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
    expect(state.blocks.last, isA<CodexUsageBlock>());
  });

  test('keeps warnings and errors non-fatal to the UI state', () {
    final reducer = CodexSessionReducer();
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
}
