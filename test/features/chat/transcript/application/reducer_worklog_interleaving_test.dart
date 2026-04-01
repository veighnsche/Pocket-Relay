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
    'keeps command output bound to its earlier work section when assistant text takes the tail',
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
          delta: 'Investigating',
        ),
      );

      final boundArtifactId = state.activeTurn!.itemArtifactIds['command_1'];
      final entryId = state.activeTurn!.itemsById['command_1']!.entryId;

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 30)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_1',
          streamKind: TranscriptRuntimeContentStreamKind.commandOutput,
          delta: ' status',
        ),
      );

      expect(state.activeTurn?.artifacts, hasLength(2));
      expect(state.activeTurn?.itemArtifactIds['command_1'], boundArtifactId);
      expect(state.activeTurn?.itemsById['command_1']?.entryId, entryId);

      final blocks = state.transcriptBlocks;
      expect(blocks, hasLength(2));
      final workBlock = blocks.first as TranscriptWorkLogGroupBlock;
      final assistantBlock = blocks.last as TranscriptTextBlock;
      expect(workBlock.entries, hasLength(1));
      expect(workBlock.entries.single.title, 'git status');
      expect(workBlock.entries.single.preview, 'clean status');
      expect(workBlock.entries.single.isRunning, isTrue);
      expect(assistantBlock.body, 'Investigating');
      expect(assistantBlock.isRunning, isTrue);
    },
  );

  test(
    'keeps command completion bound to its earlier work section when assistant text takes the tail',
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
          delta: 'Investigating',
        ),
      );

      final boundArtifactId = state.activeTurn!.itemArtifactIds['command_1'];

      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 30)),
          itemType: TranscriptCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_1',
          status: TranscriptRuntimeItemStatus.completed,
          snapshot: const <String, Object?>{
            'result': <String, Object?>{'output': 'final clean'},
            'exitCode': 0,
          },
        ),
      );

      expect(state.activeTurn?.artifacts, hasLength(2));
      expect(state.activeTurn?.itemArtifactIds['command_1'], boundArtifactId);
      expect(state.activeTurn?.itemsById.containsKey('command_1'), isFalse);

      final blocks = state.transcriptBlocks;
      expect(blocks, hasLength(2));
      final workBlock = blocks.first as TranscriptWorkLogGroupBlock;
      expect(workBlock.entries, hasLength(1));
      expect(workBlock.entries.single.title, 'git status');
      expect(workBlock.entries.single.preview, 'final clean');
      expect(workBlock.entries.single.isRunning, isFalse);
      expect(workBlock.entries.single.exitCode, 0);
      expect((blocks.last as TranscriptTextBlock).body, 'Investigating');
      expect((blocks.last as TranscriptTextBlock).isRunning, isTrue);
    },
  );

  test(
    'keeps multiple command streams updating their shared earlier work section',
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
        TranscriptRuntimeItemStartedEvent(
          createdAt: now.add(const Duration(milliseconds: 20)),
          itemType: TranscriptCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_2',
          status: TranscriptRuntimeItemStatus.inProgress,
          detail: 'pwd',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 30)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_2',
          streamKind: TranscriptRuntimeContentStreamKind.commandOutput,
          delta: '/repo',
        ),
      );
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 40)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'assistant_1',
          streamKind: TranscriptRuntimeContentStreamKind.assistantText,
          delta: 'Investigating',
        ),
      );

      final boundArtifactId = state.activeTurn!.itemArtifactIds['command_1'];
      expect(state.activeTurn?.itemArtifactIds['command_2'], boundArtifactId);

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
      state = reducer.reduceRuntimeEvent(
        state,
        TranscriptRuntimeContentDeltaEvent(
          createdAt: now.add(const Duration(milliseconds: 60)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'command_2',
          streamKind: TranscriptRuntimeContentStreamKind.commandOutput,
          delta: ' ready',
        ),
      );

      expect(state.activeTurn?.artifacts, hasLength(2));
      final blocks = state.transcriptBlocks;
      expect(blocks, hasLength(2));
      final workBlock = blocks.first as TranscriptWorkLogGroupBlock;
      expect(workBlock.entries, hasLength(2));
      expect(workBlock.entries.first.title, 'git status');
      expect(workBlock.entries.first.preview, 'clean status');
      expect(workBlock.entries.last.title, 'pwd');
      expect(workBlock.entries.last.preview, '/repo ready');
      expect((blocks.last as TranscriptTextBlock).body, 'Investigating');
    },
  );
}
