import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'codex_conversation_handoff_store.dart';
import 'shared_preferences_async_migration.dart';

class SavedResumableConversation {
  const SavedResumableConversation({
    required this.threadId,
    required this.preview,
    required this.messageCount,
    required this.firstPromptAt,
    required this.lastActivityAt,
  });

  final String threadId;
  final String preview;
  final int messageCount;
  final DateTime? firstPromptAt;
  final DateTime? lastActivityAt;

  String get normalizedThreadId => threadId.trim();

  SavedResumableConversation copyWith({
    String? threadId,
    String? preview,
    int? messageCount,
    Object? firstPromptAt = _historySentinel,
    Object? lastActivityAt = _historySentinel,
  }) {
    return SavedResumableConversation(
      threadId: threadId ?? this.threadId,
      preview: preview ?? this.preview,
      messageCount: messageCount ?? this.messageCount,
      firstPromptAt: identical(firstPromptAt, _historySentinel)
          ? this.firstPromptAt
          : firstPromptAt as DateTime?,
      lastActivityAt: identical(lastActivityAt, _historySentinel)
          ? this.lastActivityAt
          : lastActivityAt as DateTime?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'threadId': normalizedThreadId,
      'preview': preview,
      'messageCount': messageCount,
      'firstPromptAt': firstPromptAt?.toIso8601String(),
      'lastActivityAt': lastActivityAt?.toIso8601String(),
    };
  }

