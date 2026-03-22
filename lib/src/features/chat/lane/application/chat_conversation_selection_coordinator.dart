import 'dart:async';

import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';

class ChatConversationSelectionCoordinator {
  ChatConversationSelectionCoordinator({
    required CodexConversationStateStore conversationStateStore,
  }) : _conversationStateStore = conversationStateStore;

  final CodexConversationStateStore _conversationStateStore;
  String? _resumeThreadId;
  bool _suppressTrackedThreadReuse = false;
  bool _hasHydratedPersistedSelection = false;
  Future<void>? _hydrationFuture;
  Future<void> _pendingPersistence = Future<void>.value();
  int _persistenceGeneration = 0;
  int _selectionVersion = 0;

  bool get suppressTrackedThreadReuse => _suppressTrackedThreadReuse;

  Future<void> hydratePersistedSelection() {
    if (_hasHydratedPersistedSelection) {
      return Future<void>.value();
    }

    return _hydrationFuture ??= _hydratePersistedSelectionOnce();
  }

  String? resumeThreadId({required bool ephemeralSession}) {
    if (ephemeralSession) {
      return null;
    }

    return _normalizeThreadId(_resumeThreadId);
  }

  Future<void> selectConversationForResume(
    String threadId, {
    required bool ephemeralSession,
    required String? activeThreadId,
  }) async {
    final normalizedThreadId = _normalizeThreadId(threadId);
    if (normalizedThreadId == null) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'Thread id must not be empty.',
      );
    }

    _selectionVersion += 1;
    _resumeThreadId = normalizedThreadId;
    _suppressTrackedThreadReuse = false;
    await _scheduleConversationSelectionPersistence(
      activeThreadId ?? resumeThreadId(ephemeralSession: ephemeralSession),
    );
  }

  void rememberContinuationThread(
    String? threadId, {
    required bool isDisposed,
    required bool ephemeralSession,
    required String? activeThreadId,
  }) {
    final normalizedThreadId = _normalizeThreadId(threadId);
    if (normalizedThreadId == null) {
      return;
    }

    _selectionVersion += 1;
    _resumeThreadId = normalizedThreadId;
    _suppressTrackedThreadReuse = false;
    schedulePersistConversationSelection(
      isDisposed: isDisposed,
      ephemeralSession: ephemeralSession,
      activeThreadId: activeThreadId,
    );
  }

  void clearContinuationThread({
    required bool isDisposed,
    required bool ephemeralSession,
  }) {
    _selectionVersion += 1;
    _resumeThreadId = null;
    _suppressTrackedThreadReuse = true;
    if (isDisposed) {
      return;
    }

    unawaited(_scheduleConversationSelectionPersistence(null));
  }

  void schedulePersistConversationSelection({
    required bool isDisposed,
    required bool ephemeralSession,
    required String? activeThreadId,
  }) {
    if (isDisposed) {
      return;
    }

    final selectedThreadId =
        activeThreadId ?? resumeThreadId(ephemeralSession: ephemeralSession);
    unawaited(_scheduleConversationSelectionPersistence(selectedThreadId));
  }

  Future<void> recordConversationSelection({required String threadId}) async {
    final normalizedThreadId = _normalizeThreadId(threadId);
    if (normalizedThreadId == null) {
      return;
    }

    await _scheduleConversationSelectionPersistence(normalizedThreadId);
  }

  Future<void> _hydratePersistedSelectionOnce() async {
    final selectionVersion = _selectionVersion;
    try {
      final currentState = await _conversationStateStore.loadState();
      if (selectionVersion != _selectionVersion) {
        return;
      }

      _resumeThreadId = currentState.normalizedSelectedThreadId;
    } catch (_) {
      // Persisted conversation selection is a convenience, not a requirement.
    } finally {
      _hasHydratedPersistedSelection = true;
    }
  }

  Future<void> _scheduleConversationSelectionPersistence(
    String? selectedThreadId,
  ) {
    final generation = ++_persistenceGeneration;
    _pendingPersistence = _pendingPersistence.then((_) async {
      if (generation != _persistenceGeneration) {
        return;
      }

      try {
        final currentState = await _conversationStateStore.loadState();
        if (generation != _persistenceGeneration) {
          return;
        }

        await _conversationStateStore.saveState(
          currentState.copyWith(
            selectedThreadId: selectedThreadId,
            clearSelectedThreadId: selectedThreadId == null,
          ),
        );
      } catch (_) {
        // Conversation selection persistence must not break the active session.
      }
    });
    return _pendingPersistence;
  }

  String? _normalizeThreadId(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }
}
