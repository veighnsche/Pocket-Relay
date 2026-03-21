import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_models.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';

import 'support/fake_codex_app_server_client.dart';

void main() {
  test(
    'loads Codex threads for the workspace, filters descendants, and excludes zero-prompt threads',
    () async {
      final client = FakeCodexAppServerClient()
        ..listedThreads.addAll(<CodexAppServerThreadSummary>[
          CodexAppServerThreadSummary(
            id: 'thread_root',
            preview: 'Root prompt',
            cwd: '/workspace',
            createdAt: DateTime(2026, 3, 20, 10),
            updatedAt: DateTime(2026, 3, 20, 12),
          ),
          CodexAppServerThreadSummary(
            id: 'thread_child',
            preview: 'Child prompt',
            cwd: '/workspace/subdir',
            createdAt: DateTime(2026, 3, 20, 9),
            updatedAt: DateTime(2026, 3, 20, 13),
          ),
          CodexAppServerThreadSummary(
            id: 'thread_other',
            preview: 'Other prompt',
            cwd: '/elsewhere',
            createdAt: DateTime(2026, 3, 20, 8),
            updatedAt: DateTime(2026, 3, 20, 14),
          ),
        ])
        ..threadHistoriesById.addAll(<String, CodexAppServerThreadHistory>{
          'thread_root': CodexAppServerThreadHistory(
            id: 'thread_root',
            preview: 'Root prompt',
            cwd: '/workspace',
            createdAt: DateTime(2026, 3, 20, 10),
            updatedAt: DateTime(2026, 3, 20, 12),
            promptCount: 2,
          ),
          'thread_child': CodexAppServerThreadHistory(
            id: 'thread_child',
            preview: 'Child prompt',
            cwd: '/workspace/subdir',
            createdAt: DateTime(2026, 3, 20, 9),
            updatedAt: DateTime(2026, 3, 20, 13),
            promptCount: 0,
          ),
          'thread_other': CodexAppServerThreadHistory(
            id: 'thread_other',
            preview: 'Other prompt',
            cwd: '/elsewhere',
            createdAt: DateTime(2026, 3, 20, 8),
            updatedAt: DateTime(2026, 3, 20, 14),
            promptCount: 3,
          ),
        });
      addTearDown(client.close);

      final repository = CodexAppServerConversationHistoryRepository(
        clientFactory: () => client,
      );

      final conversations = await repository.loadWorkspaceConversations(
        profile: ConnectionProfile.defaults().copyWith(
          host: 'infra.example',
          username: 'vince',
          workspaceDir: '/workspace',
        ),
        secrets: const ConnectionSecrets(password: 'secret'),
      );

      expect(conversations.map((entry) => entry.threadId), <String>[
        'thread_root',
      ]);
      expect(client.listThreadCalls, <({String? cursor, int? limit})>[
        (cursor: null, limit: 100),
      ]);
      expect(client.readThreadCalls, <String>['thread_root', 'thread_child']);
    },
  );

  test('sorts workspace conversations by last activity descending', () async {
    final client = FakeCodexAppServerClient()
      ..listedThreads.addAll(<CodexAppServerThreadSummary>[
        CodexAppServerThreadSummary(
          id: 'thread_old',
          preview: 'Older prompt',
          cwd: '/workspace',
          createdAt: DateTime(2026, 3, 20, 9),
          updatedAt: DateTime(2026, 3, 20, 10),
        ),
        CodexAppServerThreadSummary(
          id: 'thread_new',
          preview: 'Newer prompt',
          cwd: '/workspace',
          createdAt: DateTime(2026, 3, 20, 11),
          updatedAt: DateTime(2026, 3, 20, 15),
        ),
      ])
      ..threadHistoriesById.addAll(<String, CodexAppServerThreadHistory>{
        'thread_old': CodexAppServerThreadHistory(
          id: 'thread_old',
          preview: 'Older prompt',
          cwd: '/workspace',
          createdAt: DateTime(2026, 3, 20, 9),
          updatedAt: DateTime(2026, 3, 20, 10),
          promptCount: 1,
        ),
        'thread_new': CodexAppServerThreadHistory(
          id: 'thread_new',
          preview: 'Newer prompt',
          cwd: '/workspace',
          createdAt: DateTime(2026, 3, 20, 11),
          updatedAt: DateTime(2026, 3, 20, 15),
          promptCount: 1,
        ),
      });
    addTearDown(client.close);

    final repository = CodexAppServerConversationHistoryRepository(
      clientFactory: () => client,
    );

    final conversations = await repository.loadWorkspaceConversations(
      profile: ConnectionProfile.defaults().copyWith(
        connectionMode: ConnectionMode.local,
        workspaceDir: '/workspace',
      ),
      secrets: const ConnectionSecrets(),
    );

    expect(conversations.map((entry) => entry.threadId), <String>[
      'thread_new',
      'thread_old',
    ]);
  });
}
