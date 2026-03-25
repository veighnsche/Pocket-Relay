import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/platform/pocket_platform_behavior.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_session_state.dart';
import 'package:pocket_relay/src/features/chat/transcript/domain/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/worklog/application/chat_changed_files_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_pending_request_placement_contract.dart';
import 'package:pocket_relay/src/features/chat/lane/presentation/chat_screen_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript_follow/presentation/chat_transcript_follow_contract.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/chat_transcript_item_projector.dart';
import 'package:pocket_relay/src/features/chat/requests/presentation/pending_user_input_form_scope.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/alert_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/approval_decision_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart';
import 'package:pocket_relay/src/features/chat/worklog/presentation/widgets/changed_files_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/session_status_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/turn_boundary_marker.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/surfaces/user_input_result_surface.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/support/turn_elapsed_footer.dart';
import 'package:pocket_relay/src/features/chat/transcript/presentation/widgets/transcript/transcript_list.dart';

const _itemProjector = ChatTranscriptItemProjector();
const _defaultFollowBehavior = ChatTranscriptFollowContract(
  isAutoFollowEnabled: true,
  resumeDistance: 72,
);

void main() {
  testWidgets('renders reasoning blocks with markdown text', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entrySurface(
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
      _findDecoratedContainerColorForText(
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
      _buildTestApp(
        themeMode: ThemeMode.dark,
        child: _entrySurface(
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
    expect(codeStyle?.fontFamily, 'monospace');
    expect(
      _findDecoratedContainerColorForText(tester, 'final answer = 42;'),
      const Color(0xFF0A1314),
    );
  });

  testWidgets('renders inline code with monospace styling', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entrySurface(
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

    final inlineCodeStyle = _findStyleForText(tester, 'dart test');

    expect(inlineCodeStyle, isNotNull);
    expect(inlineCodeStyle?.fontFamily, 'monospace');
    expect(inlineCodeStyle?.backgroundColor, const Color(0xFFE8E0CF));
  });

  testWidgets(
    'renders context-compaction blocks as dedicated transcript surfaces',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: _entrySurface(
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
      _buildTestApp(
        child: _entrySurface(
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
      _buildTestApp(
        child: _entrySurface(
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
      _buildTestApp(
        child: _entrySurface(
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
      _buildTestApp(
        child: _entrySurface(
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
      _buildTestApp(
        child: _entrySurface(
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
      _findDecoratedContainerColorForText(
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
      _buildTestApp(
        child: _entrySurface(
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
      _findDecoratedContainerColorForText(
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
        _buildTestApp(
          themeMode: ThemeMode.dark,
          child: Column(
            children: [
              _entrySurface(
                block: CodexTextBlock(
                  id: 'reasoning_dark_1',
                  kind: CodexUiBlockKind.reasoning,
                  createdAt: DateTime(2026, 3, 14, 12),
                  title: 'Reasoning',
                  body: 'Dark mode should use the themed surface.',
                ),
              ),
              const SizedBox(height: 16),
              _entrySurface(
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

      expect(_findDecoratedContainerColorForText(tester, 'Reasoning'), isNull);
      expect(
        _findDecoratedContainerColorForText(tester, 'Changed files'),
        isNull,
      );
    },
  );

  testWidgets(
    'renders assistant messages without a decorated transcript shell',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: _entrySurface(
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
    },
  );

  testWidgets(
    'renders user messages without header labels and with distinct bubble states',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: Column(
            children: [
              _entrySurface(
                block: CodexUserMessageBlock(
                  id: 'user_local_1',
                  createdAt: DateTime(2026, 3, 14, 12),
                  text: 'Draft prompt',
                  deliveryState: CodexUserMessageDeliveryState.localEcho,
                ),
              ),
              const SizedBox(height: 16),
              _entrySurface(
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
        child: _entrySurface(
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
        child: _entrySurface(
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

  testWidgets('routes resolved approvals through the decision surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entrySurface(
          block: CodexApprovalRequestBlock(
            id: 'request_resolved_1',
            createdAt: DateTime(2026, 3, 14, 12),
            requestId: 'request_resolved_1',
            requestType: CodexCanonicalRequestType.fileChangeApproval,
            title: 'File change approval resolved',
            body: 'Codex received approval for this request.',
            isResolved: true,
            resolutionLabel: 'approved',
          ),
        ),
      ),
    );

    expect(find.byType(ApprovalDecisionSurface), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.text('approved'), findsOneWidget);
  });

  testWidgets(
    'renders the unpinned host key SSH surface with save and settings actions',
    (tester) async {
      String? savedBlockId;
      var openedSettings = 0;

      await tester.pumpWidget(
        _buildTestApp(
          child: _entrySurface(
            block: CodexSshUnpinnedHostKeyBlock(
              id: 'ssh_unpinned_1',
              createdAt: DateTime(2026, 3, 14, 12),
              host: 'example.com',
              port: 22,
              keyType: 'ssh-ed25519',
              fingerprint: 'aa:bb:cc:dd',
            ),
            onSaveHostFingerprint: (blockId) async {
              savedBlockId = blockId;
            },
            onConfigure: () {
              openedSettings += 1;
            },
          ),
        ),
      );

      expect(find.text('Host key not pinned'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('save_host_fingerprint')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('host_fingerprint_value')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('open_connection_settings')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('save_host_fingerprint')));
      await tester.pump();

      expect(openedSettings, 1);
      expect(savedBlockId, 'ssh_unpinned_1');
    },
  );

  testWidgets('renders the connect failure SSH surface with settings only', (
    tester,
  ) async {
    var openedSettings = 0;

    await tester.pumpWidget(
      _buildTestApp(
        child: _entrySurface(
          block: CodexSshConnectFailedBlock(
            id: 'ssh_connect_1',
            createdAt: DateTime(2026, 3, 14, 12),
            host: 'example.com',
            port: 22,
            message: 'Connection refused',
          ),
          onConfigure: () {
            openedSettings += 1;
          },
        ),
      ),
    );

    expect(find.text('SSH connection failed'), findsOneWidget);
    expect(find.text('Connection refused'), findsOneWidget);
    expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open_connection_settings')));
    await tester.pump();

    expect(openedSettings, 1);
  });

  testWidgets(
    'renders the host key mismatch SSH surface without save affordances',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: _entrySurface(
            block: CodexSshHostKeyMismatchBlock(
              id: 'ssh_mismatch_1',
              createdAt: DateTime(2026, 3, 14, 12),
              host: 'example.com',
              port: 22,
              keyType: 'ssh-ed25519',
              expectedFingerprint: 'aa:bb:cc:dd',
              actualFingerprint: '11:22:33:44',
            ),
            onConfigure: () {},
          ),
        ),
      );

      expect(find.text('SSH host key mismatch'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('expected_host_fingerprint_value')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('observed_host_fingerprint_value')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
      expect(
        find.byKey(const ValueKey('open_connection_settings')),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders the auth failure SSH surface with settings only', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entrySurface(
          block: CodexSshAuthenticationFailedBlock(
            id: 'ssh_auth_1',
            createdAt: DateTime(2026, 3, 14, 12),
            host: 'example.com',
            port: 22,
            username: 'vince',
            authMode: AuthMode.privateKey,
            message: 'Permission denied',
          ),
          onConfigure: () {},
        ),
      ),
    );

    expect(find.text('SSH authentication failed'), findsOneWidget);
    expect(find.textContaining('private key'), findsWidgets);
    expect(find.text('Permission denied'), findsOneWidget);
    expect(find.byKey(const ValueKey('save_host_fingerprint')), findsNothing);
    expect(
      find.byKey(const ValueKey('open_connection_settings')),
      findsOneWidget,
    );
  });

  testWidgets('renders user-input fields and submits answers', (tester) async {
    String? submittedRequestId;
    Map<String, List<String>>? submittedAnswers;

    await tester.pumpWidget(
      _buildTestApp(
        activeRequestIds: const <String>{'input_1'},
        child: _entrySurface(
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
          child: _entrySurface(
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
        child: _entrySurface(
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
        child: _entrySurface(
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

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Workspace'), findsNothing);
    expect(find.text('Project'), findsNothing);
  });

  testWidgets(
    'routes resolved user-input requests through the result surface',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: _entrySurface(
            block: CodexUserInputRequestBlock(
              id: 'input_resolved_1',
              createdAt: DateTime(2026, 3, 14, 12),
              requestId: 'input_resolved_1',
              requestType: CodexCanonicalRequestType.toolUserInput,
              title: 'Input submitted',
              body: 'Project: Pocket Relay',
              isResolved: true,
              answers: <String, List<String>>{
                'project': <String>['Pocket Relay'],
              },
            ),
          ),
        ),
      );

      expect(find.byType(UserInputResultSurface), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('submitted'), findsOneWidget);
    },
  );

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
            platformBehavior: PocketPlatformBehavior.resolve(),
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
            platformBehavior: PocketPlatformBehavior.resolve(),
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
    'does not leak pending-user-input drafts when visibility promotes to the next request',
    (tester) async {
      final firstBlock = CodexUserInputRequestBlock(
        id: 'input_1',
        createdAt: DateTime(2026, 3, 14, 12),
        requestId: 'input_1',
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'First request',
        questions: const <CodexRuntimeUserInputQuestion>[
          CodexRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Project',
            question: 'Which first project should I use?',
          ),
        ],
      );
      final secondBlock = CodexUserInputRequestBlock(
        id: 'input_2',
        createdAt: DateTime(2026, 3, 14, 12, 0, 1),
        requestId: 'input_2',
        requestType: CodexCanonicalRequestType.toolUserInput,
        title: 'Input required',
        body: 'Second request',
        questions: const <CodexRuntimeUserInputQuestion>[
          CodexRuntimeUserInputQuestion(
            id: 'q1',
            header: 'Project',
            question: 'Which second project should I use?',
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: TranscriptList(
            surface: _surfaceContract(pinnedItems: <CodexUiBlock>[firstBlock]),
            followBehavior: _defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'first',
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Pocket Relay');
      await tester.pump();

      await tester.pumpWidget(
        _buildTestApp(
          child: TranscriptList(
            surface: _surfaceContract(pinnedItems: <CodexUiBlock>[secondBlock]),
            followBehavior: _defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
            surfaceChangeToken: 'second',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Which first project should I use?'), findsNothing);
      expect(find.text('Which second project should I use?'), findsOneWidget);
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    },
  );

  testWidgets(
    'routes active pending user-input ids through the surface contract',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: TranscriptList(
            surface: _surfaceContract(
              emptyState: const ChatEmptyStateContract(isConfigured: true),
              activePendingUserInputRequestIds: <String>{'input_explicit'},
            ),
            followBehavior: _defaultFollowBehavior,
            platformBehavior: PocketPlatformBehavior.resolve(),
            onConfigure: () {},
            onAutoFollowEligibilityChanged: (_) {},
          ),
        ),
      );

      final scope = tester
          .widgetList<PendingUserInputFormScope>(
            find.byType(PendingUserInputFormScope),
          )
          .last;
      expect(scope.activeRequestIds, <String>{'input_explicit'});
    },
  );

  testWidgets(
    'shows a top-of-transcript limit notice when older items are hidden',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: SizedBox(
            height: 200,
            child: TranscriptList(
              surface: _surfaceContract(
                mainItems: <CodexUiBlock>[
                  CodexTextBlock(
                    id: 'assistant_latest_1',
                    kind: CodexUiBlockKind.assistantMessage,
                    createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                    title: 'Codex',
                    body: 'Latest message 1',
                  ),
                  CodexTextBlock(
                    id: 'assistant_latest_2',
                    kind: CodexUiBlockKind.assistantMessage,
                    createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                    title: 'Codex',
                    body: 'Latest message 2',
                  ),
                ],
                totalMainItemCount: 5,
              ),
              followBehavior: _defaultFollowBehavior,
              platformBehavior: PocketPlatformBehavior.resolve(),
              onConfigure: () {},
              onAutoFollowEligibilityChanged: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.text(
          'Showing the most recent 2 of 5 transcript items. Older activity is not shown in this view.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'does not show a transcript limit notice when nothing is hidden',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: SizedBox(
            height: 200,
            child: TranscriptList(
              surface: _surfaceContract(
                mainItems: <CodexUiBlock>[
                  CodexTextBlock(
                    id: 'assistant_latest_1',
                    kind: CodexUiBlockKind.assistantMessage,
                    createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                    title: 'Codex',
                    body: 'Latest message 1',
                  ),
                ],
              ),
              followBehavior: _defaultFollowBehavior,
              platformBehavior: PocketPlatformBehavior.resolve(),
              onConfigure: () {},
              onAutoFollowEligibilityChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Showing the most recent'), findsNothing);
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
            child: _entrySurface(
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
      expect(
        _findDecoratedContainerColorForText(tester, 'Step 1 for the rollout'),
        isNull,
      );

      await tester.tap(find.text('Expand plan'));
      await tester.pumpAndSettle();

      expect(find.text('Collapse plan'), findsOneWidget);
    },
  );

  testWidgets(
    'keys transcript surfaces by block id so local state does not leak',
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
            platformBehavior: PocketPlatformBehavior.resolve(),
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
            platformBehavior: PocketPlatformBehavior.resolve(),
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
            platformBehavior: PocketPlatformBehavior.resolve(),
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
            platformBehavior: PocketPlatformBehavior.resolve(),
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
        child: _entrySurface(
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

  testWidgets(
    'shows hidden work-log count in the tappable header above visible rows',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: _entrySurface(
            block: CodexWorkLogGroupBlock(
              id: 'worklog_overflow_1',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <CodexWorkLogEntry>[
                CodexWorkLogEntry(
                  id: 'entry_1',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: 'first',
                ),
                CodexWorkLogEntry(
                  id: 'entry_2',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: 'second',
                ),
                CodexWorkLogEntry(
                  id: 'entry_3',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: 'third',
                ),
                CodexWorkLogEntry(
                  id: 'entry_4',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 3),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
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
      _buildTestApp(
        child: _entrySurface(
          block: CodexWorkLogGroupBlock(
            id: 'worklog_web_search',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <CodexWorkLogEntry>[
              CodexWorkLogEntry(
                id: 'entry_web_search',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: CodexWorkLogEntryKind.webSearch,
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
      _buildTestApp(
        child: _entrySurface(
          block: CodexWorkLogGroupBlock(
            id: 'worklog_command',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <CodexWorkLogEntry>[
              CodexWorkLogEntry(
                id: 'entry_command',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: CodexWorkLogEntryKind.commandExecution,
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
        _buildTestApp(
          child: _entrySurface(
            block: CodexWorkLogGroupBlock(
              id: 'worklog_command_wait',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <CodexWorkLogEntry>[
                CodexWorkLogEntry(
                  id: 'entry_command_wait',
                  createdAt: DateTime(2026, 3, 14, 12),
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
      _buildTestApp(
        child: _entrySurface(
          block: CodexWorkLogGroupBlock(
            id: 'worklog_sed',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <CodexWorkLogEntry>[
              CodexWorkLogEntry(
                id: 'entry_sed',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: CodexWorkLogEntryKind.commandExecution,
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
        _buildTestApp(
          child: _entrySurface(
            block: CodexWorkLogGroupBlock(
              id: 'worklog_reads',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <CodexWorkLogEntry>[
                CodexWorkLogEntry(
                  id: 'entry_cat',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: 'cat README.md',
                ),
                CodexWorkLogEntry(
                  id: 'entry_head',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: 'head -n 40 docs/021_codebase-handoff.md',
                ),
                CodexWorkLogEntry(
                  id: 'entry_tail',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: 'tail -20 logs/output.txt',
                ),
                CodexWorkLogEntry(
                  id: 'entry_get_content',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 3),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
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
        _buildTestApp(
          child: _entrySurface(
            block: CodexWorkLogGroupBlock(
              id: 'worklog_more_reads',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <CodexWorkLogEntry>[
                CodexWorkLogEntry(
                  id: 'entry_type',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: r'type C:\repo\README.md',
                ),
                CodexWorkLogEntry(
                  id: 'entry_more',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: 'more docs/021_codebase-handoff.md',
                ),
                CodexWorkLogEntry(
                  id: 'entry_awk',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: "awk 'NR>=5 && NR<=25 {print}' lib/main.dart",
                ),
                CodexWorkLogEntry(
                  id: 'entry_get_content_select_range',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 3),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
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
        _buildTestApp(
          child: _entrySurface(
            block: CodexWorkLogGroupBlock(
              id: 'worklog_searches',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <CodexWorkLogEntry>[
                CodexWorkLogEntry(
                  id: 'entry_rg',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: 'rg -n "Pocket Relay" lib test',
                ),
                CodexWorkLogEntry(
                  id: 'entry_grep',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title: 'grep -R -n "Pocket Relay" README.md',
                ),
                CodexWorkLogEntry(
                  id: 'entry_select_string',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
                  title:
                      r'Select-String -Path C:\repo\README.md -Pattern "Pocket Relay"',
                ),
                CodexWorkLogEntry(
                  id: 'entry_findstr',
                  createdAt: DateTime(2026, 3, 14, 12, 0, 3),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
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

  testWidgets(
    'formats pipe-separated search queries into readable alternation text',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: _entrySurface(
            block: CodexWorkLogGroupBlock(
              id: 'worklog_search_alternation',
              createdAt: DateTime(2026, 3, 14, 12),
              entries: <CodexWorkLogEntry>[
                CodexWorkLogEntry(
                  id: 'entry_rg_alt',
                  createdAt: DateTime(2026, 3, 14, 12),
                  entryKind: CodexWorkLogEntryKind.commandExecution,
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
      _buildTestApp(
        child: _entrySurface(
          block: CodexWorkLogGroupBlock(
            id: 'worklog_git_commands',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <CodexWorkLogEntry>[
              CodexWorkLogEntry(
                id: 'entry_git_status',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: CodexWorkLogEntryKind.commandExecution,
                title: 'git status',
              ),
              CodexWorkLogEntry(
                id: 'entry_git_diff',
                createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                entryKind: CodexWorkLogEntryKind.commandExecution,
                title: 'git diff --staged README.md',
              ),
              CodexWorkLogEntry(
                id: 'entry_git_show',
                createdAt: DateTime(2026, 3, 14, 12, 0, 2),
                entryKind: CodexWorkLogEntryKind.commandExecution,
                title: 'git show HEAD~1:README.md',
              ),
              CodexWorkLogEntry(
                id: 'entry_git_grep',
                createdAt: DateTime(2026, 3, 14, 12, 0, 3),
                entryKind: CodexWorkLogEntryKind.commandExecution,
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

  testWidgets('renders MCP tool calls as MCP-specific work-log rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entrySurface(
          block: CodexWorkLogGroupBlock(
            id: 'worklog_mcp',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <CodexWorkLogEntry>[
              CodexWorkLogEntry(
                id: 'entry_mcp_running',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: CodexWorkLogEntryKind.mcpToolCall,
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
              CodexWorkLogEntry(
                id: 'entry_mcp_failed',
                createdAt: DateTime(2026, 3, 14, 12, 0, 1),
                entryKind: CodexWorkLogEntryKind.mcpToolCall,
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
      _buildTestApp(
        child: _entrySurface(
          block: CodexWorkLogGroupBlock(
            id: 'worklog_mcp_single',
            createdAt: DateTime(2026, 3, 14, 12),
            entries: <CodexWorkLogEntry>[
              CodexWorkLogEntry(
                id: 'entry_mcp_single',
                createdAt: DateTime(2026, 3, 14, 12),
                entryKind: CodexWorkLogEntryKind.mcpToolCall,
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

  testWidgets('renders thread token usage as a compact usage strip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entrySurface(
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
          child: _entrySurface(
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
        child: _entrySurface(
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
        child: _entrySurface(
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

  testWidgets(
    'renders deferred thread usage inside the turn completion surface',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: _entrySurface(
            block: CodexTurnBoundaryBlock(
              id: 'turn_end_usage_1',
              createdAt: DateTime(2026, 3, 14, 12),
              usage: CodexUsageBlock(
                id: 'usage_embedded_1',
                createdAt: DateTime(2026, 3, 14, 12),
                title: 'Thread token usage',
                body:
                    'Last: input 12 | Total: input 24\nContext window: 200000',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Thread usage'), findsOneWidget);
      expect(find.text('ctx 200k'), findsOneWidget);
      expect(find.text('end'), findsOneWidget);
    },
  );

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
            child: _entrySurface(
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
      tester.getSize(find.byKey(TurnBoundaryMarker.separatorRowKey)).width,
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
        child: _entrySurface(
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
                    'lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart',
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
                'diff --git a/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart b/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart\n'
                '--- a/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart\n'
                '+++ b/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart\n'
                '@@ -2 +2 @@\n'
                '-old card\n'
                '+new card\n',
          ),
        ),
      ),
    );

    expect(
      find.text('2 files changed · 11 additions · 3 deletions'),
      findsOneWidget,
    );
    expect(find.text('Show diff'), findsNothing);

    await tester.tap(find.text('conversation_entry_renderer.dart'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining(
        'diff --git a/lib/src/features/chat/transcript/presentation/widgets/transcript/conversation_entry_renderer.dart',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.text('Additions'), findsOneWidget);
    expect(find.text('Deletions'), findsOneWidget);
    expect(find.text('Dart'), findsWidgets);
    expect(find.textContaining('new card', findRichText: true), findsOneWidget);
  });

  testWidgets('does not attach a single patch to unrelated file rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entrySurface(
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

    expect(find.textContaining('patch unavailable'), findsOneWidget);
    expect(find.text('README.md'), findsOneWidget);
  });

  testWidgets(
    'routes changed-file diff opening through the callback boundary',
    (tester) async {
      ChatChangedFileDiffContract? openedDiff;

      await tester.pumpWidget(
        _buildTestApp(
          child: _entrySurface(
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

      await tester.tap(find.text('app.dart'));
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
        child: _entrySurface(
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

    expect(find.text('Renamed from lib/old_name.dart'), findsOneWidget);
    expect(find.text('new_name.dart'), findsOneWidget);

    await tester.tap(find.text('new_name.dart'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Close diff'), findsOneWidget);
    expect(find.text('Additions'), findsOneWidget);
    expect(find.text('Deletions'), findsOneWidget);
    expect(
      find.textContaining(
        'diff --git a/lib/old_name.dart b/lib/new_name.dart',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders binary files as binary review surfaces', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entrySurface(
          block: CodexChangedFilesBlock(
            id: 'diff_binary_1',
            createdAt: DateTime(2026, 3, 14, 12),
            title: 'Changed files',
            files: const <CodexChangedFile>[
              CodexChangedFile(path: 'assets/logo.png'),
            ],
            unifiedDiff:
                'diff --git a/assets/logo.png b/assets/logo.png\n'
                'Binary files a/assets/logo.png and b/assets/logo.png differ\n',
          ),
        ),
      ),
    );

    expect(find.text('Binary · edited'), findsOneWidget);
    expect(find.text('logo.png'), findsOneWidget);

    await tester.tap(find.text('logo.png'));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Binary'), findsWidgets);
    expect(
      find.textContaining(
        'Binary files a/assets/logo.png and b/assets/logo.png differ',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders created, edited, and deleted file rows with distinct treatments',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          child: _entrySurface(
            block: CodexChangedFilesBlock(
              id: 'diff_states_1',
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Changed files',
              files: const <CodexChangedFile>[
                CodexChangedFile(path: 'lib/new_file.dart', additions: 3),
                CodexChangedFile(
                  path: 'lib/edited_file.dart',
                  additions: 2,
                  deletions: 1,
                ),
                CodexChangedFile(path: 'lib/deleted_file.dart', deletions: 4),
              ],
              unifiedDiff:
                  'diff --git a/lib/new_file.dart b/lib/new_file.dart\n'
                  'new file mode 100644\n'
                  '--- /dev/null\n'
                  '+++ b/lib/new_file.dart\n'
                  '@@ -0,0 +1,3 @@\n'
                  '+first\n'
                  '+second\n'
                  '+third\n'
                  'diff --git a/lib/edited_file.dart b/lib/edited_file.dart\n'
                  '--- a/lib/edited_file.dart\n'
                  '+++ b/lib/edited_file.dart\n'
                  '@@ -1,2 +1,3 @@\n'
                  ' same\n'
                  '-old\n'
                  '+new\n'
                  '+extra\n'
                  'diff --git a/lib/deleted_file.dart b/lib/deleted_file.dart\n'
                  'deleted file mode 100644\n'
                  '--- a/lib/deleted_file.dart\n'
                  '+++ /dev/null\n'
                  '@@ -1,4 +0,0 @@\n'
                  '-gone1\n'
                  '-gone2\n'
                  '-gone3\n'
                  '-gone4\n',
            ),
          ),
        ),
      );

      expect(find.text('Dart · created'), findsOneWidget);
      expect(find.text('Dart · edited'), findsOneWidget);
      expect(find.text('Dart · deleted'), findsOneWidget);

      final createdColor = _findDecoratedContainerColorForText(
        tester,
        'lib/new_file.dart',
      );
      final editedColor = _findDecoratedContainerColorForText(
        tester,
        'lib/edited_file.dart',
      );
      final deletedColor = _findDecoratedContainerColorForText(
        tester,
        'lib/deleted_file.dart',
      );

      expect(createdColor, isNull);
      expect(editedColor, isNull);
      expect(deletedColor, isNull);
    },
  );

  testWidgets('derives file rows from diff-only payloads without git headers', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        child: _entrySurface(
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

    expect(
      find.text('2 files changed · 2 additions · 2 deletions'),
      findsOneWidget,
    );
    expect(find.text('first.dart'), findsOneWidget);
    expect(find.text('second.dart'), findsOneWidget);

    await tester.tap(find.text('second.dart'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('new second', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('old second', findRichText: true),
      findsOneWidget,
    );
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
        child: _entrySurface(
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

    await tester.tap(find.text('large.dart'));
    await tester.pumpAndSettle();

    expect(find.text('Load full diff'), findsOneWidget);
    expect(
      find.text(
        'Showing the first 320 lines to keep the review surface responsive.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('line 315', findRichText: true), findsOneWidget);
    expect(find.textContaining('line 359', findRichText: true), findsNothing);

    await tester.tap(find.text('Load full diff'));
    await tester.pumpAndSettle();

    expect(find.text('Show preview'), findsOneWidget);
    expect(find.textContaining('line 359', findRichText: true), findsOneWidget);
  });
}

ChatTranscriptSurfaceContract _surfaceContract({
  bool isConfigured = true,
  List<CodexUiBlock> mainItems = const <CodexUiBlock>[],
  List<CodexUiBlock> pinnedItems = const <CodexUiBlock>[],
  Set<String>? activePendingUserInputRequestIds,
  int? totalMainItemCount,
  ChatEmptyStateContract? emptyState,
}) {
  return ChatTranscriptSurfaceContract(
    isConfigured: isConfigured,
    mainItems: mainItems.map(_itemProjector.project).toList(growable: false),
    pinnedItems: pinnedItems
        .map(_itemProjector.project)
        .toList(growable: false),
    pendingRequestPlacement: ChatPendingRequestPlacementContract(
      visibleApprovalRequest: null,
      visibleUserInputRequest: null,
    ),
    activePendingUserInputRequestIds:
        activePendingUserInputRequestIds ??
        _activePendingUserInputRequestIdsForBlocks(
          mainItems: mainItems,
          pinnedItems: pinnedItems,
        ),
    totalMainItemCount: totalMainItemCount,
    emptyState: emptyState,
  );
}

Set<String> _activePendingUserInputRequestIdsForBlocks({
  required List<CodexUiBlock> mainItems,
  required List<CodexUiBlock> pinnedItems,
}) {
  final activeRequestIds = <String>{};

  for (final block in <CodexUiBlock>[...mainItems, ...pinnedItems]) {
    if (block case final CodexUserInputRequestBlock userInputBlock
        when !userInputBlock.isResolved) {
      activeRequestIds.add(userInputBlock.requestId);
    }
  }

  return activeRequestIds;
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

Widget _entrySurface({
  Key? key,
  required CodexUiBlock block,
  Future<void> Function(String requestId)? onApproveRequest,
  Future<void> Function(String requestId)? onDenyRequest,
  void Function(ChatChangedFileDiffContract diff)? onOpenChangedFileDiff,
  Future<void> Function(String requestId, Map<String, List<String>> answers)?
  onSubmitUserInput,
  Future<void> Function(String blockId)? onSaveHostFingerprint,
  VoidCallback? onConfigure,
}) {
  return Builder(
    builder: (context) {
      return ConversationEntryRenderer(
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
        onSaveHostFingerprint: onSaveHostFingerprint,
        onConfigure: onConfigure,
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

  for (final ink in tester.widgetList<Ink>(
    find.ancestor(of: find.text(text), matching: find.byType(Ink)),
  )) {
    final decoration = ink.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color;
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

  for (final ink in tester.widgetList<Ink>(
    find.ancestor(of: find.text(text), matching: find.byType(Ink)),
  )) {
    final decoration = ink.decoration;
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
