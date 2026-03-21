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
      );
      await Future<void>.delayed(Duration.zero);

      expect(store.state.normalizedSelectedThreadId, isNull);
      expect(coordinator.resumeThreadId(ephemeralSession: false), isNull);
    },
  );

  test(
    'clearContinuationThread does not re-persist the previous active thread id',
    () async {
      final store = _DelayedConversationStateStore(
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

      coordinator.schedulePersistConversationSelection(
        isDisposed: false,
        ephemeralSession: false,
        activeThreadId: 'thread_old',
      );
      coordinator.clearContinuationThread(
        isDisposed: false,
        ephemeralSession: false,
      );
      await Future<void>.delayed(Duration.zero);
      await store.flush();

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

class _DelayedConversationStateStore implements CodexConversationStateStore {
  _DelayedConversationStateStore({
    SavedConnectionConversationState? initialState,
  }) : state = initialState ?? const SavedConnectionConversationState();

  SavedConnectionConversationState state;
  final List<Future<void>> _pendingWrites = <Future<void>>[];

  @override
  Future<SavedConnectionConversationState> loadState() async {
    return state;
  }

  @override
  Future<void> saveState(SavedConnectionConversationState nextState) {
    final write = Future<void>.microtask(() {
      state = nextState;
    });
    _pendingWrites.add(write);
    return write;
  }

  Future<void> flush() async {
    while (_pendingWrites.isNotEmpty) {
      final pending = List<Future<void>>.from(_pendingWrites);
      _pendingWrites.clear();
      await Future.wait(pending);
    }
  }
}
