import 'package:shared_preferences/shared_preferences.dart';

import 'codex_connection_conversation_history_store.dart';
import 'codex_conversation_handoff_store.dart';

abstract interface class CodexConnectionHandoffStore {
  Future<SavedConversationHandoff> load(String connectionId);

  Future<void> save(String connectionId, SavedConversationHandoff handoff);

  Future<void> delete(String connectionId);
}

class SecureCodexConnectionHandoffStore implements CodexConnectionHandoffStore {
  SecureCodexConnectionHandoffStore({
    SharedPreferencesAsync? preferences,
    CodexConnectionConversationStateStore? conversationStateStore,
  }) : _conversationStateStore =
           conversationStateStore ??
           SecureCodexConnectionConversationHistoryStore(
             preferences: preferences,
           );

  final CodexConnectionConversationStateStore _conversationStateStore;

  @override
  Future<SavedConversationHandoff> load(String connectionId) async {
    final state = await _conversationStateStore.loadState(connectionId);
    return SavedConversationHandoff(
      resumeThreadId: state.normalizedSelectedThreadId,
    );
  }

  @override
  Future<void> save(
    String connectionId,
    SavedConversationHandoff handoff,
  ) async {
    final state = await _conversationStateStore.loadState(connectionId);
    await _conversationStateStore.saveState(
      connectionId,
      state.copyWith(
        selectedThreadId: handoff.normalizedResumeThreadId,
        clearSelectedThreadId: handoff.normalizedResumeThreadId == null,
      ),
    );
  }

  @override
  Future<void> delete(String connectionId) {
    return _conversationStateStore.deleteState(connectionId);
  }
}

class MemoryCodexConnectionHandoffStore implements CodexConnectionHandoffStore {
  MemoryCodexConnectionHandoffStore({
    Map<String, SavedConversationHandoff>? initialValues,
    CodexConnectionConversationStateStore? conversationStateStore,
  }) : _conversationStateStore =
           conversationStateStore ??
           MemoryCodexConnectionConversationHistoryStore(
             initialStates: initialValues == null
                 ? null
                 : <String, SavedConnectionConversationState>{
                     for (final entry in initialValues.entries)
                       entry.key: SavedConnectionConversationState(
                         selectedThreadId: entry.value.normalizedResumeThreadId,
                         conversations:
                             entry.value.normalizedResumeThreadId == null
                             ? const <SavedResumableConversation>[]
                             : <SavedResumableConversation>[
                                 SavedResumableConversation(
                                   threadId:
                                       entry.value.normalizedResumeThreadId!,
                                   preview: '',
                                   messageCount: 1,
                                   firstPromptAt: null,
                                   lastActivityAt: null,
                                 ),
                               ],
                       ),
                   },
           );

  final CodexConnectionConversationStateStore _conversationStateStore;

  @override
  Future<SavedConversationHandoff> load(String connectionId) async {
    final state = await _conversationStateStore.loadState(connectionId);
    return SavedConversationHandoff(
      resumeThreadId: state.normalizedSelectedThreadId,
    );
  }

  @override
  Future<void> save(
    String connectionId,
    SavedConversationHandoff handoff,
  ) async {
    final state = await _conversationStateStore.loadState(connectionId);
    await _conversationStateStore.saveState(
      connectionId,
      state.copyWith(
        selectedThreadId: handoff.normalizedResumeThreadId,
        clearSelectedThreadId: handoff.normalizedResumeThreadId == null,
      ),
    );
  }

  @override
  Future<void> delete(String connectionId) {
    return _conversationStateStore.deleteState(connectionId);
  }
}
