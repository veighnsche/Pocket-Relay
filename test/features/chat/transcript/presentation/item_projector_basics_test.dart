import '../../support/screen_presentation_test_support.dart';

void main() {
  group('ChatTranscriptItemProjector', () {
    const projector = ChatTranscriptItemProjector();

    test('projects work-log groups into work-log group item contracts', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_1',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_1',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'Read docs',
            turnId: 'turn_1',
            preview: 'Found the CLI docs',
            isRunning: true,
            exitCode: 0,
          ),
        ],
      );

      final item = projector.project(groupBlock);

      expect(item, isA<ChatWorkLogGroupItemContract>());
      final groupItem = item as ChatWorkLogGroupItemContract;
      expect(groupItem.id, groupBlock.id);
      expect(groupItem.entries, hasLength(1));
      expect(groupItem.entries.single, isA<ChatGenericWorkLogEntryContract>());
      final entry = groupItem.entries.single as ChatGenericWorkLogEntryContract;
      expect(entry.title, 'Read docs');
      expect(entry.turnId, 'turn_1');
      expect(entry.preview, 'Found the CLI docs');
      expect(entry.isRunning, isTrue);
      expect(entry.exitCode, 0);
    });

    test('projects simple sed read commands into read work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_sed',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_sed',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: "sed -n '1,120p' lib/src/app/pocket_relay_app.dart",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatSedReadWorkLogEntryContract;

      expect(entry.lineStart, 1);
      expect(entry.lineEnd, 120);
      expect(entry.fileName, 'pocket_relay_app.dart');
      expect(entry.filePath, 'lib/src/app/pocket_relay_app.dart');
      expect(entry.summaryLabel, 'Reading lines 1 to 120');
    });

    test('projects web-search items into dedicated web-search entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_web_search',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_web_search',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.webSearch,
            title: 'Search docs',
            preview: 'Found CLI reference and API notes',
            snapshot: const <String, Object?>{'query': 'Pocket Relay CLI'},
          ),
        ],
      );

      final item = projector.project(groupBlock) as ChatWebSearchItemContract;
      final entry = item.entry;

      expect(entry.queryText, 'Pocket Relay CLI');
      expect(entry.resultSummary, 'Found CLI reference and API notes');
      expect(entry.activityLabel, 'Searched');
    });

    test(
      'projects plain command executions into dedicated command entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_command',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_command',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: 'pwd',
              preview: '/repo',
              isRunning: true,
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatExecCommandItemContract;
        final entry = item.entry;

        expect(entry.commandText, 'pwd');
        expect(entry.outputPreview, '/repo');
        expect(entry.activityLabel, 'Running command');
      },
    );
    test(
      'projects empty-stdin terminal interactions into command wait entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_command_wait',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_command_wait',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: 'sleep 5',
              preview: 'still running',
              isRunning: true,
              snapshot: const <String, Object?>{
                'processId': 'proc_1',
                'stdin': '',
              },
            ),
          ],
        );

        final item = projector.project(groupBlock) as ChatExecWaitItemContract;
        final entry = item.entry;

        expect(entry.commandText, 'sleep 5');
        expect(entry.outputPreview, 'still running');
        expect(entry.processId, 'proc_1');
        expect(entry.activityLabel, 'Waiting for background terminal');
      },
    );

    test(
      'keeps resumed background-terminal commands in the command execution family',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_command_wait_resumed',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_command_wait_resumed',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: 'sleep 5',
              preview: 'ready',
              isRunning: true,
              snapshot: const <String, Object?>{
                'command': 'sleep 5',
                'processId': 'proc_1',
              },
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatExecCommandItemContract;
        final entry = item.entry;

        expect(entry.commandText, 'sleep 5');
        expect(entry.outputPreview, 'ready');
        expect(entry.activityLabel, 'Running command');
      },
    );

    test('projects review status blocks into dedicated review items', () {
      final item = projector.project(
        CodexStatusBlock(
          id: 'status_review',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Review started',
          body: 'Checking the patch set',
          statusKind: CodexStatusBlockKind.review,
        ),
      );

      expect(item, isA<ChatReviewStatusItemContract>());
    });

    test(
      'projects compaction status blocks into dedicated context-compacted items',
      () {
        final item = projector.project(
          CodexStatusBlock(
            id: 'status_compaction',
            createdAt: DateTime(2026, 3, 15, 12),
            title: 'Context compacted',
            body: 'Codex compacted the current thread context.',
            statusKind: CodexStatusBlockKind.compaction,
          ),
        );

        expect(item, isA<ChatContextCompactedItemContract>());
      },
    );

    test('projects info status blocks into dedicated session-info items', () {
      final item = projector.project(
        CodexStatusBlock(
          id: 'status_info',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'New thread',
          body: 'Resume the previous task.',
          statusKind: CodexStatusBlockKind.info,
          isTranscriptSignal: true,
        ),
      );

      expect(item, isA<ChatSessionInfoItemContract>());
    });

    test('projects warning status blocks into dedicated warning items', () {
      final item = projector.project(
        CodexStatusBlock(
          id: 'status_warning',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Warning',
          body: 'The command exceeded the preferred timeout.',
          statusKind: CodexStatusBlockKind.warning,
        ),
      );

      expect(item, isA<ChatWarningItemContract>());
    });

    test('projects deprecation notices into dedicated warning items', () {
      final item = projector.project(
        CodexStatusBlock(
          id: 'status_deprecation',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Deprecation notice',
          body: 'This event family will be removed soon.',
          statusKind: CodexStatusBlockKind.warning,
        ),
      );

      expect(item, isA<ChatDeprecationNoticeItemContract>());
    });

    test('projects patch-apply failures into dedicated error items', () {
      final item = projector.project(
        CodexErrorBlock(
          id: 'error_patch_apply',
          createdAt: DateTime(2026, 3, 15, 12),
          title: 'Patch apply failed',
          body: 'The patch could not be applied cleanly.',
        ),
      );

      expect(item, isA<ChatPatchApplyFailureItemContract>());
    });
  });
}
