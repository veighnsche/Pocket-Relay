import 'ui_block_surface_test_support.dart';

void main() {
  testWidgets(
    'formats pipe-separated search queries into readable alternation text',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptWorkLogGroupBlock(
              id: 'worklog_search_alternation',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <TranscriptWorkLogEntry>[
                TranscriptWorkLogEntry(
                  id: 'entry_rg_alt',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title:
                      r'rg -n "pwsh|powershell|Get-Content|head -|tail -|/usr/bin/sed|/usr/bin/cat|/usr/bin/head|/usr/bin/tail|sed -n" lib test',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Searching for'), findsOneWidget);
      expect(
        find.textContaining(
          'pwsh | powershell | Get-Content | head - | tail -',
        ),
        findsOneWidget,
      );
      expect(find.text('In lib, test'), findsOneWidget);
      expect(
        find.textContaining(
          'pwsh|powershell|Get-Content|head -|tail -|/usr/bin/sed',
        ),
        findsNothing,
      );
    },
  );

  testWidgets('renders git commands as git-specific work-log rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptWorkLogGroupBlock(
            id: 'worklog_git_commands',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <TranscriptWorkLogEntry>[
              TranscriptWorkLogEntry(
                id: 'entry_git_status',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: TranscriptWorkLogEntryKind.commandExecution,
                title: 'git status',
              ),
              TranscriptWorkLogEntry(
                id: 'entry_git_diff',
                createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                entryKind: TranscriptWorkLogEntryKind.commandExecution,
                title: 'git diff --staged README.md',
              ),
              TranscriptWorkLogEntry(
                id: 'entry_git_show',
                createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                entryKind: TranscriptWorkLogEntryKind.commandExecution,
                title: 'git show HEAD~1:README.md',
              ),
              TranscriptWorkLogEntry(
                id: 'entry_git_grep',
                createdAt: DateTime(2026, 3, 14, 12, 0, 3),
                entryKind: TranscriptWorkLogEntryKind.commandExecution,
                title: 'git grep -n "relay_git_probe" lib test',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('4 total · 1 hidden'));
    await tester.pumpAndSettle();

    expect(find.text('Checking worktree status'), findsOneWidget);
    expect(find.text('Current repository'), findsOneWidget);
    expect(find.text('Inspecting diff'), findsOneWidget);
    expect(find.text('Staged changes'), findsOneWidget);
    expect(find.text('README.md'), findsOneWidget);
    expect(find.text('Inspecting git object'), findsOneWidget);
    expect(find.text('HEAD~1:README.md'), findsOneWidget);
    expect(find.text('Searching tracked files'), findsOneWidget);
    expect(find.text('relay_git_probe'), findsOneWidget);
    expect(find.text('In lib, test'), findsOneWidget);

    expect(find.text('git status'), findsNothing);
    expect(find.text('git diff --staged README.md'), findsNothing);
    expect(find.text('git show HEAD~1:README.md'), findsNothing);
    expect(find.text('git grep -n "relay_git_probe" lib test'), findsNothing);
  });

  testWidgets('opens terminal payloads from grouped shell work-log rows', (
    tester,
  ) async {
    ChatWorkLogTerminalContract? openedTerminal;

    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptWorkLogGroupBlock(
            id: 'worklog_git_terminal',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <TranscriptWorkLogEntry>[
              TranscriptWorkLogEntry(
                id: 'entry_git_status_terminal',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: TranscriptWorkLogEntryKind.commandExecution,
                title: 'git status',
                body: ' M lib/main.dart\n',
              ),
            ],
          ),
          onOpenWorkLogTerminal: (terminal) {
            openedTerminal = terminal;
          },
        ),
      ),
    );

    await tester.tap(find.text('Current repository'));
    await tester.pump();

    expect(openedTerminal, isNotNull);
    expect(openedTerminal?.commandText, 'git status');
    expect(openedTerminal?.terminalOutput, ' M lib/main.dart\n');
  });

  testWidgets('renders MCP tool calls as MCP-specific work-log rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptWorkLogGroupBlock(
            id: 'worklog_mcp',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <TranscriptWorkLogEntry>[
              TranscriptWorkLogEntry(
                id: 'entry_mcp_running',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: TranscriptWorkLogEntryKind.mcpToolCall,
                title: 'MCP tool call',
                preview: 'Fetching repository metadata',
                isRunning: true,
                snapshot: const <String, Object?>{
                  'server': 'filesystem',
                  'tool': 'read_file',
                  'status': 'inProgress',
                  'arguments': <String, Object?>{'path': 'README.md'},
                },
              ),
              TranscriptWorkLogEntry(
                id: 'entry_mcp_failed',
                createdAt: DateTime(2026, 3, 14, 12, 0, 1),
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
          ),
        ),
      ),
    );

    expect(find.text('filesystem.read_file'), findsOneWidget);
    expect(find.text('args: path: README.md'), findsNWidgets(2));
    expect(find.text('running · Fetching repository metadata'), findsOneWidget);

    expect(find.text('filesystem.write_file'), findsOneWidget);
    expect(find.text('failed · Permission denied · 142 ms'), findsOneWidget);
    expect(find.text('MCP tool call'), findsNothing);
  });

  testWidgets('keeps a single MCP tool call inside the work-log section', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptWorkLogGroupBlock(
            id: 'worklog_mcp_single',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <TranscriptWorkLogEntry>[
              TranscriptWorkLogEntry(
                id: 'entry_mcp_single',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: TranscriptWorkLogEntryKind.mcpToolCall,
                title: 'MCP tool call',
                snapshot: const <String, Object?>{
                  'server': 'filesystem',
                  'tool': 'read_file',
                  'status': 'completed',
                  'arguments': <String, Object?>{'path': 'README.md'},
                  'result': <String, Object?>{
                    'structuredContent': <String, Object?>{
                      'path': 'README.md',
                      'encoding': 'utf-8',
                    },
                  },
                  'durationMs': 42,
                },
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Work log'), findsOneWidget);
    expect(find.text('filesystem.read_file'), findsOneWidget);
    expect(
      find.text('completed · path: README.md, encoding: utf-8 · 42 ms'),
      findsOneWidget,
    );
    expect(find.text('MCP tool call'), findsNothing);
  });
}
