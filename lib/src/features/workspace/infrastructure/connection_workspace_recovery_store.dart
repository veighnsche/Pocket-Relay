import 'dart:convert';

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
  static const _preferencesMigrationKey =
      'pocket_relay.workspace_recovery_async_migration_complete';

  SecureConnectionWorkspaceRecoveryStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

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

    final state = ConnectionWorkspaceRecoveryState.fromJson(decoded);
    if (state.connectionId.isEmpty) {
      return null;
    }
    return state;
  }

  @override
  Future<void> save(ConnectionWorkspaceRecoveryState? state) async {
    await _ensurePreferencesReady();
    if (state == null) {
      await _preferences.remove(_recoveryStateKey);
      return;
    }

    await _preferences.setString(_recoveryStateKey, jsonEncode(state.toJson()));
  }

  Future<void> _ensurePreferencesReady() {
    return _preferencesReady ??= ensureSharedPreferencesAsyncReady(
      migrationCompletedKey: _preferencesMigrationKey,
    );
  }
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
