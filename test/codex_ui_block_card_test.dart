import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/conversation_entry_card.dart';

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

    expect(find.text('Thread token usage'), findsOneWidget);
    expect(find.text('ctx 258400'), findsOneWidget);
    expect(find.text('last'), findsOneWidget);
    expect(find.text('total'), findsOneWidget);
    expect(find.text('input 10946'), findsOneWidget);
    expect(find.text('output 910'), findsOneWidget);
  });

  testWidgets('collapses duplicate thread token usage sections', (tester) async {
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

    expect(find.text('last'), findsNothing);
    expect(find.text('total'), findsNothing);
    expect(find.text('input 12'), findsOneWidget);
    expect(find.text('cached 3'), findsOneWidget);
    expect(find.text('output 7'), findsOneWidget);
  });

  testWidgets('renders changed files summary and diff toggle', (tester) async {
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
                    'lib/src/features/chat/widgets/conversation_entry_card.dart',
                additions: 8,
                deletions: 2,
              ),
            ],
            unifiedDiff:
                'diff --git a/lib/main.dart b/lib/main.dart\n'
                '--- a/lib/main.dart\n'
                '+++ b/lib/main.dart\n'
                '@@ -1 +1 @@\n'
                '-old\n'
                '+new\n',
          ),
        ),
      ),
    );

    expect(find.text('2 files'), findsOneWidget);
    expect(find.text('+11 -3'), findsOneWidget);
    expect(find.text('Show diff'), findsOneWidget);

    await tester.tap(find.text('Show diff'));
    await tester.pumpAndSettle();

    expect(find.text('Hide diff'), findsOneWidget);
    expect(find.textContaining('diff --git a/lib/main.dart'), findsOneWidget);
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
