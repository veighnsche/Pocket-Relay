import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
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
    'ConnectionScopedConversationHistoryStore loads and saves only its connection',
    () async {
      final historyStore = MemoryCodexConnectionConversationHistoryStore(
        initialValues: <String, List<SavedConversationThread>>{
          'conn_a': const <SavedConversationThread>[
            SavedConversationThread(
              threadId: 'thread_a',
              preview: 'Prompt A',
              messageCount: 2,
              firstPromptAt: null,
              lastActivityAt: null,
            ),
          ],
          'conn_b': const <SavedConversationThread>[
            SavedConversationThread(
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
      await store.save(const <SavedConversationThread>[
        SavedConversationThread(
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
    'ConnectionScopedConversationStateStore loads and saves only its connection',
    () async {
      final conversationStateStore =
          MemoryCodexConnectionConversationHistoryStore(
            initialStates: <String, SavedConnectionConversationState>{
              'conn_a': const SavedConnectionConversationState(
                selectedThreadId: 'thread_handoff',
                conversations: <SavedConversationThread>[
                  SavedConversationThread(
                    threadId: 'thread_handoff',
                    preview: 'Prompt A',
                    messageCount: 1,
                    firstPromptAt: null,
                    lastActivityAt: null,
                  ),
                ],
              ),
              'conn_b': const SavedConnectionConversationState(
                selectedThreadId: 'thread_other',
              ),
            },
          );
      final store = ConnectionScopedConversationStateStore(
        connectionId: 'conn_a',
        conversationStateStore: conversationStateStore,
      );

      final initial = await store.loadState();
      await store.saveState(
        const SavedConnectionConversationState(
          selectedThreadId: 'thread_updated',
        ),
      );

      expect(
        initial.normalizedSelectedThreadId,
        'thread_handoff',
      );
      expect(
        (await conversationStateStore.loadState('conn_a')).normalizedSelectedThreadId,
        'thread_updated',
      );
      expect(
        (await conversationStateStore.loadState('conn_b')).normalizedSelectedThreadId,
        'thread_other',
      );
    },
  );
}
