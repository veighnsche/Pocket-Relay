import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/util/legacy_to_async_migration_util.dart';

class SavedConversationHandoff {
  const SavedConversationHandoff({this.resumeThreadId});

  final String? resumeThreadId;

  String? get normalizedResumeThreadId {
    final normalized = resumeThreadId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{'resumeThreadId': normalizedResumeThreadId};
  }

  factory SavedConversationHandoff.fromJson(Map<String, dynamic> json) {
    return SavedConversationHandoff(
      resumeThreadId: json['resumeThreadId'] as String?,
    );
  }

  SavedConversationHandoff copyWith({
    String? resumeThreadId,
    bool clearResumeThreadId = false,
  }) {
    return SavedConversationHandoff(
      resumeThreadId: clearResumeThreadId
          ? null
          : (resumeThreadId ?? this.resumeThreadId),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SavedConversationHandoff &&
        other.normalizedResumeThreadId == normalizedResumeThreadId;
  }

  @override
  int get hashCode => normalizedResumeThreadId.hashCode;
}

abstract class CodexConversationHandoffStore {
  Future<SavedConversationHandoff> load();

  Future<void> save(SavedConversationHandoff handoff);
}

class SecureCodexConversationHandoffStore
    implements CodexConversationHandoffStore {
  static const _handoffKey = 'pocket_relay.conversation_handoff';
  static const _legacyHandoffKey = 'codex_pocket.conversation_handoff';
  static const _preferencesMigrationKey =
      'pocket_relay.conversation_handoff_async_migration_complete';

  SecureCodexConversationHandoffStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  SharedPreferencesAsync? _preferences;
  final MemoryCodexConversationHandoffStore _fallbackStore =
      MemoryCodexConversationHandoffStore();
  Future<void>? _preferencesReady;

  @override
  Future<SavedConversationHandoff> load() async {
    if (_resolvedPreferences == null) {
      return _fallbackStore.load();
    }

    await _ensurePreferencesReady();
    final rawHandoff = await _readHandoff();
    if (rawHandoff == null || rawHandoff.trim().isEmpty) {
      return const SavedConversationHandoff();
    }

    return SavedConversationHandoff.fromJson(
      jsonDecode(rawHandoff) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> save(SavedConversationHandoff handoff) async {
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      await _fallbackStore.save(handoff);
      return;
    }

    await _ensurePreferencesReady();
    final normalizedThreadId = handoff.normalizedResumeThreadId;
    if (normalizedThreadId == null) {
      await preferences.remove(_handoffKey);
      await preferences.remove(_legacyHandoffKey);
      return;
    }

    await preferences.setString(_handoffKey, jsonEncode(handoff.toJson()));
    await preferences.remove(_legacyHandoffKey);
  }

  Future<String?> _readHandoff() async {
    final preferences = _resolvedPreferences;
    if (preferences == null) {
      return null;
    }

    final currentHandoff = await preferences.getString(_handoffKey);
    if (currentHandoff != null) {
      return currentHandoff;
    }

    final legacyHandoff = await preferences.getString(_legacyHandoffKey);
    if (legacyHandoff == null) {
      return null;
    }

    await preferences.setString(_handoffKey, legacyHandoff);
    await preferences.remove(_legacyHandoffKey);
    return legacyHandoff;
  }

  Future<void> _ensurePreferencesReady() {
    if (_resolvedPreferences == null) {
      return Future<void>.value();
    }
    return _preferencesReady ??= _migrateLegacyPreferencesIfNeeded();
  }

  Future<void> _migrateLegacyPreferencesIfNeeded() async {
    final legacyPreferences = await SharedPreferences.getInstance();
    await migrateLegacySharedPreferencesToSharedPreferencesAsyncIfNecessary(
      legacySharedPreferencesInstance: legacyPreferences,
      sharedPreferencesAsyncOptions: const SharedPreferencesOptions(),
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
}

class MemoryCodexConversationHandoffStore
    implements CodexConversationHandoffStore {
  MemoryCodexConversationHandoffStore({SavedConversationHandoff? initialValue})
    : _savedHandoff = initialValue ?? const SavedConversationHandoff();

  SavedConversationHandoff _savedHandoff;

  @override
  Future<SavedConversationHandoff> load() async => _savedHandoff;

  @override
  Future<void> save(SavedConversationHandoff handoff) async {
    _savedHandoff = handoff;
  }
}

class DiscardingCodexConversationHandoffStore
    implements CodexConversationHandoffStore {
  const DiscardingCodexConversationHandoffStore();

  @override
  Future<SavedConversationHandoff> load() async {
    return const SavedConversationHandoff();
  }

  @override
  Future<void> save(SavedConversationHandoff handoff) async {}
}
