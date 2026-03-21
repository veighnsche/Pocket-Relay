import 'dart:async';

import 'package:pocket_relay/src/core/storage/codex_connection_conversation_history_store.dart';

class ChatConversationSelectionCoordinator {
  ChatConversationSelectionCoordinator({
    required CodexConversationStateStore conversationStateStore,
    SavedConnectionConversationState initialConversationState =
        const SavedConnectionConversationState(),
  }) : _conversationStateStore = conversationStateStore,
       _resumeThreadId = initialConversationState.normalizedSelectedThreadId;

  final CodexConversationStateStore _conversationStateStore;
  String? _resumeThreadId;
  bool _suppressTrackedThreadReuse = false;

  bool get suppressTrackedThreadReuse => _suppressTrackedThreadReuse;

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

    _resumeThreadId = normalizedThreadId;
    _suppressTrackedThreadReuse = false;
    await _persistConversationSelection(
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
    required String? activeThreadId,
  }) {
    _resumeThreadId = null;
    _suppressTrackedThreadReuse = true;
    schedulePersistConversationSelection(
      isDisposed: isDisposed,
      ephemeralSession: ephemeralSession,
      activeThreadId: activeThreadId,
    );
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
    unawaited(_persistConversationSelection(selectedThreadId));
  }

  Future<void> recordConversationSelection({required String threadId}) async {
    final normalizedThreadId = _normalizeThreadId(threadId);
    if (normalizedThreadId == null) {
      return;
    }

    await _persistConversationSelection(normalizedThreadId);
  }

  Future<void> _persistConversationSelection(String? selectedThreadId) async {
    try {
      final currentState = await _conversationStateStore.loadState();
      await _conversationStateStore.saveState(
        currentState.copyWith(
          selectedThreadId: selectedThreadId,
          clearSelectedThreadId: selectedThreadId == null,
        ),
      );
    } catch (_) {
      // Conversation selection persistence must not break the active session.
    }
  }

  String? _normalizeThreadId(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }
    return normalizedValue;
  }
}