  factory SavedResumableConversation.fromJson(Map<String, dynamic> json) {
    return SavedResumableConversation(
      threadId: json['threadId'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      messageCount: json['messageCount'] as int? ?? 0,
      firstPromptAt: _parseTimestamp(json['firstPromptAt']),
      lastActivityAt: _parseTimestamp(json['lastActivityAt']),
    );
  }

  static DateTime? _parseTimestamp(Object? value) {
    if (value is! String) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}

class SavedConnectionConversationState {
  const SavedConnectionConversationState({
    this.selectedThreadId,
    this.conversations = const <SavedResumableConversation>[],
  });

  final String? selectedThreadId;
  final List<SavedResumableConversation> conversations;

  String? get normalizedSelectedThreadId {
    final normalized = selectedThreadId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  SavedConnectionConversationState copyWith({
    String? selectedThreadId,
    bool clearSelectedThreadId = false,
    List<SavedResumableConversation>? conversations,
  }) {
    return SavedConnectionConversationState(
      selectedThreadId: clearSelectedThreadId
          ? null
          : (selectedThreadId ?? this.selectedThreadId),
      conversations: conversations ?? this.conversations,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'selectedThreadId': normalizedSelectedThreadId,
      'conversations': conversations
          .where((entry) => entry.normalizedThreadId.isNotEmpty)
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }

  factory SavedConnectionConversationState.fromJson(Map<String, dynamic> json) {
    final rawConversations = json['conversations'];
    final conversations = rawConversations is List
        ? rawConversations
              .whereType<Map>()
              .map(
                (entry) => SavedResumableConversation.fromJson(
                  Map<String, dynamic>.from(entry),
                ),
              )
              .where((entry) => entry.normalizedThreadId.isNotEmpty)
              .toList(growable: false)
        : const <SavedResumableConversation>[];

    return SavedConnectionConversationState(
      selectedThreadId: json['selectedThreadId'] as String?,
      conversations: conversations,
    );
  }
}

const Object _historySentinel = Object();

abstract interface class CodexConversationHistoryStore {
  Future<List<SavedResumableConversation>> load();

  Future<void> save(List<SavedResumableConversation> conversations);
}

abstract interface class CodexConnectionConversationHistoryStore {
  Future<List<SavedResumableConversation>> load(String connectionId);

  Future<void> save(
    String connectionId,
    List<SavedResumableConversation> conversations,
  );

  Future<void> delete(String connectionId);
}

abstract interface class CodexConnectionConversationStateStore {
  Future<SavedConnectionConversationState> loadState(String connectionId);

  Future<void> saveState(
    String connectionId,
    SavedConnectionConversationState state,
  );

  Future<void> deleteState(String connectionId);
}

class SecureCodexConnectionConversationHistoryStore
    implements
        CodexConnectionConversationHistoryStore,
        CodexConnectionConversationStateStore {
  static const _stateKeyPrefix = 'pocket_relay.connection.';
  static const _stateKeySuffix = '.conversation_state';
  static const _legacyHistoryKeySuffix = '.conversation_history';
  static const _legacyHandoffKeySuffix = '.conversation_handoff';
  static const _preferencesMigrationKey =
      'pocket_relay.connection_conversation_history_async_migration_complete';

  SecureCodexConnectionConversationHistoryStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences;

  SharedPreferencesAsync? _preferences;
  final MemoryCodexConnectionConversationHistoryStore _fallbackStore =
      MemoryCodexConnectionConversationHistoryStore();
  Future<void>? _preferencesReady;

  @override
  Future<List<SavedResumableConversation>> load(String connectionId) async {
    final state = await loadState(connectionId);
    return List<SavedResumableConversation>.from(state.conversations);
  }

  @override
  Future<void> save(
    String connectionId,
    List<SavedResumableConversation> conversations,
  ) async {
    final currentState = await loadState(connectionId);
    await saveState(
      connectionId,
      currentState.copyWith(conversations: conversations),
    );
  }

  @override
  Future<void> delete(String connectionId) {
    return deleteState(connectionId);
  }

  @override
  Future<SavedConnectionConversationState> loadState(
    String connectionId,
  ) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      return _fallbackStore.loadState(normalizedConnectionId);
    }

    await _ensurePreferencesReady();
    final rawState = await preferences.getString(
      _stateKeyForConnection(normalizedConnectionId),
    );
    if (rawState != null && rawState.trim().isNotEmpty) {
      return SavedConnectionConversationState.fromJson(
        jsonDecode(rawState) as Map<String, dynamic>,
      );
    }

    final migratedState = await _loadLegacyState(normalizedConnectionId);
    if (migratedState == null) {
      return const SavedConnectionConversationState();
    }

    await saveState(normalizedConnectionId, migratedState);
    return migratedState;
  }

  @override
  Future<void> saveState(
    String connectionId,
    SavedConnectionConversationState state,
  ) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      await _fallbackStore.saveState(normalizedConnectionId, state);
      return;
    }

    await _ensurePreferencesReady();
    final normalizedState = SavedConnectionConversationState(
      selectedThreadId: state.normalizedSelectedThreadId,
      conversations: state.conversations
          .where((entry) => entry.normalizedThreadId.isNotEmpty)
          .toList(growable: false),
    );
    final key = _stateKeyForConnection(normalizedConnectionId);
    if (normalizedState.normalizedSelectedThreadId == null &&
        normalizedState.conversations.isEmpty) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, jsonEncode(normalizedState.toJson()));
    }

    await preferences.remove(
      _legacyHistoryKeyForConnection(normalizedConnectionId),
    );
    await preferences.remove(
      _legacyHandoffKeyForConnection(normalizedConnectionId),
    );
  }

  @override
  Future<void> deleteState(String connectionId) async {
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      await _fallbackStore.deleteState(normalizedConnectionId);
      return;
    }

    await _ensurePreferencesReady();
    await preferences.remove(_stateKeyForConnection(normalizedConnectionId));
    await preferences.remove(
      _legacyHistoryKeyForConnection(normalizedConnectionId),
    );
    await preferences.remove(
      _legacyHandoffKeyForConnection(normalizedConnectionId),
    );
  }

  Future<SavedConnectionConversationState?> _loadLegacyState(
    String connectionId,
  ) async {
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      return null;
    }

    final rawHistory = await preferences.getString(
      _legacyHistoryKeyForConnection(connectionId),
    );
    final rawHandoff = await preferences.getString(
      _legacyHandoffKeyForConnection(connectionId),
    );
    if ((rawHistory == null || rawHistory.trim().isEmpty) &&
        (rawHandoff == null || rawHandoff.trim().isEmpty)) {
      return null;
    }

    final conversations = rawHistory == null || rawHistory.trim().isEmpty
        ? const <SavedResumableConversation>[]
        : _decodeLegacyHistory(rawHistory);
    final selectedThreadId = rawHandoff == null || rawHandoff.trim().isEmpty
        ? null
        : SavedConversationHandoff.fromJson(
            jsonDecode(rawHandoff) as Map<String, dynamic>,
          ).normalizedResumeThreadId;

    final alreadyPresent = selectedThreadId == null
        ? true
        : conversations.any(
            (entry) => entry.normalizedThreadId == selectedThreadId,
          );
    return SavedConnectionConversationState(
      selectedThreadId: selectedThreadId,
      conversations: alreadyPresent
          ? conversations
          : <SavedResumableConversation>[
              SavedResumableConversation(
                threadId: selectedThreadId,
                preview: '',
                messageCount: 1,
                firstPromptAt: null,
                lastActivityAt: null,
              ),
              ...conversations,
            ],
    );
  }

  List<SavedResumableConversation> _decodeLegacyHistory(String rawHistory) {
    final decoded = jsonDecode(rawHistory);
    if (decoded is! List) {
      return const <SavedResumableConversation>[];
    }

    return decoded
        .whereType<Map>()
        .map(
          (entry) => SavedResumableConversation.fromJson(
            Map<String, dynamic>.from(entry),
          ),
        )
        .where((entry) => entry.normalizedThreadId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _ensurePreferencesReady() {
    if (_resolvedPreferences == null) {
      return Future<void>.value();
    }
    return _preferencesReady ??= ensureSharedPreferencesAsyncReady(
      migrationCompletedKey: _preferencesMigrationKey,
    );
  }

  SharedPreferencesAsync? get _resolvedPreferences {
    return _preferences ??= _tryCreatePreferences();
  }

  SharedPreferencesAsync? _tryCreatePreferences() {
    try {
      return SharedPreferencesAsync();
    } on StateError {
      return null;
    }
  }

  String _normalizeConnectionId(String connectionId) {
    final normalizedConnectionId = connectionId.trim();
    if (normalizedConnectionId.isEmpty) {
      throw ArgumentError.value(
        connectionId,
        'connectionId',
        'Connection id must not be empty.',
      );
    }
    return normalizedConnectionId;
  }

  String _stateKeyForConnection(String connectionId) {
    return '$_stateKeyPrefix$connectionId$_stateKeySuffix';
  }

  String _legacyHistoryKeyForConnection(String connectionId) {
    return '$_stateKeyPrefix$connectionId$_legacyHistoryKeySuffix';
  }

  String _legacyHandoffKeyForConnection(String connectionId) {
    return '$_stateKeyPrefix$connectionId$_legacyHandoffKeySuffix';
  }
}

class MemoryCodexConnectionConversationHistoryStore
    implements
        CodexConnectionConversationHistoryStore,
        CodexConnectionConversationStateStore {
  MemoryCodexConnectionConversationHistoryStore({
    Map<String, List<SavedResumableConversation>>? initialValues,
    Map<String, SavedConnectionConversationState>? initialStates,
  }) : _statesByConnectionId = initialStates == null
           ? <String, SavedConnectionConversationState>{
               if (initialValues != null)
                 for (final entry in initialValues.entries)
                   entry.key: SavedConnectionConversationState(
                     conversations: List<SavedResumableConversation>.from(
                       entry.value,
                     ),
                   ),
             }
           : initialStates.map(
               (key, value) =>
                   MapEntry<String, SavedConnectionConversationState>(
                     key,
                     SavedConnectionConversationState(
                       selectedThreadId: value.selectedThreadId,
                       conversations: List<SavedResumableConversation>.from(
                         value.conversations,
                       ),
                     ),
                   ),
             );

  final Map<String, SavedConnectionConversationState> _statesByConnectionId;

  @override
  Future<List<SavedResumableConversation>> load(String connectionId) async {
    return List<SavedResumableConversation>.from(
      (await loadState(connectionId)).conversations,
    );
  }

  @override
  Future<void> save(
    String connectionId,
    List<SavedResumableConversation> conversations,
  ) async {
    final state = await loadState(connectionId);
    await saveState(connectionId, state.copyWith(conversations: conversations));
  }

  @override
  Future<void> delete(String connectionId) {
    return deleteState(connectionId);
  }

  @override
  Future<SavedConnectionConversationState> loadState(
    String connectionId,
  ) async {
    final state = _statesByConnectionId[connectionId];
    if (state == null) {
      return const SavedConnectionConversationState();
    }
    return SavedConnectionConversationState(
      selectedThreadId: state.selectedThreadId,
      conversations: List<SavedResumableConversation>.from(state.conversations),
    );
  }

  @override
  Future<void> saveState(
    String connectionId,
    SavedConnectionConversationState state,
  ) async {
    if (state.normalizedSelectedThreadId == null &&
        state.conversations.isEmpty) {
      _statesByConnectionId.remove(connectionId);
      return;
    }

    _statesByConnectionId[connectionId] = SavedConnectionConversationState(
      selectedThreadId: state.normalizedSelectedThreadId,
      conversations: List<SavedResumableConversation>.from(state.conversations),
    );
  }

  @override
  Future<void> deleteState(String connectionId) async {
    _statesByConnectionId.remove(connectionId);
  }
}

class DiscardingCodexConversationHistoryStore
    implements CodexConversationHistoryStore {
  const DiscardingCodexConversationHistoryStore();

  @override
  Future<List<SavedResumableConversation>> load() async {
    return const <SavedResumableConversation>[];
  }

  @override
  Future<void> save(List<SavedResumableConversation> conversations) async {}
}
