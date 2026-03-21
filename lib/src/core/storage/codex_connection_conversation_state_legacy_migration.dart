import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'shared_preferences_async_migration.dart';

class CodexConnectionConversationStateLegacyMigration {
  const CodexConnectionConversationStateLegacyMigration({
    required this.stateKeyPrefix,
    required this.preferencesMigrationKey,
  });

  final String stateKeyPrefix;
  final String preferencesMigrationKey;

  static const _legacyHistoryKeySuffix = '.conversation_history';
  static const _legacyHandoffKeySuffix = '.conversation_handoff';

  Future<void> ensurePreferencesReady() {
    return ensureSharedPreferencesAsyncReady(
      migrationCompletedKey: preferencesMigrationKey,
    );
  }

  Future<String?> loadLegacySelectedThreadId(
    SharedPreferencesAsync preferences,
    String connectionId,
  ) async {
    final rawHandoff = await preferences.getString(
      _legacyHandoffKeyForConnection(connectionId),
    );
    if (rawHandoff == null || rawHandoff.trim().isEmpty) {
      return null;
    }

    final payload = jsonDecode(rawHandoff);
    if (payload is! Map) {
      return null;
    }

    final selectedThreadId = payload['resumeThreadId'];
    if (selectedThreadId is! String) {
      return null;
    }

    final normalizedThreadId = selectedThreadId.trim();
    return normalizedThreadId.isEmpty ? null : normalizedThreadId;
  }

  Future<void> clearLegacyKeys(
    SharedPreferencesAsync preferences,
    String connectionId,
  ) async {
    await preferences.remove(_legacyHistoryKeyForConnection(connectionId));
    await preferences.remove(_legacyHandoffKeyForConnection(connectionId));
  }

  String _legacyHistoryKeyForConnection(String connectionId) {
    return '$stateKeyPrefix$connectionId$_legacyHistoryKeySuffix';
  }

  String _legacyHandoffKeyForConnection(String connectionId) {
    return '$stateKeyPrefix$connectionId$_legacyHandoffKeySuffix';
  }
}
