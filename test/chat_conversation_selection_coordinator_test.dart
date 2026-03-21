import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
import 'package:pocket_relay/src/features/chat/application/chat_conversation_selection_coordinator.dart';

void main() {
  test('selectConversationForResume persists the selected thread id', () async {
    final store = _RecordingConversationStateStore();
    final coordinator = ChatConversationSelectionCoordinator(
      conversationStateStore: store,
    );

    await coordinator.selectConversationForResume(
      'thread_saved',
      ephemeralSession: false,
      activeThreadId: null,
    );

    expect(store.state.normalizedSelectedThreadId, 'thread_saved');
    expect(coordinator.resumeThreadId(ephemeralSession: false), 'thread_saved');
  });

  test(
    'clearContinuationThread clears the persisted selected thread id',
    () async {
      final store = _RecordingConversationStateStore(
        initialState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_old',
        ),
      );
      final coordinator = ChatConversationSelectionCoordinator(
        conversationStateStore: store,
        initialConversationState: const SavedConnectionConversationState(
          selectedThreadId: 'thread_old',
        ),
      );

      coordinator.clearContinuationThread(
        isDisposed: false,
        ephemeralSession: false,
        activeThreadId: null,
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.state.normalizedSelectedThreadId, isNull);
      expect(coordinator.resumeThreadId(ephemeralSession: false), isNull);
    },
  );
}

class _RecordingConversationStateStore implements CodexConversationStateStore {
  _RecordingConversationStateStore({
    SavedConnectionConversationState? initialState,
  }) : state = initialState ?? const SavedConnectionConversationState();

  SavedConnectionConversationState state;

  @override
  Future<SavedConnectionConversationState> loadState() async {
    return state;
  }

  @override
  Future<void> saveState(SavedConnectionConversationState nextState) async {
    state = nextState;
  }
}
