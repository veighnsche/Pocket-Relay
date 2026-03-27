import '../../support/screen_presentation_test_support.dart';

void main() {
  group('ChatTranscriptItemProjector', () {
    const projector = ChatTranscriptItemProjector();

    test('projects sed -ne read commands into read work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_sed_ne',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_sed_ne',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: "sed -ne '5,25p' lib/src/app/pocket_relay_app.dart",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatSedReadWorkLogEntryContract;

      expect(entry.lineStart, 5);
      expect(entry.lineEnd, 25);
      expect(entry.summaryLabel, 'Reading lines 5 to 25');
    });

    test('projects nl piped into sed reads into read work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_nl_sed',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_nl_sed',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: "nl -ba lib/src/app/pocket_relay_app.dart | sed -n '5,25p'",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatSedReadWorkLogEntryContract;

      expect(entry.lineStart, 5);
      expect(entry.lineEnd, 25);
      expect(entry.fileName, 'pocket_relay_app.dart');
      expect(entry.filePath, 'lib/src/app/pocket_relay_app.dart');
      expect(entry.summaryLabel, 'Reading lines 5 to 25');
    });

    test('keeps chained sed commands as generic work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_sed_chain',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_sed_chain',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title:
                "sed -n '1,120p' lib/src/app/pocket_relay_app.dart && rg Pocket Relay",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;

      expect(item.entries.single, isA<ChatGenericWorkLogEntryContract>());
    });

    test('keeps reversed sed ranges as generic work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_sed_reversed',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_sed_reversed',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: "sed -n '40,1p' lib/src/app/pocket_relay_app.dart",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;

      expect(item.entries.single, isA<ChatGenericWorkLogEntryContract>());
    });

    test('projects cat reads into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_cat',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_cat',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'cat README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatCatReadWorkLogEntryContract;

      expect(entry.fileName, 'README.md');
      expect(entry.filePath, 'README.md');
      expect(entry.summaryLabel, 'Reading full file');
    });

    test('projects type reads into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_type',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_type',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: r'type C:\repo\README.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatTypeReadWorkLogEntryContract;

      expect(entry.fileName, 'README.md');
      expect(entry.filePath, r'C:\repo\README.md');
      expect(entry.summaryLabel, 'Reading full file');
    });

    test('projects more reads into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_more',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_more',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'more docs/021_codebase-handoff.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatMoreReadWorkLogEntryContract;

      expect(entry.fileName, '021_codebase-handoff.md');
      expect(entry.filePath, 'docs/021_codebase-handoff.md');
      expect(entry.summaryLabel, 'Reading full file');
    });

    test('projects head reads into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_head',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_head',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'head -n 40 docs/021_codebase-handoff.md',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatHeadReadWorkLogEntryContract;

      expect(entry.lineCount, 40);
      expect(entry.fileName, '021_codebase-handoff.md');
      expect(entry.summaryLabel, 'Reading first 40 lines');
    });

    test(
      'projects compact head -n40 reads into command-specific work-log entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_head_compact',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_head_compact',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: 'head -n40 docs/021_codebase-handoff.md',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry = item.entries.single as ChatHeadReadWorkLogEntryContract;

        expect(entry.lineCount, 40);
        expect(entry.summaryLabel, 'Reading first 40 lines');
      },
    );

    test('projects tail reads into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_tail',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_tail',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: 'tail -20 logs/output.txt',
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatTailReadWorkLogEntryContract;

      expect(entry.lineCount, 20);
      expect(entry.fileName, 'output.txt');
      expect(entry.summaryLabel, 'Reading last 20 lines');
    });

    test(
      'projects Get-Content reads into command-specific work-log entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_get_content',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_get_content',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title: r'Get-Content -Path C:\repo\README.md -TotalCount 25',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatGetContentReadWorkLogEntryContract;

        expect(entry.mode, ChatGetContentReadMode.firstLines);
        expect(entry.lineCount, 25);
        expect(entry.fileName, 'README.md');
        expect(entry.filePath, r'C:\repo\README.md');
        expect(entry.summaryLabel, 'Reading first 25 lines');
      },
    );

    test(
      'projects Get-Content piped through Select-Object first-lines reads into command-specific work-log entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_get_content_select_first',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_get_content_select_first',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title:
                  r'Get-Content -Path C:\repo\README.md | Select-Object -First 25',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatGetContentReadWorkLogEntryContract;

        expect(entry.mode, ChatGetContentReadMode.firstLines);
        expect(entry.lineCount, 25);
        expect(entry.filePath, r'C:\repo\README.md');
        expect(entry.summaryLabel, 'Reading first 25 lines');
      },
    );

    test(
      'projects Get-Content piped through Select-Object range reads into command-specific work-log entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_get_content_select_range',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_get_content_select_range',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title:
                  r'Get-Content -Path C:\repo\README.md | Select-Object -Skip 4 -First 21',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatGetContentReadWorkLogEntryContract;

        expect(entry.mode, ChatGetContentReadMode.lineRange);
        expect(entry.lineStart, 5);
        expect(entry.lineEnd, 25);
        expect(entry.summaryLabel, 'Reading lines 5 to 25');
      },
    );

    test(
      'projects Get-Content piped through Select-Object last-lines reads into command-specific work-log entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_get_content_select_last',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_get_content_select_last',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title:
                  r'Get-Content -Path C:\repo\README.md | Select-Object -Last 10',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;
        final entry =
            item.entries.single as ChatGetContentReadWorkLogEntryContract;

        expect(entry.mode, ChatGetContentReadMode.lastLines);
        expect(entry.lineCount, 10);
        expect(entry.summaryLabel, 'Reading last 10 lines');
      },
    );

    test('projects awk range reads into command-specific work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_awk',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_awk',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title:
                "awk 'NR>=5 && NR<=25 {print}' lib/src/app/pocket_relay_app.dart",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;
      final entry = item.entries.single as ChatAwkReadWorkLogEntryContract;

      expect(entry.lineStart, 5);
      expect(entry.lineEnd, 25);
      expect(entry.fileName, 'pocket_relay_app.dart');
      expect(entry.summaryLabel, 'Reading lines 5 to 25');
    });

    test(
      'keeps unsupported Get-Content Select-Object pipelines as generic work-log entries',
      () {
        final groupBlock = CodexWorkLogGroupBlock(
          id: 'worklog_get_content_select_skip_only',
          createdAt: DateTime(2026, 3, 15, 12),
          entries: <CodexWorkLogEntry>[
            CodexWorkLogEntry(
              id: 'entry_get_content_select_skip_only',
              createdAt: DateTime(2026, 3, 15, 12),
              entryKind: CodexWorkLogEntryKind.commandExecution,
              title:
                  r'Get-Content -Path C:\repo\README.md | Select-Object -Skip 4',
            ),
          ],
        );

        final item =
            projector.project(groupBlock) as ChatWorkLogGroupItemContract;

        expect(item.entries.single, isA<ChatGenericWorkLogEntryContract>());
      },
    );

    test('keeps unsupported awk scripts as generic work-log entries', () {
      final groupBlock = CodexWorkLogGroupBlock(
        id: 'worklog_awk_unsupported',
        createdAt: DateTime(2026, 3, 15, 12),
        entries: <CodexWorkLogEntry>[
          CodexWorkLogEntry(
            id: 'entry_awk_unsupported',
            createdAt: DateTime(2026, 3, 15, 12),
            entryKind: CodexWorkLogEntryKind.commandExecution,
            title: "awk '{print \$1}' lib/src/app/pocket_relay_app.dart",
          ),
        ],
      );

      final item =
          projector.project(groupBlock) as ChatWorkLogGroupItemContract;

      expect(item.entries.single, isA<ChatGenericWorkLogEntryContract>());
    });
  });
}
