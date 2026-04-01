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
    'freezes a command work section before approval and resumes updates in the same section after resolution',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        TranscriptSessionState.initial(),
        TranscriptRuntimeItemStartedEvent(
          createdAt: now,
          itemType: TranscriptCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_1',
          status: TranscriptRuntimeItemStatus.inProgress,
          detail: 'git status',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_1',
          streamKind: TranscriptRuntimeContentStreamKind.commandOutput,
          delta: 'clean',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 20)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_1',
          streamKind: TranscriptRuntimeContentStreamKind.assistantText,
          delta: 'Waiting',
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeRequestOpenedEvent(
          createdAt: now.add(const Duration(milliseconds: 30)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_1',
          requestId: 'approval_1',
          requestType: TranscriptCanonicalRequestType.fileChangeApproval,
          detail: 'Write files',
        ),
      );

      var blocks = state.transcriptBlocks;
      final frozenWork = blocks.first as TranscriptWorkLogGroupBlock;
      final frozenAssistant = blocks.last as TranscriptTextBlock;
      expect(frozenWork.entries.single.isRunning, isFalse);
      expect(frozenAssistant.isRunning, isFalse);

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeRequestResolvedEvent(
          createdAt: now.add(const Duration(milliseconds: 40)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_1',
          requestId: 'approval_1',
          requestType: TranscriptCanonicalRequestType.fileChangeApproval,
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 50)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_1',
          streamKind: TranscriptRuntimeContentStreamKind.commandOutput,
          delta: ' status',
        ),
      );

      blocks = state.transcriptBlocks;
      final workBlocks = blocks.whereType<TranscriptWorkLogGroupBlock>().toList(
        growable: false,
      );
      expect(workBlocks, hasLength(1));
      expect(workBlocks.single.entries.single.preview, 'clean status');
      expect(workBlocks.single.entries.single.isRunning, isTrue);
      expect((blocks[1] as TranscriptTextBlock).body, 'Waiting');
      expect((blocks[1] as TranscriptTextBlock).isRunning, isFalse);
      expect(blocks[2], isA<TranscriptApprovalRequestBlock>());
      expect(
        (blocks[2] as TranscriptApprovalRequestBlock).title,
        'File change approval resolved',
      );
    },
  );

  test(
    'command output clears the background-terminal wait marker when execution resumes',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        TranscriptSessionState.initial(),
        TranscriptRuntimeItemStartedEvent(
          createdAt: now,
          itemType: TranscriptCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_wait_1',
          status: TranscriptRuntimeItemStatus.inProgress,
          detail: 'sleep 5',
          snapshot: const <String, Object?>{'command': 'sleep 5'},
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemUpdatedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          itemType: TranscriptCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_wait_1',
          status: TranscriptRuntimeItemStatus.inProgress,
          rawMethod: 'item/commandExecution/terminalInteraction',
          detail: '',
          snapshot: const <String, Object?>{'processId': 'proc_1', 'stdin': ''},
        ),
      );

      var activeItem = state.activeTurn?.itemsById['command_wait_1'];
      expect(activeItem, isNotNull);
      expect(activeItem?.snapshot?['command'], 'sleep 5');
      expect(activeItem?.snapshot?['stdin'], '');
      expect(activeItem?.snapshot?['processId'], 'proc_1');

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 20)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_wait_1',
          streamKind: TranscriptRuntimeContentStreamKind.commandOutput,
          delta: 'ready',
        ),
      );

      activeItem = state.activeTurn?.itemsById['command_wait_1'];
      expect(activeItem, isNotNull);
      expect(activeItem?.snapshot?['command'], 'sleep 5');
      expect(activeItem?.snapshot?.containsKey('stdin'), isFalse);
      expect(activeItem?.snapshot?['processId'], 'proc_1');
    },
  );

  test('command lifecycle updates replace stale terminal snapshot fields', () {
    final reducer = TranscriptReducer();
    final now = DateTime(2026, 3, 14, 12);
    var state = reducer.reduceRuntimeEvent(
      TranscriptSessionState.initial(),
      TranscriptRuntimeItemStartedEvent(
        createdAt: now,
        itemType: TranscriptCanonicalItemType.commandExecution,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'command_snapshot_1',
        status: TranscriptRuntimeItemStatus.inProgress,
        snapshot: const <String, Object?>{'command': 'git status'},
      ),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeItemUpdatedEvent(
        createdAt: now.add(const Duration(milliseconds: 10)),
        itemType: TranscriptCanonicalItemType.commandExecution,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'command_snapshot_1',
        status: TranscriptRuntimeItemStatus.inProgress,
        rawMethod: 'item/commandExecution/terminalInteraction',
        snapshot: const <String, Object?>{
          'processId': 'proc_1',
          'stdin': 'y\n',
        },
      ),
    );

    state = reducer.reduceRuntimeEvent(
      state,
      TranscriptRuntimeItemUpdatedEvent(
        createdAt: now.add(const Duration(milliseconds: 20)),
        itemType: TranscriptCanonicalItemType.commandExecution,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'command_snapshot_1',
        status: TranscriptRuntimeItemStatus.inProgress,
        snapshot: const <String, Object?>{
          'command': 'git status',
          'processId': 'proc_1',
        },
      ),
    );

    final activeItem = state.activeTurn?.itemsById['command_snapshot_1'];
    expect(activeItem, isNotNull);
    expect(activeItem?.snapshot?['stdin'], isNull);
    expect(activeItem?.snapshot?['processId'], 'proc_1');
    expect(activeItem?.snapshot?['command'], 'git status');
  });

  test(
    'command titles upgrade when later lifecycle events include the command',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        TranscriptSessionState.initial(),
        TranscriptRuntimeItemStartedEvent(
          createdAt: now,
          itemType: TranscriptCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_title_1',
          status: TranscriptRuntimeItemStatus.inProgress,
        ),
      );

      expect(state.activeTurn?.itemsById['command_title_1']?.title, 'Command');

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemUpdatedEvent(
          createdAt: now.add(const Duration(milliseconds: 10)),
          itemType: TranscriptCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_title_1',
          status: TranscriptRuntimeItemStatus.inProgress,
          snapshot: const <String, Object?>{'command': 'pwd'},
        ),
      );

      expect(state.activeTurn?.itemsById['command_title_1']?.title, 'pwd');
    },
  );

  test(
    'keeps assistant and work artifacts in chronological order when they interleave',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        TranscriptSessionState.initial(),
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now,
          itemType: TranscriptCanonicalItemType.assistantMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_1',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'Before work'},
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 100)),
          itemType: TranscriptCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_1',
          status: TranscriptRuntimeItemStatus.completed,
          detail: 'git status',
          snapshot: const <String, Object?>{
            'result': <String, Object?>{'output': 'clean'},
            'exitCode': 0,
          },
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 200)),
          itemType: TranscriptCanonicalItemType.assistantMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_2',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'After work'},
        ),
      );

      expect(state.transcriptBlocks, hasLength(3));
      expect(state.transcriptBlocks.first, isA<TranscriptTextBlock>());
      expect(state.transcriptBlocks[1], isA<TranscriptWorkLogGroupBlock>());
      expect(state.transcriptBlocks.last, isA<TranscriptTextBlock>());
      expect(
        (state.transcriptBlocks.first as TranscriptTextBlock).body,
        'Before work',
      );
      expect(
        (state.transcriptBlocks[1] as TranscriptWorkLogGroupBlock)
            .entries
            .single
            .title,
        'git status',
      );
      expect(
        (state.transcriptBlocks.last as TranscriptTextBlock).body,
        'After work',
      );
    },
  );

  test(
    'consolidates consecutive distinct file-change items into one changed-files artifact',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        TranscriptSessionState.initial(),
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now,
          itemType: TranscriptCanonicalItemType.fileChange,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_1',
          status: TranscriptRuntimeItemStatus.completed,
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
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 100)),
          itemType: TranscriptCanonicalItemType.fileChange,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_2',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{
            'changes': <Object?>[
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
          .whereType<TranscriptChangedFilesBlock>()
          .toList(growable: false);
      expect(changedFilesBlocks, hasLength(1));
      expect(changedFilesBlocks.single.files, hasLength(2));
      expect(changedFilesBlocks.single.files.first.path, 'README.md');
      expect(changedFilesBlocks.single.files.last.path, 'lib/app.dart');
    },
  );

  test(
    'keeps pending approvals off the transcript until resolution and preserves chronology',
    () {
      final reducer = TranscriptReducer();
      final now = DateTime(2026, 3, 14, 12);
      var state = reducer.reduceRuntimeEvent(
        TranscriptSessionState.initial(),
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now,
          itemType: TranscriptCanonicalItemType.assistantMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_before',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'Before request'},
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeRequestOpenedEvent(
          createdAt: now.add(const Duration(milliseconds: 100)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_before',
          requestId: 'approval_1',
          requestType: TranscriptCanonicalRequestType.fileChangeApproval,
          detail: 'Write files',
        ),
      );

      expect(state.transcriptBlocks, hasLength(1));
      expect(state.pendingApprovalRequests, isNotEmpty);
      expect(
        state.pendingApprovalRequests['approval_1']?.requestId,
        'approval_1',
      );

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeRequestResolvedEvent(
          createdAt: now.add(const Duration(milliseconds: 200)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_before',
          requestId: 'approval_1',
          requestType: TranscriptCanonicalRequestType.fileChangeApproval,
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 300)),
          itemType: TranscriptCanonicalItemType.assistantMessage,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_after',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{'text': 'After request'},
        ),
      );

      expect(state.pendingApprovalRequests, isEmpty);
      expect(state.transcriptBlocks, hasLength(3));
      expect(
        (state.transcriptBlocks.first as TranscriptTextBlock).body,
        'Before request',
      );
      expect(state.transcriptBlocks[1], isA<TranscriptApprovalRequestBlock>());
      expect(
        (state.transcriptBlocks[1] as TranscriptApprovalRequestBlock).title,
        'File change approval resolved',
      );
      expect(
        (state.transcriptBlocks.last as TranscriptTextBlock).body,
        'After request',
      );
    },
  );
}
