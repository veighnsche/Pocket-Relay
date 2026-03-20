import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:pocket_relay/src/core/storage/codex_conversation_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/connection_scoped_stores.dart';

void main() {
  test(
    'ConnectionScopedProfileStore loads and saves only its connection',
    () async {
      final repository = MemoryCodexConnectionRepository(
        initialConnections: <SavedConnection>[
          SavedConnection(
            id: 'conn_a',
            profile: ConnectionProfile.defaults().copyWith(
              label: 'A',
              host: 'a.example.com',
              username: 'vince',
            ),
            secrets: const ConnectionSecrets(password: 'secret-a'),
          ),
          SavedConnection(
            id: 'conn_b',
            profile: ConnectionProfile.defaults().copyWith(
              label: 'B',
              host: 'b.example.com',
              username: 'vince',
            ),
            secrets: const ConnectionSecrets(password: 'secret-b'),
          ),
        ],
      );
      final store = ConnectionScopedProfileStore(
        connectionId: 'conn_a',
        connectionRepository: repository,
      );

      final initial = await store.load();
      await store.save(
        initial.profile.copyWith(label: 'A Updated'),
        initial.secrets.copyWith(privateKeyPem: 'pem-a'),
      );

      final connectionA = await repository.loadConnection('conn_a');
      final connectionB = await repository.loadConnection('conn_b');

      expect(initial.profile.label, 'A');
      expect(connectionA.profile.label, 'A Updated');
      expect(connectionA.secrets.privateKeyPem, 'pem-a');
      expect(connectionB.profile.label, 'B');
      expect(connectionB.secrets.privateKeyPem, isEmpty);
    },
  );

  test(
    'ConnectionScopedConversationHandoffStore loads and saves only its connection',
    () async {
      final handoffStore = MemoryCodexConnectionHandoffStore(
        initialValues: <String, SavedConversationHandoff>{
          'conn_a': const SavedConversationHandoff(resumeThreadId: 'thread_a'),
          'conn_b': const SavedConversationHandoff(resumeThreadId: 'thread_b'),
        },
      );
      final store = ConnectionScopedConversationHandoffStore(
        connectionId: 'conn_a',
        handoffStore: handoffStore,
      );

      final initial = await store.load();
      await store.save(
        const SavedConversationHandoff(resumeThreadId: 'thread_a_updated'),
      );

      expect(
        initial,
        const SavedConversationHandoff(resumeThreadId: 'thread_a'),
      );
      expect(
        await handoffStore.load('conn_a'),
        const SavedConversationHandoff(resumeThreadId: 'thread_a_updated'),
      );
      expect(
        await handoffStore.load('conn_b'),
        const SavedConversationHandoff(resumeThreadId: 'thread_b'),
      );
    },
  );

  test(
    'ConnectionScopedConversationHistoryStore loads and saves only its connection',
    () async {
      final historyStore = MemoryCodexConnectionConversationHistoryStore(
        initialValues: <String, List<SavedResumableConversation>>{
          'conn_a': const <SavedResumableConversation>[
            SavedResumableConversation(
              threadId: 'thread_a',
              preview: 'Prompt A',
              messageCount: 2,
              firstPromptAt: null,
              lastActivityAt: null,
            ),
          ],
          'conn_b': const <SavedResumableConversation>[
            SavedResumableConversation(
              threadId: 'thread_b',
              preview: 'Prompt B',
              messageCount: 1,
              firstPromptAt: null,
              lastActivityAt: null,
            ),
          ],
        },
      );
      final store = ConnectionScopedConversationHistoryStore(
        connectionId: 'conn_a',
        historyStore: historyStore,
      );

      final initial = await store.load();
      await store.save(const <SavedResumableConversation>[
        SavedResumableConversation(
          threadId: 'thread_a_updated',
          preview: 'Prompt A updated',
          messageCount: 3,
          firstPromptAt: null,
          lastActivityAt: null,
        ),
      ]);

      expect(initial.single.normalizedThreadId, 'thread_a');
      expect(
        (await historyStore.load('conn_a')).single.normalizedThreadId,
        'thread_a_updated',
      );
      expect(
        (await historyStore.load('conn_b')).single.normalizedThreadId,
        'thread_b',
      );
    },
  );

  test(
    'ConnectionScopedConversationHandoffStore and history store can share one conversation state backing',
    () async {
      final conversationStateStore =
          MemoryCodexConnectionConversationHistoryStore(
            initialStates: <String, SavedConnectionConversationState>{
              'conn_a': const SavedConnectionConversationState(
                selectedThreadId: 'thread_handoff',
                conversations: <SavedResumableConversation>[
                  SavedResumableConversation(
                    threadId: 'thread_handoff',
                    preview: 'Prompt A',
                    messageCount: 1,
                    firstPromptAt: null,
                    lastActivityAt: null,
                  ),
                ],
              ),
            },
          );
      final handoffStore = ConnectionScopedConversationHandoffStore(
        connectionId: 'conn_a',
        handoffStore: MemoryCodexConnectionHandoffStore(
          conversationStateStore: conversationStateStore,
        ),
      );
      final historyStore = ConnectionScopedConversationHistoryStore(
        connectionId: 'conn_a',
        historyStore: conversationStateStore,
      );

      expect(
        (await handoffStore.load()).normalizedResumeThreadId,
        'thread_handoff',
      );
      expect(
        (await historyStore.load()).single.normalizedThreadId,
        'thread_handoff',
      );
    },
  );
}
