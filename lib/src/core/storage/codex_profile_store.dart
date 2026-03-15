import 'dart:convert';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences/util/legacy_to_async_migration_util.dart';

abstract class CodexProfileStore {
  Future<SavedProfile> load();

  Future<void> save(ConnectionProfile profile, ConnectionSecrets secrets);
}

class SecureCodexProfileStore implements CodexProfileStore {
  static const _profileKey = 'pocket_relay.profile';
  static const _legacyProfileKey = 'codex_pocket.profile';
  static const _obsoletePreferencesKey = 'pocket_relay.preferences';
  static const _preferencesMigrationKey =
      'pocket_relay.preferences_async_migration_complete';
  static const _passwordKey = 'pocket_relay.secret.password';
  static const _legacyPasswordKey = 'codex_pocket.secret.password';
  static const _privateKeyKey = 'pocket_relay.secret.private_key';
  static const _legacyPrivateKeyKey = 'codex_pocket.secret.private_key';
  static const _privateKeyPassphraseKey =
      'pocket_relay.secret.private_key_passphrase';
  static const _legacyPrivateKeyPassphraseKey =
      'codex_pocket.secret.private_key_passphrase';

  final FlutterSecureStorage _secureStorage;
  final SharedPreferencesAsync _preferences;
  Future<void>? _preferencesReady;

  SecureCodexProfileStore({
    FlutterSecureStorage? secureStorage,
    SharedPreferencesAsync? preferences,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _preferences = preferences ?? SharedPreferencesAsync();

  @override
  Future<SavedProfile> load() async {
    await _ensurePreferencesReady();
    final rawProfile = await _readProfile();
    await _preferences.remove(_obsoletePreferencesKey);
    final profile = rawProfile == null
        ? ConnectionProfile.defaults()
        : ConnectionProfile.fromJson(
            jsonDecode(rawProfile) as Map<String, dynamic>,
          );

    final password = await _readSecret(_passwordKey, _legacyPasswordKey);
    final privateKeyPem = await _readSecret(
      _privateKeyKey,
      _legacyPrivateKeyKey,
    );
    final privateKeyPassphrase = await _readSecret(
      _privateKeyPassphraseKey,
      _legacyPrivateKeyPassphraseKey,
    );

    return SavedProfile(
      profile: profile,
      secrets: ConnectionSecrets(
        password: password,
        privateKeyPem: privateKeyPem,
        privateKeyPassphrase: privateKeyPassphrase,
      ),
    );
  }

  @override
  Future<void> save(
    ConnectionProfile profile,
    ConnectionSecrets secrets,
  ) async {
    await _ensurePreferencesReady();
    await _preferences.setString(_profileKey, jsonEncode(profile.toJson()));
    await _preferences.remove(_legacyProfileKey);
    await _preferences.remove(_obsoletePreferencesKey);

    await _writeSecret(_passwordKey, _legacyPasswordKey, secrets.password);
    await _writeSecret(
      _privateKeyKey,
      _legacyPrivateKeyKey,
      secrets.privateKeyPem,
    );
    await _writeSecret(
      _privateKeyPassphraseKey,
      _legacyPrivateKeyPassphraseKey,
      secrets.privateKeyPassphrase,
    );
  }

  Future<void> _writeSecret(String key, String legacyKey, String value) async {
    if (value.trim().isEmpty) {
      await _secureStorage.delete(key: key);
      await _secureStorage.delete(key: legacyKey);
      return;
    }

    await _secureStorage.write(key: key, value: value);
    await _secureStorage.delete(key: legacyKey);
  }

  Future<String> _readSecret(String key, String legacyKey) async {
    final currentValue = await _secureStorage.read(key: key);
    if (currentValue != null) {
      return currentValue;
    }

    final legacyValue = await _secureStorage.read(key: legacyKey);
    if (legacyValue == null) {
      return '';
    }

    await _secureStorage.write(key: key, value: legacyValue);
    await _secureStorage.delete(key: legacyKey);
    return legacyValue;
  }

  Future<String?> _readProfile() async {
    final currentProfile = await _preferences.getString(_profileKey);
    if (currentProfile != null) {
      return currentProfile;
    }

    final legacyProfile = await _preferences.getString(_legacyProfileKey);
    if (legacyProfile == null) {
      return null;
    }

    await _preferences.setString(_profileKey, legacyProfile);
    await _preferences.remove(_legacyProfileKey);
    return legacyProfile;
  }

  Future<void> _ensurePreferencesReady() {
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
}

class MemoryCodexProfileStore implements CodexProfileStore {
  MemoryCodexProfileStore({SavedProfile? initialValue})
    : _savedProfile =
          initialValue ??
          SavedProfile(
            profile: ConnectionProfile.defaults(),
            secrets: const ConnectionSecrets(),
          );

  SavedProfile _savedProfile;

  @override
  Future<SavedProfile> load() async => _savedProfile;

  @override
  Future<void> save(
    ConnectionProfile profile,
    ConnectionSecrets secrets,
  ) async {
    _savedProfile = _savedProfile.copyWith(profile: profile, secrets: secrets);
  }
}
