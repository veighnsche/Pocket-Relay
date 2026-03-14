import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/models/codex_runtime_event.dart';
import 'package:pocket_relay/src/features/chat/models/codex_ui_block.dart';
import 'package:pocket_relay/src/features/chat/presentation/widgets/conversation_entry_card.dart';

void main() {
  testWidgets('renders reasoning blocks with markdown text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationEntryCard(
            block: CodexTextBlock(
              id: 'reasoning_1',
              kind: CodexUiBlockKind.reasoning,
              createdAt: DateTime(2026, 3, 14, 12),
              title: 'Reasoning',
              body: 'Investigating the next step.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Reasoning'), findsOneWidget);
    expect(find.text('Investigating the next step.'), findsOneWidget);
  });

  testWidgets('renders approval request actions', (tester) async {
    String? approvedRequestId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationEntryCard(
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
      MaterialApp(
        home: Scaffold(
          body: ConversationEntryCard(
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
}
