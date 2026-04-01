import '../../support/screen_presentation_test_support.dart';

void main() {
  group('ChatTranscriptItemProjector', () {
    const projector = ChatTranscriptItemProjector();

    test('projects rg searches into command-specific work-log entries', () {
      final groupBlock = TranscriptWorkLogGroupBlock(
        id: 'worklog_rg',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <TranscriptWorkLogEntry>[
          TranscriptWorkLogEntry(
            id: 'entry_rg',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: TranscriptWorkLogEntryKind.commandExecution,
            title: 'rg -n "Pocket Relay" lib test',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry =
          item.entries.single as ChatRipgrepSearchWorkLogEntryContract;

      expect(entry.queryText, 'Pocket Relay');
      expect(entry.scopeTargets, <String>['lib', 'test']);
      expect(entry.scopeLabel, 'In lib, test');
      expect(entry.summaryLabel, 'Searching for');
    });

    test('projects grep searches into command-specific work-log entries', () {
      final groupBlock = TranscriptWorkLogGroupBlock(
        id: 'worklog_grep',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <TranscriptWorkLogEntry>[
          TranscriptWorkLogEntry(
            id: 'entry_grep',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: TranscriptWorkLogEntryKind.commandExecution,
            title: 'grep -R -n "Pocket Relay" README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGrepSearchWorkLogEntryContract;

      expect(entry.queryText, 'Pocket Relay');
      expect(entry.scopeTargets, <String>['README.md']);
      expect(entry.scopeLabel, 'In README.md');
    });

    test(
      'projects Select-String searches into command-specific work-log entries',
      () {
        final groupBlock = TranscriptWorkLogGroupBlock(
          id: 'worklog_select_string',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <TranscriptWorkLogEntry>[
            TranscriptWorkLogEntry(
              id: 'entry_select_string',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: TranscriptWorkLogEntryKind.commandExecution,
              title:
                  r'Select-String -Path C:\repo\README.md -Pattern "Pocket Relay"',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatSelectStringSearchWorkLogEntryContract;

        expect(entry.queryText, 'Pocket Relay');
        expect(entry.scopeTargets, <String>[r'C:\repo\README.md']);
        expect(entry.scopeLabel, r'In C:\repo\README.md');
      },
    );

    test(
      'projects findstr searches into command-specific work-log entries',
      () {
        final groupBlock = TranscriptWorkLogGroupBlock(
          id: 'worklog_findstr',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <TranscriptWorkLogEntry>[
            TranscriptWorkLogEntry(
              id: 'entry_findstr',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: TranscriptWorkLogEntryKind.commandExecution,
              title: r'findstr /n /s /c:"Pocket Relay" *.md',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatFindStrSearchWorkLogEntryContract;

        expect(entry.queryText, 'Pocket Relay');
        expect(entry.scopeTargets, <String>['*.md']);
        expect(entry.scopeLabel, 'In *.md');
      },
    );

    test(
      'splits simple top-level alternation queries into structured display segments',
      () {
        final groupBlock = TranscriptWorkLogGroupBlock(
          id: 'worklog_rg_alt',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <TranscriptWorkLogEntry>[
            TranscriptWorkLogEntry(
              id: 'entry_rg_alt',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: TranscriptWorkLogEntryKind.commandExecution,
              title:
                  r'rg -n "pwsh|powershell|Get-Content|head -|tail -|/usr/bin/sed|/usr/bin/cat|/usr/bin/head|/usr/bin/tail|sed -n" lib test',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatRipgrepSearchWorkLogEntryContract;

        expect(entry.querySegments, <String>[
          'pwsh',
          'powershell',
          'Get-Content',
          'head -',
          'tail -',
          '/usr/bin/sed',
          '/usr/bin/cat',
          '/usr/bin/head',
          '/usr/bin/tail',
          'sed -n',
        ]);
        expect(
          entry.displayQueryText,
          'pwsh | powershell | Get-Content | head - | tail - | /usr/bin/sed | /usr/bin/cat | /usr/bin/head | /usr/bin/tail | sed -n',
        );
      },
    );

    test('keeps chained rg commands as generic work-log entries', () {
      final groupBlock = TranscriptWorkLogGroupBlock(
        id: 'worklog_rg_chain',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <TranscriptWorkLogEntry>[
          TranscriptWorkLogEntry(
            id: 'entry_rg_chain',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: TranscriptWorkLogEntryKind.commandExecution,
            title:
                'rg -n "Pocket Relay" lib && grep -n "Pocket Relay" README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;

      expect(item.entries.single, isA<ChatGenericWorkLogEntryContract>());
    });

    test('projects git status commands into git work-log entries', () {
      final groupBlock = TranscriptWorkLogGroupBlock(
        id: 'worklog_git_status',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <TranscriptWorkLogEntry>[
          TranscriptWorkLogEntry(
            id: 'entry_git_status',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: TranscriptWorkLogEntryKind.commandExecution,
            title: 'git status',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGitWorkLogEntryContract;

      expect(entry.summaryLabel, 'Checking worktree status');
      expect(entry.primaryLabel, 'Current repository');
      expect(entry.secondaryLabel, isNull);
    });

    test('projects git diff commands into git work-log entries', () {
      final groupBlock = TranscriptWorkLogGroupBlock(
        id: 'worklog_git_diff',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <TranscriptWorkLogEntry>[
          TranscriptWorkLogEntry(
            id: 'entry_git_diff',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: TranscriptWorkLogEntryKind.commandExecution,
            title: 'git diff --staged README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGitWorkLogEntryContract;

      expect(entry.summaryLabel, 'Inspecting diff');
      expect(entry.primaryLabel, 'Staged changes');
      expect(entry.secondaryLabel, 'README.md');
    });

    test('projects git show commands into git work-log entries', () {
      final groupBlock = TranscriptWorkLogGroupBlock(
        id: 'worklog_git_show',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <TranscriptWorkLogEntry>[
          TranscriptWorkLogEntry(
            id: 'entry_git_show',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: TranscriptWorkLogEntryKind.commandExecution,
            title: 'git show HEAD~1:README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGitWorkLogEntryContract;

      expect(entry.summaryLabel, 'Inspecting git object');
      expect(entry.primaryLabel, 'HEAD~1:README.md');
    });

    test('projects git grep commands into git work-log entries', () {
      final groupBlock = TranscriptWorkLogGroupBlock(
        id: 'worklog_git_grep',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <TranscriptWorkLogEntry>[
          TranscriptWorkLogEntry(
            id: 'entry_git_grep',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: TranscriptWorkLogEntryKind.commandExecution,
            title: 'git grep -n "Pocket Relay" lib test',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGitWorkLogEntryContract;

      expect(entry.summaryLabel, 'Searching tracked files');
      expect(entry.primaryLabel, 'Pocket Relay');
      expect(entry.secondaryLabel, 'In lib, test');
    });

    test('keeps unknown git subcommands in the git work-log family', () {
      final groupBlock = TranscriptWorkLogGroupBlock(
        id: 'worklog_git_generic',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <TranscriptWorkLogEntry>[
          TranscriptWorkLogEntry(
            id: 'entry_git_generic',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: TranscriptWorkLogEntryKind.commandExecution,
            title: 'git sparse-checkout list',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatGitWorkLogEntryContract;

      expect(entry.summaryLabel, 'Running git sparse-checkout');
      expect(entry.primaryLabel, 'list');
    });

    test('keeps completed MCP tool calls inside grouped work-log entries', () {
      final groupBlock = TranscriptWorkLogGroupBlock(
        id: 'worklog_mcp_completed',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <TranscriptWorkLogEntry>[
          TranscriptWorkLogEntry(
            id: 'entry_mcp_completed',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: TranscriptWorkLogEntryKind.mcpToolCall,
            title: 'MCP tool call',
            snapshot: const <String, Object?>{
              'server': 'filesystem',
              'tool': 'read_file',
              'status': 'completed',
              'arguments': <String, Object?>{'path': 'README.md'},
              'result': <String, Object?>{
                'content': <Object?>[
                  <String, Object?>{
                    'type': 'text',
                    'text': 'README first lines\nMore output',
                  },
                ],
              },
              'durationMs': 42,
            },
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatMcpToolCallWorkLogEntryContract;

      expect(entry.status, ChatMcpToolCallStatus.completed);
      expect(entry.toolName, 'read_file');
      expect(entry.serverName, 'filesystem');
      expect(entry.identityLabel, 'filesystem.read_file');
      expect(entry.argumentsSummary, 'path: README.md');
      expect(entry.resultSummary, 'README first lines');
      expect(entry.argumentsLabel, 'args: path: README.md');
      expect(entry.outcomeLabel, 'completed · README first lines · 42 ms');
    });

    test('keeps failed MCP tool calls inside grouped work-log entries', () {
      final groupBlock = TranscriptWorkLogGroupBlock(
        id: 'worklog_mcp_failed',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <TranscriptWorkLogEntry>[
          TranscriptWorkLogEntry(
            id: 'entry_mcp_failed',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: TranscriptWorkLogEntryKind.mcpToolCall,
            title: 'MCP tool call',
            snapshot: const <String, Object?>{
              'server': 'filesystem',
              'tool': 'write_file',
              'status': 'failed',
              'arguments': <String, Object?>{'path': 'README.md'},
              'error': <String, Object?>{'message': 'Permission denied'},
              'durationMs': 142,
            },
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatMcpToolCallWorkLogEntryContract;

      expect(entry.status, ChatMcpToolCallStatus.failed);
      expect(entry.identityLabel, 'filesystem.write_file');
      expect(entry.argumentsSummary, 'path: README.md');
      expect(entry.errorSummary, 'Permission denied');
      expect(entry.argumentsLabel, 'args: path: README.md');
      expect(entry.outcomeLabel, 'failed · Permission denied · 142 ms');
    });
  });
}
