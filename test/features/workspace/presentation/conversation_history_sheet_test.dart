import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/errors/pocket_error.dart';
import 'package:pocket_relay/src/core/theme/pocket_theme.dart';
import 'package:pocket_relay/src/core/widgets/modal_sheet_scaffold.dart';
import 'package:pocket_relay/src/features/workspace/domain/codex_workspace_conversation_summary.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';
import 'package:pocket_relay/src/features/workspace/presentation/workspace_conversation_history_sheet.dart';

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
    'desktop presentation uses bounded dialog chrome instead of sheet chrome',
    (tester) async {
      await tester.pumpWidget(
        _buildSheet(
          presentation:
              ConnectionWorkspaceConversationHistoryPresentation.desktop,
          future: Future<List<CodexWorkspaceConversationSummary>>.value(
            const <CodexWorkspaceConversationSummary>[],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey<String>('desktop_conversation_history_surface'),
        ),
        findsOneWidget,
      );
      expect(find.byType(ModalSheetDragHandle), findsNothing);
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
    expect(
      find.textContaining(
        '[${PocketErrorCatalog.connectionHistoryLoadFailed.code}]',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('history backend unavailable'), findsOneWidget);
  });

  testWidgets(
    'shows a connection-settings action for unpinned host key failures',
    (tester) async {
      var openedConnectionSettings = false;
      final completer = Completer<List<CodexWorkspaceConversationSummary>>();

      await tester.pumpWidget(
        _buildSheet(
          future: completer.future,
          onOpenConnectionSettings: () {
            openedConnectionSettings = true;
          },
        ),
      );
      completer.completeError(
        const CodexWorkspaceConversationHistoryUnpinnedHostKeyException(
          host: 'example.com',
          port: 22,
          keyType: 'ssh-ed25519',
          fingerprint: '7a:9f:d7:dc:2e:f2',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Host key not pinned'), findsOneWidget);
      expect(
        find.textContaining(
          '[${PocketErrorCatalog.connectionHistoryHostKeyUnpinned.code}]',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('7a:9f:d7:dc:2e:f2'), findsOneWidget);

      await tester.tap(
        find.byKey(
          const ValueKey('conversation_history_open_connection_settings'),
        ),
      );
      await tester.pumpAndSettle();

      expect(openedConnectionSettings, isTrue);
    },
  );
}

Widget _buildSheet({
  required Future<List<CodexWorkspaceConversationSummary>> future,
  ValueChanged<CodexWorkspaceConversationSummary>? onResumeConversation,
  VoidCallback? onOpenConnectionSettings,
  ConnectionWorkspaceConversationHistoryPresentation presentation =
      ConnectionWorkspaceConversationHistoryPresentation.mobile,
}) {
  return MaterialApp(
    theme: buildPocketTheme(Brightness.light),
    home: Scaffold(
      body: ConnectionWorkspaceConversationHistorySheet(
        presentation: presentation,
        title: 'Conversation history',
        future: future,
        onResumeConversation: onResumeConversation ?? (_) {},
        onOpenConnectionSettings: onOpenConnectionSettings,
      ),
    ),
  );
}
