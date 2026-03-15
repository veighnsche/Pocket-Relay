import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/transcript_list.dart';

void main() {
  testWidgets('renders reasoning blocks with markdown text', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexTextBlock(
            id: 'reasoning_1',
            kind: CodexUiBlockKind.reasoning,
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Reasoning',
            body: 'Investigating the next step.',
          ),
        ),
      ),
    );

    expect(find.text('Reasoning'), findsOneWidget);
    expect(find.text('Investigating the next step.'), findsOneWidget);
  });

  testWidgets('renders code fences with readable text in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        themeMode: ThemeMode.dark,
        child: ConversationEntryCard(
          block: CodexTextBlock(
            id: 'reasoning_code_1',
            kind: CodexUiBlockKind.reasoning,
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Reasoning',
            body: '```dart\nfinal answer = 42;\n```',
          ),
        ),
      ),
    );

    expect(find.text('final answer = 42;'), findsOneWidget);

    final codeStyle = _findStyleForText(tester, 'final answer = 42;');

    expect(codeStyle, isNotNull);
    expect(codeStyle?.color, const Color(0xFFE7F3F4));
  });

  testWidgets('uses dark surfaces for parsed codex cards in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        themeMode: ThemeMode.dark,
        child: Column(
          children: [
            ConversationEntryCard(
              block: CodexTextBlock(
                id: 'reasoning_dark_1',
                kind: CodexUiBlockKind.reasoning,
                createdAt: DateTime(2026, 3, 14, 12),
                title: 'Reasoning',
                body: 'Dark mode should use the themed surface.',
              ),
            ),
            const SizedBox(height: 16),
            ConversationEntryCard(
              block: CodexChangedFilesBlock(
                id: 'files_dark_1',
                createdAt: DateTime(2026, 3, 14, 12),
                title: 'Changed files',
                files: <CodexChangedFile>[
                  const CodexChangedFile(
                    path: 'lib/src/features/chat/presentation/widgets/foo.dart',
                    additions: 2,
                    deletions: 1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    expect(
      _findDecoratedContainerColorForText(tester, 'Reasoning'),
      PocketPalette.dark.surface,
    );
    expect(
      _findDecoratedContainerColorForText(tester, 'Changed files'),
      PocketPalette.dark.surface,
    );
  });

  testWidgets('renders assistant messages without a decorated card shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexTextBlock(
            id: 'assistant_1',
            kind: CodexUiBlockKind.assistantMessage,
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Codex',
            body: 'Plain assistant transcript.',
          ),
        ),
      ),
    );

    expect(find.text('Codex'), findsOneWidget);
    expect(find.text('Plain assistant transcript.'), findsOneWidget);
    expect(_findDecoratedContainerColorForText(tester, 'Codex'), isNull);
  });

  testWidgets('renders a live elapsed footer for a running assistant turn', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexTextBlock(
            id: 'assistant_live_1',
            kind: CodexUiBlockKind.assistantMessage,
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Codex',
            body: 'Streaming response.',
            turnId: 'turn_live',
            isRunning: true,
          ),
          turnTimer: CodexSessionTurnTimer(
            turnId: 'turn_live',
            startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
          ),
        ),
      ),
    );

    expect(find.textContaining('Elapsed'), findsOneWidget);
  });

  testWidgets('renders a completed elapsed footer with the final duration', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexTextBlock(
            id: 'assistant_done_1',
            kind: CodexUiBlockKind.assistantMessage,
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Codex',
            body: 'Final response.',
            turnId: 'turn_done',
          ),
          turnTimer: CodexSessionTurnTimer(
            turnId: 'turn_done',
            startedAt: DateTime(2026, 3, 14, 12),
            completedAt: DateTime(2026, 3, 14, 12, 1, 8),
          ),
        ),
      ),
    );

    expect(find.text('Completed in 1:08'), findsOneWidget);
  });

  testWidgets('shows the elapsed footer only on the last eligible block', (
    tester,
  ) async {
    final timer = CodexSessionTurnTimer(
      turnId: 'turn_1',
      startedAt: DateTime(2026, 3, 14, 12),
      completedAt: DateTime(2026, 3, 14, 12, 0, 9),
    );

    await tester.pumpWidget(
      _buildTestApp(
        child: TranscriptList(
          controller: TranscriptListController(),
          isConfigured: true,
          transcriptBlocks: <CodexUiBlock>[
            CodexTextBlock(
              id: 'reasoning_1',
              kind: CodexUiBlockKind.reasoning,
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Reasoning',
              body: 'Planning the patch.',
              turnId: 'turn_1',
            ),
            CodexTextBlock(
              id: 'assistant_1',
              kind: CodexUiBlockKind.assistantMessage,
              createdAt: DateTime(2026, 3, 14, 12, 0, 1),
              title: 'Codex',
              body: 'Patch applied.',
              turnId: 'turn_1',
            ),
          ],
          turnTimers: <String, CodexSessionTurnTimer>{'turn_1': timer},
          onConfigure: () {},
        ),
      ),
    );

    expect(find.text('Completed in 0:09'), findsOneWidget);
  });

  testWidgets('renders approval request actions', (tester) async {
    String? approvedRequestId;

    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexApprovalRequestBlock(
            id: 'request_1',
            createdAt: DateTime(2026, 3, 14, 12),
            requestId: 'request_1',
            requestType: CodexCanonicalRequestType.fileChangeApproval,
            title: 'File change approval',
            body: 'Allow Codex to write files.',
          ),
          onApproveRequest: (requestId) async {
            approvedRequestId = requestId;
          },
          onDenyRequest: (_) async {},
        ),
      ),
    );

    expect(find.text('Approve'), findsOneWidget);
    expect(find.text('Deny'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pump();

    expect(approvedRequestId, 'request_1');
  });

  testWidgets('renders user-input fields and submits answers', (tester) async {
    String? submittedRequestId;
    Map<String, List<String>>? submittedAnswers;

    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexUserInputRequestBlock(
            id: 'input_1',
            createdAt: DateTime(2026, 3, 14, 12),
            requestId: 'input_1',
            requestType: CodexCanonicalRequestType.toolUserInput,
            title: 'Input required',
            body: 'Codex needs clarification.',
            questions: const <CodexRuntimeUserInputQuestion>[
              CodexRuntimeUserInputQuestion(
                id: 'q1',
                header: 'Project',
                question: 'Which project should I use?',
              ),
            ],
          ),
          onSubmitUserInput: (requestId, answers) async {
            submittedRequestId = requestId;
            submittedAnswers = answers;
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Pocket Relay');
    await tester.tap(find.text('Submit response'));
    await tester.pump();

    expect(submittedRequestId, 'input_1');
    expect(submittedAnswers, <String, List<String>>{
      'q1': <String>['Pocket Relay'],
    });
  });

  testWidgets('resyncs user-input fields when the backing request changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexUserInputRequestBlock(
            id: 'input_1',
            createdAt: DateTime(2026, 3, 14, 12),
            requestId: 'input_1',
            requestType: CodexCanonicalRequestType.toolUserInput,
            title: 'Input required',
            body: 'First request.',
            questions: const <CodexRuntimeUserInputQuestion>[
              CodexRuntimeUserInputQuestion(
                id: 'q1',
                header: 'Project',
                question: 'Which project should I use?',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Local draft');
    await tester.pump();

    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexUserInputRequestBlock(
            id: 'input_2',
            createdAt: DateTime(2026, 3, 14, 12, 0, 5),
            requestId: 'input_2',
            requestType: CodexCanonicalRequestType.toolUserInput,
            title: 'Input submitted',
            body: 'Second request.',
            isResolved: true,
            questions: const <CodexRuntimeUserInputQuestion>[
              CodexRuntimeUserInputQuestion(
                id: 'q2',
                header: 'Workspace',
                question: 'Which workspace should I use?',
              ),
            ],
            answers: <String, List<String>>{
              'q2': <String>['/workspace/mobile'],
            },
          ),
        ),
      ),
    );

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Project'), findsNothing);
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, '/workspace/mobile');
  });

  testWidgets(
    'renders proposed plans with extracted title and collapse control',
    (tester) async {
      final markdownLines = <String>[
        '# Ship mobile widgets',
        '',
        '## Summary',
        '',
        for (var index = 0; index < 24; index += 1)
          '- Step ${index + 1} for the rollout',
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: SingleChildScrollView(
            child: ConversationEntryCard(
              block: CodexProposedPlanBlock(
                id: 'plan_1',
                createdAt: DateTime(2026, 3, 14, 12),
                title: 'Proposed plan',
                markdown: markdownLines.join('\n'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ship mobile widgets'), findsOneWidget);
      expect(find.text('Summary'), findsNothing);
      expect(find.text('Expand plan'), findsOneWidget);

      await tester.tap(find.text('Expand plan'));
      await tester.pumpAndSettle();

      expect(find.text('Collapse plan'), findsOneWidget);
    },
  );

  testWidgets(
    'keys transcript cards by block id so local state does not leak',
    (tester) async {
      final controller = TranscriptListController();
      final markdownLines = <String>[
        '# Ship mobile widgets',
        '',
        '## Summary',
        '',
        for (var index = 0; index < 24; index += 1)
          '- Step ${index + 1} for the rollout',
      ];

      await tester.pumpWidget(
        _buildTestApp(
          child: TranscriptList(
            controller: controller,
            isConfigured: true,
            transcriptBlocks: <CodexUiBlock>[
              CodexProposedPlanBlock(
                id: 'plan_1',
                createdAt: DateTime(2026, 3, 14, 12),
                title: 'Proposed plan',
                markdown: markdownLines.join('\n'),
              ),
            ],
            turnTimers: const <String, CodexSessionTurnTimer>{},
            onConfigure: () {},
          ),
        ),
      );

      await tester.tap(find.text('Expand plan'));
      await tester.pumpAndSettle();
      expect(find.text('Collapse plan'), findsOneWidget);

      await tester.pumpWidget(
        _buildTestApp(
          child: TranscriptList(
            controller: controller,
            isConfigured: true,
            transcriptBlocks: <CodexUiBlock>[
              CodexProposedPlanBlock(
                id: 'plan_2',
                createdAt: DateTime(2026, 3, 14, 12, 0, 5),
                title: 'Proposed plan',
                markdown: markdownLines.join('\n'),
              ),
            ],
            turnTimers: const <String, CodexSessionTurnTimer>{},
            onConfigure: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expand plan'), findsOneWidget);
      expect(find.text('Collapse plan'), findsNothing);
    },
  );

  testWidgets('renders compact work-log groups with normalized labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexWorkLogGroupBlock(
            id: 'worklog_1',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <CodexWorkLogEntry>[
              CodexWorkLogEntry(
                id: 'entry_1',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: CodexWorkLogEntryKind.commandExecution,
                title: 'Read docs completed',
                preview: 'Found the CLI docs',
                exitCode: 0,
              ),
              CodexWorkLogEntry(
                id: 'entry_2',
                createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                entryKind: CodexWorkLogEntryKind.webSearch,
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

  testWidgets('renders thread token usage as a compact usage strip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexUsageBlock(
            id: 'usage_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Thread token usage',
            body:
                'Last: input 10946 · cached 9216 · output 510 · reasoning 288 · total 11456\n'
                'Total: input 21946 · cached 18216 · output 910 · reasoning 488 · total 23356\n'
                'Context window: 258400',
          ),
        ),
      ),
    );

    expect(find.text('Thread usage'), findsOneWidget);
    expect(find.text('ctx 258.4k'), findsOneWidget);
    expect(find.text('current'), findsOneWidget);
    expect(find.text('total'), findsOneWidget);
    expect(find.text('in'), findsOneWidget);
    expect(find.text('cache'), findsOneWidget);
    expect(find.text('out'), findsOneWidget);
    expect(find.text('rsn'), findsOneWidget);
    expect(find.text('all'), findsOneWidget);
    expect(find.text('10.9k'), findsOneWidget);
    expect(find.text('910'), findsOneWidget);
  });

  testWidgets(
    'renders duplicate thread token usage as current and total rows',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: ConversationEntryCard(
            block: CodexUsageBlock(
              id: 'usage_2',
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Thread token usage',
              body:
                  'Last: input 12 · cached 3 · output 7\n'
                  'Total: input 12 · cached 3 · output 7',
            ),
          ),
        ),
      );

      expect(find.text('current'), findsOneWidget);
      expect(find.text('total'), findsOneWidget);
      expect(find.text('in'), findsOneWidget);
      expect(find.text('cache'), findsOneWidget);
      expect(find.text('out'), findsOneWidget);
      expect(find.text('12'), findsNWidgets(2));
      expect(find.text('3'), findsNWidgets(2));
      expect(find.text('7'), findsNWidgets(2));
    },
  );

  testWidgets('renders turn completion as a compact separator', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexTurnBoundaryBlock(
            id: 'turn_end_1',
            createdAt: DateTime(2026, 3, 14, 12),
          ),
        ),
      ),
    );

    expect(find.text('end'), findsOneWidget);
  });

  testWidgets('renders elapsed time in the turn completion separator', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexTurnBoundaryBlock(
            id: 'turn_end_2',
            createdAt: DateTime(2026, 3, 14, 12),
            elapsed: const Duration(minutes: 1, seconds: 5),
          ),
        ),
      ),
    );

    expect(find.text('end · 1:05'), findsOneWidget);
  });

  testWidgets('renders a live elapsed footer on the active streaming card', (
    tester,
  ) async {
    final startedAt = DateTime.now().subtract(const Duration(seconds: 5));

    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexTextBlock(
            id: 'assistant_live_1',
            kind: CodexUiBlockKind.assistantMessage,
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Codex',
            body: 'Streaming response',
            turnId: 'turn_123',
            isRunning: true,
          ),
          turnTimer: CodexSessionTurnTimer(
            turnId: 'turn_123',
            startedAt: startedAt,
          ),
        ),
      ),
    );

    expect(find.textContaining('Elapsed 0:05'), findsOneWidget);
  });

  testWidgets('renders changed files summary and opens a per-file diff sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexChangedFilesBlock(
            id: 'diff_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <CodexChangedFile>[
              CodexChangedFile(
                path: 'lib/src/features/chat/chat_screen.dart',
                additions: 3,
                deletions: 1,
              ),
              CodexChangedFile(
                path:
                    'lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart',
                additions: 8,
                deletions: 2,
              ),
            ],
            unifiedDiff:
                'diff --git a/lib/src/features/chat/chat_screen.dart b/lib/src/features/chat/chat_screen.dart\n'
                '--- a/lib/src/features/chat/chat_screen.dart\n'
                '+++ b/lib/src/features/chat/chat_screen.dart\n'
                '@@ -1 +1 @@\n'
                '-old screen\n'
                '+new screen\n'
                'diff --git a/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart b/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart\n'
                '--- a/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart\n'
                '+++ b/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart\n'
                '@@ -2 +2 @@\n'
                '-old card\n'
                '+new card\n',
          ),
        ),
      ),
    );

    expect(find.text('2 files'), findsOneWidget);
    expect(find.text('+11 -3'), findsOneWidget);
    expect(find.text('View diff'), findsNWidgets(2));
    expect(find.text('Show diff'), findsNothing);

    await tester.tap(
      find.text(
        'lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'diff --git a/lib/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart',
      ),
      findsOneWidget,
    );
    expect(find.text('+8 additions'), findsOneWidget);
    expect(find.text('-2 deletions'), findsOneWidget);
    expect(find.text('+new card'), findsOneWidget);
  });

  testWidgets('does not attach a single patch to unrelated file rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexChangedFilesBlock(
            id: 'diff_unmatched_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <CodexChangedFile>[
              CodexChangedFile(path: 'README.md'),
              CodexChangedFile(
                path: 'lib/app.dart',
                additions: 1,
                deletions: 1,
              ),
            ],
            unifiedDiff:
                'diff --git a/lib/app.dart b/lib/app.dart\n'
                '--- a/lib/app.dart\n'
                '+++ b/lib/app.dart\n'
                '@@ -1 +1 @@\n'
                '-old\n'
                '+new\n',
          ),
        ),
      ),
    );

    expect(find.text('View diff'), findsOneWidget);
    expect(find.text('No patch'), findsOneWidget);
    expect(find.text('README.md'), findsOneWidget);
  });

  testWidgets('matches renamed files by old-path aliases', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexChangedFilesBlock(
            id: 'diff_rename_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <CodexChangedFile>[
              CodexChangedFile(path: 'lib/old_name.dart'),
            ],
            unifiedDiff:
                'diff --git a/lib/old_name.dart b/lib/new_name.dart\n'
                'similarity index 88%\n'
                'rename from lib/old_name.dart\n'
                'rename to lib/new_name.dart\n'
                '--- a/lib/old_name.dart\n'
                '+++ b/lib/new_name.dart\n'
                '@@ -1 +1 @@\n'
                '-oldName();\n'
                '+newName();\n',
          ),
        ),
      ),
    );

    expect(find.text('View diff'), findsOneWidget);
    expect(find.text('No patch'), findsNothing);

    await tester.tap(find.text('lib/old_name.dart'));
    await tester.pumpAndSettle();

    expect(find.text('renamed'), findsOneWidget);
    expect(find.text('+1 additions'), findsOneWidget);
    expect(find.text('-1 deletions'), findsOneWidget);
    expect(find.text('+newName();'), findsOneWidget);
  });

  testWidgets('derives file rows from diff-only payloads without git headers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexChangedFilesBlock(
            id: 'diff_only_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            unifiedDiff:
                '--- a/lib/first.dart\n'
                '+++ b/lib/first.dart\n'
                '@@ -1 +1 @@\n'
                '-old first\n'
                '+new first\n'
                '--- a/lib/second.dart\n'
                '+++ b/lib/second.dart\n'
                '@@ -2 +2 @@\n'
                '-old second\n'
                '+new second\n',
          ),
        ),
      ),
    );

    expect(find.text('2 files'), findsOneWidget);
    expect(find.text('+2 -2'), findsOneWidget);
    expect(find.text('lib/first.dart'), findsOneWidget);
    expect(find.text('lib/second.dart'), findsOneWidget);
    expect(find.text('View diff'), findsNWidgets(2));

    await tester.tap(find.text('lib/second.dart'));
    await tester.pumpAndSettle();

    expect(find.text('+new second'), findsOneWidget);
    expect(find.text('-old second'), findsOneWidget);
  });

  testWidgets('shows a bounded preview for very large diffs', (tester) async {
    final diffLines = <String>[
      'diff --git a/lib/large.dart b/lib/large.dart',
      '--- a/lib/large.dart',
      '+++ b/lib/large.dart',
      '@@ -1,0 +1,360 @@',
      for (var index = 0; index < 360; index += 1) '+line $index',
    ];

    await tester.pumpWidget(
      _buildTestApp(
        child: ConversationEntryCard(
          block: CodexChangedFilesBlock(
            id: 'diff_large_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <CodexChangedFile>[
              CodexChangedFile(path: 'lib/large.dart', additions: 360),
            ],
            unifiedDiff: diffLines.join('\n'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('lib/large.dart'));
    await tester.pumpAndSettle();

    expect(find.text('Load full diff'), findsOneWidget);
    expect(
      find.text('Showing the first 320 lines to keep the sheet responsive.'),
      findsOneWidget,
    );
    expect(find.text('+line 315'), findsOneWidget);
    expect(find.text('+line 359'), findsNothing);

    await tester.tap(find.text('Load full diff'));
    await tester.pumpAndSettle();

    expect(find.text('Show preview'), findsOneWidget);
    expect(find.text('+line 359'), findsOneWidget);
  });
}

Widget _buildTestApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    darkTheme: buildPocketTheme(Brightness.dark),
    themeMode: themeMode,
    home: Scaffold(body: child),
  );
}

TextStyle? _findStyleForText(WidgetTester tester, String text) {
  for (final widget in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  )) {
    final span = widget.textSpan;
    if (span == null) {
      continue;
    }
    final style = _styleForInlineText(span, text);
    if (style != null) {
      return style;
    }
  }

  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    final style = _styleForInlineText(widget.text, text);
    if (style != null) {
      return style;
    }
  }

  return null;
}

Color? _findDecoratedContainerColorForText(WidgetTester tester, String text) {
  for (final container in tester.widgetList<Container>(
    find.ancestor(of: find.text(text), matching: find.byType(Container)),
  )) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
    }
  }

  return null;
}

TextStyle? _styleForInlineText(
  InlineSpan span,
  String text, [
  TextStyle? inheritedStyle,
]) {
  if (span is! TextSpan) {
    return null;
  }

  final mergedStyle = inheritedStyle?.merge(span.style) ?? span.style;

  if ((span.text ?? '').contains(text)) {
    return mergedStyle;
  }

  for (final child in span.children ?? const <InlineSpan>[]) {
    final childStyle = _styleForInlineText(child, text, mergedStyle);
    if (childStyle != null) {
      return childStyle;
    }
  }

  return null;
}
