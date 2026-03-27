import 'package:pocket_relay/src/core/theme/pocket_typography.dart';
import 'ui_block_surface_test_support.dart';

void main() {
  testWidgets('renders reasoning blocks with markdown text', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
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
    expect(
      findDecoratedContainerColorForText(
        tester,
        'Investigating the next step.',
      ),
      isNull,
    );
  });

  testWidgets('renders code fences with readable text in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        themeMode: ThemeMode.dark,
        child: entrySurface(
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

    final codeStyle = findStyleForText(tester, 'final answer = 42;');

    expect(codeStyle, isNotNull);
    expect(codeStyle?.color, const Color(0xFFE7F3F4));
    expect(codeStyle?.fontFamily, PocketFontFamilies.monospace);
    expect(
      findDecoratedContainerColorForText(tester, 'final answer = 42;'),
      const Color(0xFF0A1314),
    );
  });

  testWidgets('renders inline code with monospace styling', (tester) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: CodexTextBlock(
            id: 'assistant_inline_code_1',
            kind: CodexUiBlockKind.assistantMessage,
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Assistant',
            body: 'Use `dart test` before shipping.',
          ),
        ),
      ),
    );

    final inlineCodeStyle = findStyleForText(tester, 'dart test');

    expect(inlineCodeStyle, isNotNull);
    expect(inlineCodeStyle?.fontFamily, PocketFontFamilies.monospace);
    expect(inlineCodeStyle?.backgroundColor, const Color(0xFFE8E0CF));
  });

  testWidgets(
    'renders context-compaction blocks as dedicated transcript surfaces',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: entrySurface(
            block: CodexStatusBlock(
              id: 'status_1',
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Context compacted',
              body: 'Older transcript context was compacted upstream.',
              statusKind: CodexStatusBlockKind.compaction,
            ),
          ),
        ),
      );

      expect(find.byType(ContextCompactedSurface), findsOneWidget);
      expect(find.text('Context compacted'), findsOneWidget);
      expect(
        find.text('Older transcript context was compacted upstream.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders review status blocks as dedicated transcript surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: CodexStatusBlock(
            id: 'status_review_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Review started',
            body: 'Checking the patch set',
            statusKind: CodexStatusBlockKind.review,
          ),
        ),
      ),
    );

    expect(find.byType(ReviewStatusSurface), findsOneWidget);
    expect(find.text('Review started'), findsOneWidget);
    expect(find.text('Checking the patch set'), findsOneWidget);
  });

  testWidgets('renders session info blocks as dedicated transcript surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: CodexStatusBlock(
            id: 'status_info_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'New thread',
            body: 'Resume the previous task.',
            statusKind: CodexStatusBlockKind.info,
            isTranscriptSignal: true,
          ),
        ),
      ),
    );

    expect(find.byType(SessionInfoSurface), findsOneWidget);
    expect(find.text('New thread'), findsOneWidget);
    expect(find.text('Resume the previous task.'), findsOneWidget);
  });

  testWidgets('renders warning blocks as dedicated transcript surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: CodexStatusBlock(
            id: 'status_warning_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Warning',
            body: 'The command exceeded the preferred timeout.',
            statusKind: CodexStatusBlockKind.warning,
          ),
        ),
      ),
    );

    expect(find.byType(WarningEventSurface), findsOneWidget);
    expect(find.text('Warning'), findsOneWidget);
    expect(
      find.text('The command exceeded the preferred timeout.'),
      findsOneWidget,
    );
  });

  testWidgets('renders deprecation notices as dedicated transcript surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: CodexStatusBlock(
            id: 'status_deprecation_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Deprecation notice',
            body: 'This event family will be removed soon.',
            statusKind: CodexStatusBlockKind.warning,
          ),
        ),
      ),
    );

    expect(find.byType(DeprecationNoticeSurface), findsOneWidget);
    expect(find.text('Deprecation notice'), findsOneWidget);
    expect(
      find.text('This event family will be removed soon.'),
      findsOneWidget,
    );
  });

  testWidgets('renders error blocks as flat transcript annotations', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: CodexErrorBlock(
            id: 'error_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Patch apply failed',
            body: 'The patch could not be applied cleanly.',
          ),
        ),
      ),
    );

    expect(find.byType(PatchApplyFailureSurface), findsOneWidget);
    expect(find.text('Patch apply failed'), findsOneWidget);
    expect(
      find.text('The patch could not be applied cleanly.'),
      findsOneWidget,
    );
    expect(
      findDecoratedContainerColorForText(
        tester,
        'The patch could not be applied cleanly.',
      ),
      isNull,
    );
  });

  testWidgets('renders plan updates as flat transcript annotations', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildTestApp(
        child: entrySurface(
          block: CodexPlanUpdateBlock(
            id: 'plan_update_1',
            createdAt: DateTime(2026, 3, 14, 12),
            explanation: 'Updated the execution sequence.',
            steps: const <CodexRuntimePlanStep>[
              CodexRuntimePlanStep(
                step: 'Inspect the existing transcript item hierarchy.',
                status: CodexRuntimePlanStepStatus.completed,
              ),
              CodexRuntimePlanStep(
                step: 'Replace framed transcript annotations.',
                status: CodexRuntimePlanStepStatus.inProgress,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Updated Plan'), findsOneWidget);
    expect(find.text('Updated the execution sequence.'), findsOneWidget);
    expect(
      find.text('Inspect the existing transcript item hierarchy.'),
      findsOneWidget,
    );
    expect(find.text('Replace framed transcript annotations.'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(
      findDecoratedContainerColorForText(
        tester,
        'Updated the execution sequence.',
      ),
      isNull,
    );
  });

  testWidgets(
    'keeps reasoning flat while retaining changed-files surface in dark mode',
    (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          themeMode: ThemeMode.dark,
          child: Column(
            children: [
              entrySurface(
                block: CodexTextBlock(
                  id: 'reasoning_dark_1',
                  kind: CodexUiBlockKind.reasoning,
                  createdAt: DateTime(2026, 3, 14, 12),
                  title: 'Reasoning',
                  body: 'Dark mode should use the themed surface.',
                ),
              ),
              const SizedBox(height: 16),
              entrySurface(
                block: CodexChangedFilesBlock(
                  id: 'files_dark_1',
                  createdAt: DateTime(2026, 3, 14, 12),
                  title: 'Changed files',
                  files: <CodexChangedFile>[
                    const CodexChangedFile(
                      path:
                          'lib/src/features/chat/presentation/widgets/foo.dart',
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

      expect(findDecoratedContainerColorForText(tester, 'Reasoning'), isNull);
      expect(
        findDecoratedContainerColorForText(tester, 'Changed files'),
        isNull,
      );
    },
  );
}
