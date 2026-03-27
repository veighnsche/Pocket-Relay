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
    'starts a new changed-files surface when the same file-change item resumes after an intervening warning',
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
      expect(changedFilesBlocks.map((block) => block.id).toSet(), hasLength(2));
      expect(changedFilesBlocks.first.files.single.path, 'README.md');
      expect(changedFilesBlocks.first.isRunning, isFalse);
      expect(changedFilesBlocks.last.files, hasLength(2));
      expect(changedFilesBlocks.last.files.first.path, 'README.md');
      expect(changedFilesBlocks.last.files.last.path, 'lib/app.dart');
      expect(changedFilesBlocks.last.isRunning, isTrue);
    },
  );

  test(
    'starts a new changed-files surface when the same file-change item resumes after an approval request',
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
        CodexRuntimeRequestOpenedEvent(
          createdAt: now.add(const Duration(milliseconds: 1)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_1',
          requestId: 'approval_1',
          requestType: CodexCanonicalRequestType.fileChangeApproval,
          detail: 'Write files',
        ),
      );

      final frozenBeforeApproval =
          state.transcriptBlocks.single as CodexChangedFilesBlock;
      expect(frozenBeforeApproval.files.single.path, 'README.md');
      expect(frozenBeforeApproval.isRunning, isFalse);
      expect(
        state.pendingApprovalRequests['approval_1']?.requestId,
        'approval_1',
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeRequestResolvedEvent(
          createdAt: now.add(const Duration(milliseconds: 2)),
          threadId: 'thread_123',
          turnId: 'turn_123',
          itemId: 'file_change_1',
          requestId: 'approval_1',
          requestType: CodexCanonicalRequestType.fileChangeApproval,
        ),
      );

      state = reducer.reduceRuntimeEvent(
        state,
        CodexRuntimeItemCompletedEvent(
          createdAt: now.add(const Duration(milliseconds: 3)),
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
      expect(changedFilesBlocks.map((block) => block.id).toSet(), hasLength(2));
      expect(changedFilesBlocks.first.files.single.path, 'README.md');
      expect(changedFilesBlocks.first.isRunning, isFalse);
      expect(changedFilesBlocks.last.files, hasLength(2));
      expect(changedFilesBlocks.last.files.first.path, 'README.md');
      expect(changedFilesBlocks.last.files.last.path, 'lib/app.dart');
      expect(changedFilesBlocks.last.isRunning, isFalse);
      expect(state.transcriptBlocks[1], isA<CodexApprovalRequestBlock>());
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
    },
  );
}
