import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/presentation/chat_transcript_item_projector.dart';
import 'package:pocket_relay/src/features/chat/presentation/pending_user_input_form_scope.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/conversation_entry_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/changed_files_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/cards/turn_boundary_card.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/support/turn_elapsed_footer.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/transcript/transcript_list.dart';

const _itemProjector = ChatTranscriptItemProjector();
const _defaultFollowBehavior = ChatTranscriptFollowContract(
  isAutoFollowEnabled: true,
  resumeDistance: 72,
);

void main() {
  testWidgets('renders reasoning blocks with markdown text', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entryCard(
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
        child: _entryCard(
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
            _entryCard(
              block: CodexTextBlock(
                id: 'reasoning_dark_1',
                kind: CodexUiBlockKind.reasoning,
                createdAt: DateTime(2026, 3, 14, 12),
                title: 'Reasoning',
                body: 'Dark mode should use the themed surface.',
              ),
            ),
            const SizedBox(height: 16),
            _entryCard(
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
        child: _entryCard(
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

    expect(find.text('Plain assistant transcript.'), findsOneWidget);
    expect(
      _findDecoratedContainerColorForText(
        tester,
        'Plain assistant transcript.',
      ),
      isNull,
    );
  });

  testWidgets(
    'renders user messages without header labels and with distinct bubble states',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Column(
            children: [
              _entryCard(
                block: CodexUserMessageBlock(
                  id: 'user_local_1',
                  createdAt: DateTime(2026, 3, 14, 12),
                  text: 'Draft prompt',
                  deliveryState: CodexUserMessageDeliveryState.localEcho,
                ),
              ),
              const SizedBox(height: 16),
              _entryCard(
                block: CodexUserMessageBlock(
                  id: 'user_session_1',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                  text: 'Delivered prompt',
                  deliveryState: CodexUserMessageDeliveryState.sent,
                ),
              ),
            ],
          ),
        ),
      );

      expect(find.text('You'), findsNothing);
      expect(find.text('local echo'), findsNothing);
      expect(find.text('sent'), findsNothing);
      expect(find.text('Draft prompt'), findsOneWidget);
      expect(find.text('Delivered prompt'), findsOneWidget);

      final localBubble = _findDecoratedContainerColorForText(
        tester,
        'Draft prompt',
      );
      final sentBubble = _findDecoratedContainerColorForText(
        tester,
        'Delivered prompt',
      );

      expect(localBubble, isNotNull);
      expect(sentBubble, isNotNull);
      expect(localBubble, isNot(equals(sentBubble)));
      expect(
        _findStyleForText(tester, 'Delivered prompt')?.color,
        const Color(0xFF1C1917),
      );
    },
  );

  testWidgets('uses readable user message text in dark mode', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        themeMode: ThemeMode.dark,
        child: _entryCard(
          block: CodexUserMessageBlock(
            id: 'user_dark_1',
            createdAt: DateTime(2026, 3, 14, 12),
            text: 'Dark prompt',
            deliveryState: CodexUserMessageDeliveryState.sent,
          ),
        ),
      ),
    );

    expect(
      _findStyleForText(tester, 'Dark prompt')?.color,
      const Color(0xFFF4F2ED),
    );
  });

  testWidgets('renders a live elapsed footer as a standalone widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: TurnElapsedFooter(
          turnTimer: CodexSessionTurnTimer(
            turnId: 'turn_live',
            startedAt: DateTime.now().subtract(const Duration(seconds: 5)),
          ),
        ),
      ),
    );

    expect(find.textContaining('Elapsed'), findsOneWidget);
  });

  testWidgets('renders a completed elapsed footer as a standalone widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: TurnElapsedFooter(
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

  testWidgets('renders approval request actions', (tester) async {
    String? approvedRequestId;

    await tester.pumpWidget(
      _buildTestApp(
        child: _entryCard(
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
        activeRequestIds: const <String>{'input_1'},
        child: _entryCard(
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
    'routes user-input option chips through the shared request draft state',
    (tester) async {
      Map<String, List<String>>? submittedAnswers;

      await tester.pumpWidget(
        _buildTestApp(
          activeRequestIds: const <String>{'input_1'},
          child: _entryCard(
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
                  options: <CodexRuntimeUserInputOption>[
                    CodexRuntimeUserInputOption(
                      label: 'Pocket Relay',
                      description: 'Use the mobile app project.',
                    ),
                  ],
                ),
              ],
            ),
            onSubmitUserInput: (_, answers) async {
              submittedAnswers = answers;
            },
          ),
        ),
      );

      await tester.tap(find.text('Pocket Relay'));
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Pocket Relay');

      await tester.tap(find.text('Submit response'));
      await tester.pump();

      expect(submittedAnswers, <String, List<String>>{
        'q1': <String>['Pocket Relay'],
      });
    },
  );

  testWidgets('resyncs user-input fields when the backing request changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        activeRequestIds: const <String>{'input_1'},
        child: _entryCard(
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
        activeRequestIds: const <String>{'input_2'},
        child: _entryCard(
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
    'preserves user-input drafts when a request moves within the transcript surface',
    (tester) async {
      final block = CodexUserInputRequestBlock(
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
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: TranscriptList(
            surface: _surfaceContract(mainItems: <CodexUiBlock>[block]),
            followBehavior: _defaultFollowBehavior,
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'main',
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Pocket Relay');
      await tester.pump();

      await tester.pumpWidget(
        _buildTestApp(
          child: TranscriptList(
            surface: _surfaceContract(pinnedItems: <CodexUiBlock>[block]),
            followBehavior: _defaultFollowBehavior,
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'pinned',
          ),
        ),
      );
      await tester.pump();

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, 'Pocket Relay');
    },
  );

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
            child: _entryCard(
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
            surface: _surfaceContract(
              mainItems: <CodexUiBlock>[
                CodexProposedPlanBlock(
                  id: 'plan_1',
                  createdAt: DateTime(2026, 3, 14, 12),
                  title: 'Proposed plan',
                  markdown: markdownLines.join('\n'),
                ),
              ],
            ),
            followBehavior: _defaultFollowBehavior,
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'plan_1',
          ),
        ),
      );

      await tester.tap(find.text('Expand plan'));
      await tester.pumpAndSettle();
      expect(find.text('Collapse plan'), findsOneWidget);

      await tester.pumpWidget(
        _buildTestApp(
          child: TranscriptList(
            surface: _surfaceContract(
              mainItems: <CodexUiBlock>[
                CodexProposedPlanBlock(
                  id: 'plan_2',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 5),
                  title: 'Proposed plan',
                  markdown: markdownLines.join('\n'),
                ),
              ],
            ),
            followBehavior: _defaultFollowBehavior,
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'plan_2',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Expand plan'), findsOneWidget);
      expect(find.text('Collapse plan'), findsNothing);
    },
  );

  testWidgets(
    'routes follow eligibility and follow requests through the transcript contract',
    (tester) async {
      bool? isNearBottom;
      final blocks = List<CodexUiBlock>.generate(
        24,
        (index) => CodexTextBlock(
          id: 'assistant_$index',
          kind: CodexUiBlockKind.assistantMessage,
          createdAt: DateTime(2026, 3, 14, 12, 0, index),
          title: 'Codex',
          body: 'Assistant message $index',
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: TranscriptList(
            surface: _surfaceContract(mainItems: blocks),
            followBehavior: _defaultFollowBehavior,
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (value) {
              isNearBottom = value;
            },
            surfaceChangeToken: 'initial',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableState = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollableState.position.jumpTo(scrollableState.position.maxScrollExtent);
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, 320));
      await tester.pumpAndSettle();

      expect(isNearBottom, isFalse);
      expect(
        scrollableState.position.pixels,
        lessThan(scrollableState.position.maxScrollExtent),
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: TranscriptList(
            surface: _surfaceContract(mainItems: blocks),
            followBehavior: _followBehavior(
              requestId: 1,
              source: ChatTranscriptFollowRequestSource.sendPrompt,
            ),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (value) {
              isNearBottom = value;
            },
            surfaceChangeToken: 'initial',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        scrollableState.position.pixels,
        closeTo(scrollableState.position.maxScrollExtent, 1),
      );
    },
  );

  testWidgets('renders compact work-log groups with normalized labels', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entryCard(
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
        child: _entryCard(
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
    expect(find.text('current'), findsAtLeastNWidgets(1));
    expect(find.text('total'), findsAtLeastNWidgets(1));
    expect(find.text('in'), findsOneWidget);
    expect(find.text('cache'), findsOneWidget);
    expect(find.text('out'), findsOneWidget);
    expect(find.text('rsn'), findsOneWidget);
    expect(find.text('all'), findsOneWidget);
    expect(find.text('1.7k'), findsOneWidget);
    expect(find.text('2.2k'), findsOneWidget);
    expect(find.text('9.2k'), findsOneWidget);
    expect(find.text('288'), findsOneWidget);
    expect(find.text('18.2k'), findsOneWidget);
    expect(find.text('422'), findsOneWidget);
    expect(find.text('488'), findsOneWidget);
    expect(find.text('4.6k'), findsOneWidget);
  });

  testWidgets(
    'renders duplicate thread token usage as current and total rows',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: _entryCard(
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

      expect(find.text('current'), findsAtLeastNWidgets(1));
      expect(find.text('total'), findsAtLeastNWidgets(1));
      expect(find.text('in'), findsOneWidget);
      expect(find.text('cache'), findsOneWidget);
      expect(find.text('out'), findsOneWidget);
      expect(find.text('rsn'), findsOneWidget);
      expect(find.text('all'), findsOneWidget);
      expect(find.text('9'), findsNWidgets(2));
      expect(find.text('3'), findsNWidgets(2));
      expect(find.text('7'), findsNWidgets(2));
      expect(find.text('16'), findsNWidgets(2));
      expect(find.text('-'), findsNWidgets(2));
    },
  );

  testWidgets('renders turn completion as a compact separator', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entryCard(
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
        child: _entryCard(
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

  testWidgets('renders deferred thread usage inside the turn completion card', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entryCard(
          block: CodexTurnBoundaryBlock(
            id: 'turn_end_usage_1',
            createdAt: DateTime(2026, 3, 14, 12),
            usage: CodexUsageBlock(
              id: 'usage_embedded_1',
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Thread token usage',
              body: 'Last: input 12 | Total: input 24\nContext window: 200000',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Thread usage'), findsOneWidget);
    expect(find.text('ctx 200k'), findsOneWidget);
    expect(find.text('end'), findsOneWidget);
  });

  testWidgets('keeps the turn completion separator flush on wide layouts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTestApp(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 1200,
            child: _entryCard(
              block: CodexTurnBoundaryBlock(
                id: 'turn_end_flush_1',
                createdAt: DateTime(2026, 3, 14, 12),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(TurnBoundaryCard.separatorRowKey)).width,
      1200,
    );
  });

  testWidgets('renders a live elapsed footer with the current duration', (
    tester,
  ) async {
    final startedAt = DateTime.now().subtract(const Duration(seconds: 5));

    await tester.pumpWidget(
      _buildTestApp(
        child: TurnElapsedFooter(
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
        child: _entryCard(
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
        child: _entryCard(
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

  testWidgets(
    'routes changed-file diff opening through the callback boundary',
    (tester) async {
      ChatChangedFileDiffContract? openedDiff;

      await tester.pumpWidget(
        _buildTestApp(
          child: _entryCard(
            block: CodexChangedFilesBlock(
              id: 'diff_callback_1',
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Changed files',
              files: const <CodexChangedFile>[
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
            onOpenChangedFileDiff: (diff) {
              openedDiff = diff;
            },
          ),
        ),
      );

      await tester.tap(find.text('lib/app.dart'));
      await tester.pump();

      expect(openedDiff, isNotNull);
      expect(openedDiff?.displayPathLabel, 'lib/app.dart');
      expect(openedDiff?.stats.additions, 1);
      expect(openedDiff?.stats.deletions, 1);
      expect(find.text('+new'), findsNothing);
    },
  );

  testWidgets('matches renamed files by old-path aliases', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entryCard(
          block: CodexChangedFilesBlock(
            id: 'diff_rename_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <CodexChangedFile>[
              CodexChangedFile(path: 'lib/new_name.dart'),
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
    expect(find.text('lib/old_name.dart -> lib/new_name.dart'), findsOneWidget);

    await tester.tap(find.text('lib/old_name.dart -> lib/new_name.dart'));
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
        child: _entryCard(
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
        child: _entryCard(
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

ChatTranscriptSurfaceContract _surfaceContract({
  bool isConfigured = true,
  List<CodexUiBlock> mainItems = const <CodexUiBlock>[],
  List<CodexUiBlock> pinnedItems = const <CodexUiBlock>[],
  ChatEmptyStateContract? emptyState,
}) {
  return ChatTranscriptSurfaceContract(
    isConfigured: isConfigured,
    mainItems: mainItems.map(_itemProjector.project).toList(growable: false),
    pinnedItems: pinnedItems
        .map(_itemProjector.project)
        .toList(growable: false),
    emptyState: emptyState,
  );
}

ChatTranscriptFollowContract _followBehavior({
  bool isAutoFollowEnabled = true,
  int? requestId,
  ChatTranscriptFollowRequestSource source =
      ChatTranscriptFollowRequestSource.sendPrompt,
}) {
  return ChatTranscriptFollowContract(
    isAutoFollowEnabled: isAutoFollowEnabled,
    resumeDistance: 72,
    request: requestId == null
        ? null
        : ChatTranscriptFollowRequestContract(id: requestId, source: source),
  );
}

Widget _entryCard({
  Key? key,
  required CodexUiBlock block,
  Future<void> Function(String requestId)? onApproveRequest,
  Future<void> Function(String requestId)? onDenyRequest,
  void Function(ChatChangedFileDiffContract diff)? onOpenChangedFileDiff,
  Future<void> Function(String requestId, Map<String, List<String>> answers)?
  onSubmitUserInput,
}) {
  return Builder(
    builder: (context) {
      return ConversationEntryCard(
        key: key,
        item: _itemProjector.project(block),
        onApproveRequest: onApproveRequest,
        onDenyRequest: onDenyRequest,
        onOpenChangedFileDiff:
            onOpenChangedFileDiff ??
            (diff) {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (context) => ChangedFileDiffSheet(diff: diff),
              );
            },
        onSubmitUserInput: onSubmitUserInput,
      );
    },
  );
}

Widget _buildTestApp({
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
  Set<String> activeRequestIds = const <String>{},
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    darkTheme: buildPocketTheme(Brightness.dark),
    themeMode: themeMode,
    home: Scaffold(
      body: PendingUserInputFormScope(
        activeRequestIds: activeRequestIds,
        child: child,
      ),
    ),
  );
}

TextStyle? _findStyleForText(WidgetTester tester, String text) {
  for (final widget in tester.widgetList<SelectableText>(
    find.byType(SelectableText),
  )) {
    if (widget.data == text) {
      return widget.style;
    }

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
  final selectableTextFinder = find.byWidgetPredicate(
    (widget) => widget is SelectableText && widget.data == text,
  );
  if (selectableTextFinder.evaluate().isNotEmpty) {
    for (final container in tester.widgetList<Container>(
      find.ancestor(of: selectableTextFinder, matching: find.byType(Container)),
    )) {
      final decoration = container.decoration;
      if (decoration is BoxDecoration && decoration.color != null) {
        return decoration.color;
      }
    }
  }

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
