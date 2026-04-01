import 'ui_block_surface_test_support.dart';

void main() {
  testWidgets('renders compact work-log groups with normalized labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptWorkLogGroupBlock(
            id: 'worklog_1',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <TranscriptWorkLogEntry>[
              TranscriptWorkLogEntry(
                id: 'entry_1',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: TranscriptWorkLogEntryKind.commandExecution,
                title: 'Read docs completed',
                preview: 'Found the CLI docs',
                exitCode: 0,
              ),
              TranscriptWorkLogEntry(
                id: 'entry_2',
                createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                entryKind: TranscriptWorkLogEntryKind.webSearch,
                title: 'Search the reference complete',
                isRunning: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Work log'), findsOneWidget);
    expect(find.text('Read docs'), findsOneWidget);
    expect(find.text('Read docs completed'), findsNothing);
    expect(find.text('running'), findsOneWidget);
  });

  testWidgets(
    'shows hidden work-log count in the tappable header above visible rows',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptWorkLogGroupBlock(
              id: 'worklog_overflow_1',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <TranscriptWorkLogEntry>[
                TranscriptWorkLogEntry(
                  id: 'entry_1',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'first',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_2',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'second',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_3',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'third',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_4',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 3),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'fourth',
                ),
              ],
            ),
          ),
        ),
      );

      final hiddenSummaryTopLeft = tester.getTopLeft(
        find.text('4 total · 1 hidden'),
      );
      final firstVisibleRowTopLeft = tester.getTopLeft(find.text('second'));

      expect(hiddenSummaryTopLeft.dy, lessThan(firstVisibleRowTopLeft.dy));
    },
  );

  testWidgets('renders web-search entries as dedicated work-log rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptWorkLogGroupBlock(
            id: 'worklog_web_search',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <TranscriptWorkLogEntry>[
              TranscriptWorkLogEntry(
                id: 'entry_web_search',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: TranscriptWorkLogEntryKind.webSearch,
                title: 'Search docs',
                preview: 'Found CLI reference and API notes',
                snapshot: const <String, Object?>{'query': 'Pocket Relay CLI'},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Searched'), findsOneWidget);
    expect(find.text('Pocket Relay CLI'), findsOneWidget);
    expect(find.text('Found CLI reference and API notes'), findsOneWidget);
    expect(find.text('Search docs'), findsNothing);
  });

  testWidgets('renders plain command executions as dedicated work-log rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptWorkLogGroupBlock(
            id: 'worklog_command',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <TranscriptWorkLogEntry>[
              TranscriptWorkLogEntry(
                id: 'entry_command',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: TranscriptWorkLogEntryKind.commandExecution,
                title: 'pwd',
                preview: '/repo',
                isRunning: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Running command'), findsOneWidget);
    expect(find.text('pwd'), findsOneWidget);
    expect(find.text('/repo'), findsOneWidget);
  });

  testWidgets(
    'renders empty-stdin terminal interactions as a dedicated command wait row',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptWorkLogGroupBlock(
              id: 'worklog_command_wait',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <TranscriptWorkLogEntry>[
                TranscriptWorkLogEntry(
                  id: 'entry_command_wait',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'sleep 5',
                  preview: 'still running',
                  isRunning: true,
                  snapshot: const <String, Object?>{
                    'processId': 'proc_1',
                    'stdin': '',
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('waiting'), findsOneWidget);
      expect(find.text('Waiting for background terminal'), findsOneWidget);
      expect(find.text('sleep 5'), findsOneWidget);
      expect(find.text('still running'), findsOneWidget);
      expect(find.text('Running command'), findsNothing);
    },
  );

  testWidgets('renders simple sed reads as structured read work-log rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: TranscriptWorkLogGroupBlock(
            id: 'worklog_sed',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <TranscriptWorkLogEntry>[
              TranscriptWorkLogEntry(
                id: 'entry_sed',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: TranscriptWorkLogEntryKind.commandExecution,
                title:
                    "sed -n '1,120p' lib/src/features/chat/worklog/presentation/widgets/work_log_group_surface.dart",
                exitCode: 0,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Reading lines 1 to 120'), findsOneWidget);
    expect(find.text('work_log_group_surface.dart'), findsOneWidget);
    expect(
      find.text(
        'lib/src/features/chat/worklog/presentation/widgets/work_log_group_surface.dart',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        "sed -n '1,120p' lib/src/features/chat/worklog/presentation/widgets/work_log_group_surface.dart",
      ),
      findsNothing,
    );
    expect(find.text('exit 0'), findsNothing);
  });

  testWidgets(
    'renders cat, head, tail, and Get-Content reads as command-specific work-log rows',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptWorkLogGroupBlock(
              id: 'worklog_reads',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <TranscriptWorkLogEntry>[
                TranscriptWorkLogEntry(
                  id: 'entry_cat',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'cat README.md',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_head',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'head -n 40 docs/021_codebase-handoff.md',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_tail',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'tail -20 logs/output.txt',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_get_content',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 3),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: r'Get-Content -Path C:\repo\README.md -TotalCount 25',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('4 total · 1 hidden'));
      await tester.pumpAndSettle();

      expect(find.text('Reading full file'), findsOneWidget);
      expect(find.text('README.md'), findsAtLeastNWidgets(2));

      expect(find.text('Reading first 40 lines'), findsOneWidget);
      expect(find.text('021_codebase-handoff.md'), findsOneWidget);

      expect(find.text('Reading last 20 lines'), findsOneWidget);
      expect(find.text('output.txt'), findsOneWidget);

      expect(find.text('Reading first 25 lines'), findsOneWidget);
      expect(find.text(r'C:\repo\README.md'), findsOneWidget);

      expect(find.text('cat README.md'), findsNothing);
      expect(
        find.text('head -n 40 docs/021_codebase-handoff.md'),
        findsNothing,
      );
      expect(find.text('tail -20 logs/output.txt'), findsNothing);
      expect(
        find.text(r'Get-Content -Path C:\repo\README.md -TotalCount 25'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'renders type, more, awk, and Select-Object-piped Get-Content reads as command-specific work-log rows',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptWorkLogGroupBlock(
              id: 'worklog_more_reads',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <TranscriptWorkLogEntry>[
                TranscriptWorkLogEntry(
                  id: 'entry_type',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: r'type C:\repo\README.md',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_more',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'more docs/021_codebase-handoff.md',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_awk',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: "awk 'NR>=5 && NR<=25 {print}' lib/main.dart",
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_get_content_select_range',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 3),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title:
                      r'Get-Content -Path C:\repo\README.md | Select-Object -Skip 4 -First 21',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('4 total · 1 hidden'));
      await tester.pumpAndSettle();

      expect(find.text('Reading full file'), findsNWidgets(2));
      expect(find.text('README.md'), findsAtLeastNWidgets(2));
      expect(find.text('021_codebase-handoff.md'), findsOneWidget);

      expect(find.text('Reading lines 5 to 25'), findsNWidgets(2));
      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text(r'C:\repo\README.md'), findsAtLeastNWidgets(2));

      expect(find.text(r'type C:\repo\README.md'), findsNothing);
      expect(find.text('more docs/021_codebase-handoff.md'), findsNothing);
      expect(
        find.text("awk 'NR>=5 && NR<=25 {print}' lib/main.dart"),
        findsNothing,
      );
      expect(
        find.text(
          r'Get-Content -Path C:\repo\README.md | Select-Object -Skip 4 -First 21',
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'renders rg, grep, Select-String, and findstr searches as command-specific work-log rows',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: TranscriptWorkLogGroupBlock(
              id: 'worklog_searches',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <TranscriptWorkLogEntry>[
                TranscriptWorkLogEntry(
                  id: 'entry_rg',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'rg -n "Pocket Relay" lib test',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_grep',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: 'grep -R -n "Pocket Relay" README.md',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_select_string',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title:
                      r'Select-String -Path C:\repo\README.md -Pattern "Pocket Relay"',
                ),
                TranscriptWorkLogEntry(
                  id: 'entry_findstr',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 3),
                  entryKind: TranscriptWorkLogEntryKind.commandExecution,
                  title: r'findstr /n /s /c:"Pocket Relay" *.md',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('4 total · 1 hidden'));
      await tester.pumpAndSettle();

      expect(find.text('Searching for'), findsNWidgets(4));
      expect(find.text('Pocket Relay'), findsNWidgets(4));
      expect(find.text('In lib, test'), findsOneWidget);
      expect(find.text('In README.md'), findsOneWidget);
      expect(find.text(r'In C:\repo\README.md'), findsOneWidget);
      expect(find.text('In *.md'), findsOneWidget);

      expect(find.text('rg -n "Pocket Relay" lib test'), findsNothing);
      expect(find.text('grep -R -n "Pocket Relay" README.md'), findsNothing);
      expect(
        find.text(
          r'Select-String -Path C:\repo\README.md -Pattern "Pocket Relay"',
        ),
        findsNothing,
      );
      expect(find.text(r'findstr /n /s /c:"Pocket Relay" *.md'), findsNothing);
    },
  );
}
