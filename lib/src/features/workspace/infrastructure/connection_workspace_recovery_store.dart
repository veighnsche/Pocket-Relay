import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pocket_relay/src/core/storage/shared_preferences_async_migration.dart';

class ConnectionWorkspaceRecoveryState {
  const ConnectionWorkspaceRecoveryState({
    required this.connectionId,
    required this.draftText,
    this.selectedThreadId,
    this.backgroundedAt,
  });

  final String connectionId;
  final String draftText;
  final String? selectedThreadId;
  final DateTime? backgroundedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'connectionId': connectionId,
      'draftText': draftText,
      'selectedThreadId': selectedThreadId,
      'backgroundedAt': backgroundedAt?.toIso8601String(),
    };
  }

  factory ConnectionWorkspaceRecoveryState.fromJson(Map<String, dynamic> json) {
    return ConnectionWorkspaceRecoveryState(
      connectionId: _normalizedRecoveryString(json['connectionId']) ?? '',
      draftText: json['draftText'] as String? ?? '',
      selectedThreadId: _normalizedRecoveryString(json['selectedThreadId']),
      backgroundedAt: _parseRecoveryDateTime(json['backgroundedAt']),
    );
  }
}

abstract interface class ConnectionWorkspaceRecoveryStore {
  Future<ConnectionWorkspaceRecoveryState?> load();

  Future<void> save(ConnectionWorkspaceRecoveryState? state);
}

class NoopConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  const NoopConnectionWorkspaceRecoveryStore();

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async => null;

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {}
}

class MemoryConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  MemoryConnectionWorkspaceRecoveryStore({
    ConnectionWorkspaceRecoveryState? initialState,
  }) : _state = initialState;

  ConnectionWorkspaceRecoveryState? _state;

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async => _state;

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    _state = state;
  }
}

class SecureConnectionWorkspaceRecoveryStore
    implements ConnectionWorkspaceRecoveryStore {
  static const _recoveryStateKey = 'pocket_relay.workspace.recovery_state';
  static const _draftTextStorageKey =
      'pocket_relay.workspace.recovery_state.draft_text';
  static const _legacyDraftTextKey = 'draftText';
  static const _preferencesMigrationKey =
      'pocket_relay.workspace_recovery_async_migration_complete';

  SecureConnectionWorkspaceRecoveryStore({
    FlutterSecureStorage? secureStorage,
    SharedPreferencesAsync? preferences,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _preferences = preferences ?? SharedPreferencesAsync();

  final FlutterSecureStorage _secureStorage;
  final SharedPreferencesAsync _preferences;
  Future<void>? _preferencesReady;

  @override
  Future<ConnectionWorkspaceRecoveryState?> load() async {
    await _ensurePreferencesReady();
    final rawState = await _preferences.getString(_recoveryStateKey);
    if (rawState == null || rawState.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(rawState);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final sanitizedMap = Map<String, dynamic>.from(decoded)
      ..remove(_legacyDraftTextKey);
    final hasLegacyDraftText = decoded.containsKey(_legacyDraftTextKey);
    final legacyDraftText = _recoveryDraftText(decoded[_legacyDraftTextKey]);
    if (hasLegacyDraftText) {
      await _preferences.setString(
        _recoveryStateKey,
        jsonEncode(_persistableStateJson(sanitizedMap)),
      );
    }

    final state = ConnectionWorkspaceRecoveryState.fromJson(sanitizedMap);
    if (state.connectionId.isEmpty) {
      return null;
    }
    final persistedDraftText = await _readDraftText();
    final effectiveDraftText = persistedDraftText.isNotEmpty
        ? persistedDraftText
        : legacyDraftText;
    if (hasLegacyDraftText &&
        persistedDraftText.isEmpty &&
        legacyDraftText.isNotEmpty) {
      await _writeDraftText(legacyDraftText);
    }
    return ConnectionWorkspaceRecoveryState(
      connectionId: state.connectionId,
      selectedThreadId: state.selectedThreadId,
      draftText: effectiveDraftText,
      backgroundedAt: state.backgroundedAt,
    );
  }

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    await _ensurePreferencesReady();
    if (state == null) {
      await _preferences.remove(_recoveryStateKey);
      await _deleteDraftText();
      return;
    }

    await _preferences.setString(
      _recoveryStateKey,
      jsonEncode(_persistableStateJson(state.toJson())),
    );
    await _writeDraftText(state.draftText);
  }

  Future<void> _ensurePreferencesReady() {
    return _preferencesReady ??= ensureSharedPreferencesAsyncReady(
      migrationCompletedKey: _preferencesMigrationKey,
    );
  }

  Future<String> _readDraftText() async {
    return await _secureStorage.read(key: _draftTextStorageKey) ?? '';
  }

  Future<void> _writeDraftText(String value) async {
    if (value.isEmpty) {
      await _deleteDraftText();
      return;
    }
    await _secureStorage.write(key: _draftTextStorageKey, value: value);
  }

  Future<void> _deleteDraftText() {
    return _secureStorage.delete(key: _draftTextStorageKey);
  }
}

Map<String, Object?> _persistableStateJson(Map<String, dynamic> json) {
  return <String, Object?>{
    'connectionId': _normalizedRecoveryString(json['connectionId']) ?? '',
    'selectedThreadId': _normalizedRecoveryString(json['selectedThreadId']),
    'backgroundedAt': _parseRecoveryDateTime(
      json['backgroundedAt'],
    )?.toIso8601String(),
  };
}

DateTime? _parseRecoveryDateTime(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String? _normalizedRecoveryString(Object? value) {
  if (value is! String) {
    return null;
  }
  final normalizedValue = value.trim();
  return normalizedValue.isEmpty ? null : normalizedValue;
}

String _recoveryDraftText(Object? value) {
  return value is String ? value : '';
}
