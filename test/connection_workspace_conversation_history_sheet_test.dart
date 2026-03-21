import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/features/workspace/models/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/presentation/widgets/connection_workspace_conversation_history_sheet.dart';

void main() {
  testWidgets(
    'shows an empty-state message when no workspace conversations are available',
    (tester) async {
      await tester.pumpWidget(
        _buildSheet(
          future: Future<List<CodexWorkspaceConversationSummary>>.value(
            const <CodexWorkspaceConversationSummary>[],
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('No matching conversations'), findsOneWidget);
      expect(
        find.text('No workspace conversations are available yet.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'falls back to the normalized thread id and resumes the selected conversation',
    (tester) async {
      CodexWorkspaceConversationSummary? resumedConversation;
      final conversation = CodexWorkspaceConversationSummary(
        threadId: ' thread_saved ',
        preview: '   ',
        cwd: '/workspace',
        promptCount: 3,
        firstPromptAt: DateTime(2026, 3, 20, 9),
        lastActivityAt: DateTime(2026, 3, 20, 11, 42),
      );

      await tester.pumpWidget(
        _buildSheet(
          future: Future<List<CodexWorkspaceConversationSummary>>.value(
            <CodexWorkspaceConversationSummary>[conversation],
          ),
          onResumeConversation: (selectedConversation) {
            resumedConversation = selectedConversation;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('thread_saved'), findsOneWidget);
      expect(find.textContaining('3 prompts'), findsOneWidget);
      expect(find.textContaining('2026-03-20 11:42'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('workspace_conversation_thread_saved')),
      );
      await tester.pumpAndSettle();

      expect(resumedConversation, same(conversation));
    },
  );

  testWidgets('shows the error state when conversation loading fails', (
    tester,
  ) async {
    final completer = Completer<List<CodexWorkspaceConversationSummary>>();
    await tester.pumpWidget(_buildSheet(future: completer.future));
    completer.completeError(StateError('history backend unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('Could not load conversations'), findsOneWidget);
    expect(find.textContaining('history backend unavailable'), findsOneWidget);
  });
}

Widget _buildSheet({
  required Future<List<CodexWorkspaceConversationSummary>> future,
  ValueChanged<CodexWorkspaceConversationSummary>? onResumeConversation,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: ConnectionWorkspaceConversationHistorySheet(
        title: 'Conversation history',
        future: future,
        onResumeConversation: onResumeConversation ?? (_) {},
      ),
    ),
  );
}
