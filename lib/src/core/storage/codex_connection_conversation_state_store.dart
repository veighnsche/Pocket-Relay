import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'codex_connection_conversation_state_legacy_migration.dart';

/// This file is not the home for authoritative historical conversation data.
///
/// Pocket Relay only persists narrow connection-scoped lane state here,
/// currently `selectedThreadId`.
///
/// Pocket Relay may own other live session/runtime state elsewhere, but
/// historical conversation lists and historical transcript content belong to
/// Codex and must be read from Codex when needed.

class SavedConnectionConversationState {
  const SavedConnectionConversationState({this.selectedThreadId});

  /// The app may remember which upstream thread should be resumed, but it must
  /// not persist its own historical transcript archive.
  final String? selectedThreadId;

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
  }) {
    return SavedConnectionConversationState(
      selectedThreadId: clearSelectedThreadId
          ? null
          : (selectedThreadId ?? this.selectedThreadId),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'selectedThreadId': normalizedSelectedThreadId};
  }

  factory SavedConnectionConversationState.fromJson(Map<String, dynamic> json) {
    return SavedConnectionConversationState(
      selectedThreadId: json['selectedThreadId'] as String?,
    );
  }
}

abstract interface class CodexConversationStateStore {
  Future<SavedConnectionConversationState> loadState();

  Future<void> saveState(SavedConnectionConversationState state);
}

abstract interface class CodexConnectionConversationStateStore {
  /// Loads connection-scoped lane state only.
  ///
  /// This store must not become a source of truth for historical conversation
  /// lists or historical transcript content.
  Future<SavedConnectionConversationState> loadState(String connectionId);

  Future<void> saveState(
    String connectionId,
    SavedConnectionConversationState state,
  );

  Future<void> deleteState(String connectionId);
}

class SecureCodexConnectionConversationStateStore
    implements CodexConnectionConversationStateStore {
  static const _stateKeyPrefix = 'pocket_relay.connection.';
  static const _stateKeySuffix = '.conversation_state';
  static const _legacyMigration = CodexConnectionConversationStateLegacyMigration(
    stateKeyPrefix: _stateKeyPrefix,
    preferencesMigrationKey:
        'pocket_relay.connection_conversation_history_async_migration_complete',
  );

  SecureCodexConnectionConversationStateStore({
    SharedPreferencesAsync? preferences,
  }) : _preferences = preferences;

  SharedPreferencesAsync? _preferences;
  final MemoryCodexConnectionConversationStateStore _fallbackStore =
      MemoryCodexConnectionConversationStateStore();
  Future<void>? _preferencesReady;

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

    final migratedSelectedThreadId = await _legacyMigration
        .loadLegacySelectedThreadId(preferences, normalizedConnectionId);
    if (migratedSelectedThreadId == null) {
      return const SavedConnectionConversationState();
    }

    final migratedState = SavedConnectionConversationState(
      selectedThreadId: migratedSelectedThreadId,
    );
    await saveState(normalizedConnectionId, migratedState);
    return migratedState;
  }

  @override
  Future<void> saveState(
    String connectionId,
    SavedConnectionConversationState state,
  ) async {
    // Persist only lightweight lane state. Historical transcript content must
    // remain upstream in Codex because most work may happen outside this app.
    final normalizedConnectionId = _normalizeConnectionId(connectionId);
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      await _fallbackStore.saveState(normalizedConnectionId, state);
      return;
    }

    await _ensurePreferencesReady();
    final normalizedState = SavedConnectionConversationState(
      selectedThreadId: state.normalizedSelectedThreadId,
    );
    final key = _stateKeyForConnection(normalizedConnectionId);
    if (normalizedState.normalizedSelectedThreadId == null) {
      await preferences.remove(key);
    } else {
      await preferences.setString(key, jsonEncode(normalizedState.toJson()));
    }

    await _legacyMigration.clearLegacyKeys(preferences, normalizedConnectionId);
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
    await _legacyMigration.clearLegacyKeys(preferences, normalizedConnectionId);
  }

  Future<void> _ensurePreferencesReady() {
    if (_resolvedPreferences == null) {
      return Future<void>.value();
    }
    return _preferencesReady ??= _legacyMigration.ensurePreferencesReady();
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
}

class MemoryCodexConnectionConversationStateStore
    implements CodexConnectionConversationStateStore {
  MemoryCodexConnectionConversationStateStore({
    Map<String, SavedConnectionConversationState>? initialStates,
  }) : _statesByConnectionId =
           (initialStates ?? const <String, SavedConnectionConversationState>{})
               .map(
                 (key, value) =>
                     MapEntry<String, SavedConnectionConversationState>(
                       key,
                       SavedConnectionConversationState(
                         selectedThreadId: value.selectedThreadId,
                       ),
                     ),
               );

  final Map<String, SavedConnectionConversationState> _statesByConnectionId;

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
    );
  }

  @override
  Future<void> saveState(
    String connectionId,
    SavedConnectionConversationState state,
  ) async {
    if (state.normalizedSelectedThreadId == null) {
      _statesByConnectionId.remove(connectionId);
      return;
    }

    _statesByConnectionId[connectionId] = SavedConnectionConversationState(
      selectedThreadId: state.normalizedSelectedThreadId,
    );
  }

  @override
  Future<void> deleteState(String connectionId) async {
    _statesByConnectionId.remove(connectionId);
  }
}

class DiscardingCodexConversationStateStore
    implements CodexConversationStateStore {
  const DiscardingCodexConversationStateStore();

  @override
  Future<SavedConnectionConversationState> loadState() async {
    return const SavedConnectionConversationState();
  }

  @override
  Future<void> saveState(SavedConnectionConversationState state) async {}
}
