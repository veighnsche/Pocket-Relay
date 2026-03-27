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
    final pendingRequest = state.pendingApprovalRequests['i:99']!;
    expect(pendingRequest.requestId, 'i:99');
    expect(
      pendingRequest.requestType,
      CodexCanonicalRequestType.fileChangeApproval,
    );
    expect(pendingRequest.detail, 'Write files');

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
    final resolvedBlock =
        state.transcriptBlocks.single as CodexApprovalRequestBlock;
    expect(resolvedBlock.title, 'File change approval resolved');
    expect(resolvedBlock.isResolved, isTrue);
    expect(resolvedBlock.resolutionLabel, 'resolved');
    expect(resolvedBlock.body, contains('Write files'));
  });

  test('derives approval decision labels from resolved approval payloads', () {
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

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeRequestResolvedEvent(
        createdAt: now.add(const Duration(milliseconds: 10)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_123',
        requestId: 'i:99',
        requestType: CodexCanonicalRequestType.fileChangeApproval,
        resolution: const <String, Object?>{'approved': true},
      ),
    );

    final resolvedBlock =
        state.transcriptBlocks.single as CodexApprovalRequestBlock;
    expect(resolvedBlock.title, 'File change approval approved');
    expect(resolvedBlock.resolutionLabel, 'approved');
    expect(
      resolvedBlock.body,
      contains('Codex received approval for this request.'),
    );
  });

  test('freezes a running assistant artifact when an approval opens', () {
    final reducer = TranscriptReducer();
    final now = DateTime(2026, 3, 14, 12);
    var state = reducer.reduceRuntimeEvent(
      CodexSessionState.initial(),
      CodexRuntimeContentDeltaEvent(
        createdAt: now,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'assistant_123',
        streamKind: CodexRuntimeContentStreamKind.assistantText,
        delta: 'Before request',
      ),
    );

    final runningBlockBeforeRequest =
        state.transcriptBlocks.single as CodexTextBlock;
    expect(runningBlockBeforeRequest.isRunning, isTrue);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeRequestOpenedEvent(
        createdAt: now.add(const Duration(milliseconds: 100)),
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'assistant_123',
        requestId: 'approval_1',
        requestType: CodexCanonicalRequestType.fileChangeApproval,
        detail: 'Write files',
      ),
    );

    expect(
      state.pendingApprovalRequests['approval_1']?.requestId,
      'approval_1',
    );
    final frozenBlock = state.transcriptBlocks.single as CodexTextBlock;
    expect(frozenBlock.body, 'Before request');
    expect(frozenBlock.isRunning, isFalse);
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
    final pendingRequest = state.pendingUserInputRequests['s:user-input-1']!;
    expect(pendingRequest.requestId, 's:user-input-1');
    expect(pendingRequest.questions.single.question, 'What is your name?');

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
    final submittedBlock =
        state.transcriptBlocks.single as CodexUserInputRequestBlock;
    expect(submittedBlock.title, 'Input submitted');
    expect(submittedBlock.body, 'Name: Vince');
    expect(submittedBlock.isResolved, isTrue);
  });

  test(
    'freezes a running assistant artifact when user input is requested and forks resumed output after resolution',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        CodexSessionState.initial(),
        CodexRuntimeContentDeltaEvent(
          createdAt: now,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_123',
          streamKind: CodexRuntimeContentStreamKind.assistantText,
          delta: 'Before request',
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeUserInputRequestedEvent(
          createdAt: now.add(const Duration(milliseconds: 100)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_123',
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

      final frozenBeforeInput = state.transcriptBlocks.single as CodexTextBlock;
      expect(frozenBeforeInput.body, 'Before request');
      expect(frozenBeforeInput.isRunning, isFalse);
      expect(
        state.pendingUserInputRequests['s:user-input-1']?.requestId,
        's:user-input-1',
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeUserInputResolvedEvent(
          createdAt: now.add(const Duration(milliseconds: 200)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_123',
          requestId: 's:user-input-1',
          answers: const <String, List<String>>{
            'q1': <String>['Vince'],
          },
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 300)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_123',
          streamKind: CodexRuntimeContentStreamKind.assistantText,
          delta: 'After request',
        ),
      );

      expect(state.transcriptBlocks, hasLength(3));
      final blocks = state.transcriptBlocks;
      expect((blocks[0] as CodexTextBlock).body, 'Before request');
      expect((blocks[0] as CodexTextBlock).isRunning, isFalse);
      expect(blocks[1], isA<CodexUserInputRequestBlock>());
      expect((blocks[2] as CodexTextBlock).body, 'After request');
      expect((blocks[2] as CodexTextBlock).isRunning, isTrue);
    },
  );

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

  test(
    'keeps the richer user-input resolution when a generic resolved event arrives later',
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
        CodexRuntimeUserInputResolvedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          requestId: 's:user-input-1',
          answers: const <String, List<String>>{
            'q1': <String>['Vince'],
          },
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeRequestResolvedEvent(
          createdAt: now.add(const Duration(milliseconds: 20)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_123',
          requestId: 's:user-input-1',
          requestType: CodexCanonicalRequestType.unknown,
        ),
      );

      final resolvedBlocks = state.transcriptBlocks
          .whereType<CodexUserInputRequestBlock>()
          .toList(growable: false);
      expect(resolvedBlocks, hasLength(1));
      expect(resolvedBlocks.single.title, 'Input submitted');
      expect(resolvedBlocks.single.body, contains('Vince'));
      expect(
        state.transcriptBlocks.whereType<CodexApprovalRequestBlock>(),
        isEmpty,
      );
    },
  );
}
