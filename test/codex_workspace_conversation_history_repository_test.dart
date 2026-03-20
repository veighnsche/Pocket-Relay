import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/codex_workspace_conversation_history_repository.dart';

void main() {
  test('filters local history to sessions inside the workspace tree', () async {
    final repository = CodexStorageConversationHistoryRepository(
      localLoader: FakeStorageLoader(
        snapshot: const CodexWorkspaceConversationStorageSnapshot(
          historyJsonl: '''
{"session_id":"session_a","ts":1710000000,"text":"Open the transport code"}
{"session_id":"session_a","ts":1710000300,"text":"Add the missing tests"}
{"session_id":"session_b","ts":1710000600,"text":"Other workspace prompt"}
''',
          sessionDocuments: <CodexWorkspaceConversationSessionDocument>[
            CodexWorkspaceConversationSessionDocument(
              path: '/root/.codex/sessions/a.jsonl',
              contents:
                  '{"type":"session_meta","payload":{"id":"session_a","cwd":"/workspace/project","timestamp":"2026-03-20T10:00:00Z"}}',
            ),
            CodexWorkspaceConversationSessionDocument(
              path: '/root/.codex/sessions/b.jsonl',
              contents:
                  '{"type":"session_meta","payload":{"id":"session_b","cwd":"/elsewhere","timestamp":"2026-03-20T11:00:00Z"}}',
            ),
          ],
        ),
      ),
    );

    final conversations = await repository.loadWorkspaceConversations(
      profile: ConnectionProfile.defaults().copyWith(
        connectionMode: ConnectionMode.local,
        workspaceDir: '/workspace',
      ),
      secrets: const ConnectionSecrets(),
    );

    expect(conversations, hasLength(1));
    expect(conversations.single.sessionId, 'session_a');
    expect(conversations.single.preview, 'Open the transport code');
    expect(conversations.single.messageCount, 2);
    expect(conversations.single.cwd, '/workspace/project');
  });

  test('uses the remote loader for SSH-backed workspaces', () async {
    final remoteLoader = FakeRemoteStorageLoader(
      snapshot: const CodexWorkspaceConversationStorageSnapshot(
        historyJsonl:
            '{"session_id":"session_remote","ts":1710000000,"text":"Inspect the remote codex logs"}',
        sessionDocuments: <CodexWorkspaceConversationSessionDocument>[
          CodexWorkspaceConversationSessionDocument(
            path: '/home/vince/.codex/sessions/a.jsonl',
            contents:
                '{"type":"session_meta","payload":{"id":"session_remote","cwd":"/srv/app","timestamp":"2026-03-20T10:00:00Z"}}',
          ),
        ],
      ),
    );
    final repository = CodexStorageConversationHistoryRepository(
      localLoader: FakeStorageLoader(
        snapshot: const CodexWorkspaceConversationStorageSnapshot(
          historyJsonl: null,
          sessionDocuments: <CodexWorkspaceConversationSessionDocument>[],
        ),
      ),
      remoteLoader: remoteLoader,
    );

    final conversations = await repository.loadWorkspaceConversations(
      profile: ConnectionProfile.defaults().copyWith(
        connectionMode: ConnectionMode.remote,
        host: 'example.test',
        username: 'vince',
        workspaceDir: '/srv/app',
      ),
      secrets: const ConnectionSecrets(password: 'secret'),
    );

    expect(remoteLoader.callCount, 1);
    expect(conversations, hasLength(1));
    expect(conversations.single.sessionId, 'session_remote');
  });

  test('excludes matching workspace sessions with zero recorded prompts', () async {
    final repository = CodexStorageConversationHistoryRepository(
      localLoader: FakeStorageLoader(
        snapshot: const CodexWorkspaceConversationStorageSnapshot(
          historyJsonl:
              '{"session_id":"session_with_prompts","ts":1710000000,"text":"Open the transport code"}',
          sessionDocuments: <CodexWorkspaceConversationSessionDocument>[
            CodexWorkspaceConversationSessionDocument(
              path: '/root/.codex/sessions/a.jsonl',
              contents:
                  '{"type":"session_meta","payload":{"id":"session_zero","cwd":"/workspace/project","timestamp":"2026-03-20T10:00:00Z"}}',
            ),
            CodexWorkspaceConversationSessionDocument(
              path: '/root/.codex/sessions/b.jsonl',
              contents:
                  '{"type":"session_meta","payload":{"id":"session_with_prompts","cwd":"/workspace/project","timestamp":"2026-03-20T11:00:00Z"}}',
            ),
          ],
        ),
      ),
    );

    final conversations = await repository.loadWorkspaceConversations(
      profile: ConnectionProfile.defaults().copyWith(
        connectionMode: ConnectionMode.local,
        workspaceDir: '/workspace',
      ),
      secrets: const ConnectionSecrets(),
    );

    expect(conversations, hasLength(1));
    expect(conversations.single.sessionId, 'session_with_prompts');
    expect(conversations.single.messageCount, 1);
  });
}

class FakeStorageLoader implements CodexWorkspaceConversationStorageLoader {
  const FakeStorageLoader({required this.snapshot});

  final CodexWorkspaceConversationStorageSnapshot snapshot;

  @override
  Future<CodexWorkspaceConversationStorageSnapshot> load() async => snapshot;
}

class FakeRemoteStorageLoader
    implements CodexWorkspaceConversationRemoteLoader {
  FakeRemoteStorageLoader({required this.snapshot});

  final CodexWorkspaceConversationStorageSnapshot snapshot;
  int callCount = 0;

  @override
  Future<CodexWorkspaceConversationStorageSnapshot> load({
    required ConnectionProfile profile,
    required ConnectionSecrets secrets,
  }) async {
    callCount += 1;
    return snapshot;
  }
}
