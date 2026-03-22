import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pocket_relay/src/core/storage/shared_preferences_async_migration.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';

class ConnectionWorkspaceRecoveryState {
  const ConnectionWorkspaceRecoveryState({
    required this.connectionId,
    required this.draftText,
    this.selectedThreadId,
    this.backgroundedAt,
    this.backgroundedLifecycleState,
  });

  final String connectionId;
  final String draftText;
  final String? selectedThreadId;
  final DateTime? backgroundedAt;
  final ConnectionWorkspaceBackgroundLifecycleState? backgroundedLifecycleState;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'connectionId': connectionId,
      'draftText': draftText,
      'selectedThreadId': selectedThreadId,
      'backgroundedAt': backgroundedAt?.toIso8601String(),
      'backgroundedLifecycleState': backgroundedLifecycleState?.name,
    };
  }

  factory ConnectionWorkspaceRecoveryState.fromJson(Map<String, dynamic> json) {
    return ConnectionWorkspaceRecoveryState(
      connectionId: _normalizedRecoveryString(json['connectionId']) ?? '',
      draftText: json['draftText'] as String? ?? '',
      selectedThreadId: _normalizedRecoveryString(json['selectedThreadId']),
      backgroundedAt: _parseRecoveryDateTime(json['backgroundedAt']),
      backgroundedLifecycleState: _parseBackgroundLifecycleState(
        json['backgroundedLifecycleState'],
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ConnectionWorkspaceRecoveryState &&
        other.connectionId == connectionId &&
        other.draftText == draftText &&
        other.selectedThreadId == selectedThreadId &&
        other.backgroundedAt == backgroundedAt;
  }

  @override
  int get hashCode =>
      Object.hash(connectionId, draftText, selectedThreadId, backgroundedAt);
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
  static const _legacyDraftTextStorageKey =
      'pocket_relay.workspace.recovery_state.draft_text';
  static const _draftTextStorageKeyPrefix =
      'pocket_relay.workspace.recovery_state.draft_text.';
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
    final state = ConnectionWorkspaceRecoveryState.fromJson(sanitizedMap);
    if (state.connectionId.isEmpty) {
      return null;
    }

    final hasLegacyDraftText = decoded.containsKey(_legacyDraftTextKey);
    final legacyDraftText = _recoveryDraftText(decoded[_legacyDraftTextKey]);
    var persistedDraftText = await _readDraftText(state.connectionId);
    final legacySecureDraftText = persistedDraftText.isEmpty
        ? await _readLegacyDraftText()
        : '';
    if (persistedDraftText.isEmpty && legacySecureDraftText.isNotEmpty) {
      await _writeDraftText(state.connectionId, legacySecureDraftText);
      await _deleteLegacyDraftText();
      persistedDraftText = legacySecureDraftText;
    }
    if (hasLegacyDraftText) {
      if (persistedDraftText.isEmpty && legacyDraftText.isNotEmpty) {
        await _writeDraftText(state.connectionId, legacyDraftText);
        persistedDraftText = legacyDraftText;
      }
      await _preferences.setString(
        _recoveryStateKey,
        jsonEncode(_persistableStateJson(sanitizedMap)),
      );
    }

    final effectiveDraftText = persistedDraftText.isNotEmpty
        ? persistedDraftText
        : legacyDraftText;
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
      final persistedConnectionId = await _loadPersistedConnectionId();
      await _preferences.remove(_recoveryStateKey);
      if (persistedConnectionId != null) {
        await _deleteDraftText(persistedConnectionId);
      }
      await _deleteLegacyDraftText();
      return;
    }

    await _writeDraftText(state.connectionId, state.draftText);
    await _deleteLegacyDraftText();
    await _preferences.setString(
      _recoveryStateKey,
      jsonEncode(_persistableStateJson(state.toJson())),
    );
  }

  Future<void> _ensurePreferencesReady() {
    return _preferencesReady ??= ensureSharedPreferencesAsyncReady(
      migrationCompletedKey: _preferencesMigrationKey,
    );
  }

  Future<String?> _loadPersistedConnectionId() async {
    final rawState = await _preferences.getString(_recoveryStateKey);
    if (rawState == null || rawState.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(rawState);
      if (decoded is! Map) {
        return null;
      }
      return _normalizedRecoveryString(
        Map<String, dynamic>.from(decoded)['connectionId'],
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _readDraftText(String connectionId) async {
    return await _secureStorage.read(
          key: _draftTextStorageKeyForConnection(connectionId),
        ) ??
        '';
  }

  Future<String> _readLegacyDraftText() async {
    return await _secureStorage.read(key: _legacyDraftTextStorageKey) ?? '';
  }

  Future<void> _writeDraftText(String connectionId, String value) async {
    if (value.isEmpty) {
      await _deleteDraftText(connectionId);
      return;
    }
    await _secureStorage.write(
      key: _draftTextStorageKeyForConnection(connectionId),
      value: value,
    );
  }

  Future<void> _deleteDraftText(String connectionId) {
    return _secureStorage.delete(
      key: _draftTextStorageKeyForConnection(connectionId),
    );
  }

  Future<void> _deleteLegacyDraftText() {
    return _secureStorage.delete(key: _legacyDraftTextStorageKey);
  }
}

String _draftTextStorageKeyForConnection(String connectionId) {
  final normalizedConnectionId = _normalizedRecoveryString(connectionId) ?? '';
  return '${
      SecureConnectionWorkspaceRecoveryStore._draftTextStorageKeyPrefix
    }$normalizedConnectionId';
}

Map<String, Object?> _persistableStateJson(Map<String, dynamic> json) {
  return <String, Object?>{
    'connectionId': _normalizedRecoveryString(json['connectionId']) ?? '',
    'selectedThreadId': _normalizedRecoveryString(json['selectedThreadId']),
    'backgroundedAt': _parseRecoveryDateTime(
      json['backgroundedAt'],
    )?.toIso8601String(),
    'backgroundedLifecycleState': _parseBackgroundLifecycleState(
      json['backgroundedLifecycleState'],
    )?.name,
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

ConnectionWorkspaceBackgroundLifecycleState? _parseBackgroundLifecycleState(
  Object? value,
) {
  final normalizedValue = _normalizedRecoveryString(value);
  if (normalizedValue == null) {
    return null;
  }

  for (final lifecycleState
      in ConnectionWorkspaceBackgroundLifecycleState.values) {
    if (lifecycleState.name == normalizedValue) {
      return lifecycleState;
    }
  }
  return null;
}

String _recoveryDraftText(Object? value) {
  return value is String ? value : '';
}
