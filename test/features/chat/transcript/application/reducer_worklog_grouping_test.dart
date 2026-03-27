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

  test('normalizes shell-wrapped command titles in work-log entries', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: now,
        itemType: CodexCanonicalItemType.commandExecution,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_command',
        status: CodexRuntimeItemStatus.completed,
        detail: '/usr/bin/zsh -lc "sed -n \'1,40p\' lib/main.dart"',
        snapshot: const <String, Object?>{
          'result': <String, Object?>{'output': 'class App {}'},
          'exitCode': 0,
        },
      ),
    );

    final group = state.transcriptBlocks.single as CodexWorkLogGroupBlock;
    expect(group.entries.single.title, "sed -n '1,40p' lib/main.dart");
  });

  test('normalizes PowerShell-wrapped command titles in work-log entries', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: now,
        itemType: CodexCanonicalItemType.commandExecution,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_command_pwsh',
        status: CodexRuntimeItemStatus.completed,
        detail:
            r'powershell.exe -NoLogo -NoProfile -Command "Get-Content -Path C:\repo\README.md -TotalCount 25"',
        snapshot: const <String, Object?>{
          'result': <String, Object?>{'output': 'Pocket Relay'},
          'exitCode': 0,
        },
      ),
    );

    final group = state.transcriptBlocks.single as CodexWorkLogGroupBlock;
    expect(
      group.entries.single.title,
      r'Get-Content -Path C:\repo\README.md -TotalCount 25',
    );
  });

  test('normalizes shell-wrapped rg titles in work-log entries', () {
    final reducer = TranscriptReducer();
    var state = CodexSessionState.initial();
    final now = DateTime(2026, 3, 14, 12);

    state = reducer.reduceRuntimeEvent(
      state,
      CodexRuntimeItemCompletedEvent(
        createdAt: now,
        itemType: CodexCanonicalItemType.commandExecution,
        threadId: 'thread_123',
        turnId: 'turn_123',
        itemId: 'item_command_rg',
        status: CodexRuntimeItemStatus.completed,
        detail: '/usr/bin/zsh -lc "rg -n \\"Pocket Relay\\" lib test"',
        snapshot: const <String, Object?>{
          'result': <String, Object?>{'output': 'lib/main.dart:1:Pocket Relay'},
          'exitCode': 0,
        },
      ),
    );

    final group = state.transcriptBlocks.single as CodexWorkLogGroupBlock;
    expect(group.entries.single.title, 'rg -n "Pocket Relay" lib test');
  });

  test(
    'normalizes PowerShell-wrapped Select-String titles in work-log entries',
    () {
      final reducer = TranscriptReducer();
      var state = CodexSessionState.initial();
      final now = DateTime(2026, 3, 14, 12);

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemCompletedEvent(
          createdAt: now,
          itemType: CodexCanonicalItemType.commandExecution,
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'item_command_select_string',
          status: CodexRuntimeItemStatus.completed,
          detail:
              r'powershell.exe -NoLogo -NoProfile -Command "Select-String -Path C:\repo\README.md -Pattern \"Pocket Relay\""',
          snapshot: const <String, Object?>{
            'result': <String, Object?>{'output': 'README.md:1:Pocket Relay'},
            'exitCode': 0,
          },
        ),
      );

      final group = state.transcriptBlocks.single as CodexWorkLogGroupBlock;
      expect(
        group.entries.single.title,
        r'Select-String -Path C:\repo\README.md -Pattern "Pocket Relay"',
      );
    },
  );

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
}
