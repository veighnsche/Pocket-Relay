import 'dart:convert';

import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class CodexProfileStore {
  Future<SavedProfile> load();

  Future<void> save(ConnectionProfile profile, ConnectionSecrets secrets);
}

class SecureCodexProfileStore implements CodexProfileStore {
  static const _profileKey = 'pocket_relay.profile';
  static const _legacyProfileKey = 'codex_pocket.profile';
  static const _obsoletePreferencesKey = 'pocket_relay.preferences';
  static const _passwordKey = 'pocket_relay.secret.password';
  static const _legacyPasswordKey = 'codex_pocket.secret.password';
  static const _privateKeyKey = 'pocket_relay.secret.private_key';
  static const _legacyPrivateKeyKey = 'codex_pocket.secret.private_key';
  static const _privateKeyPassphraseKey =
      'pocket_relay.secret.private_key_passphrase';
  static const _legacyPrivateKeyPassphraseKey =
      'codex_pocket.secret.private_key_passphrase';

  final FlutterSecureStorage _secureStorage;

  SecureCodexProfileStore({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  @override
  Future<SavedProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawProfile =
        prefs.getString(_profileKey) ?? prefs.getString(_legacyProfileKey);
    await prefs.remove(_obsoletePreferencesKey);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));

    await _writeSecret(_passwordKey, secrets.password);
    await _writeSecret(_privateKeyKey, secrets.privateKeyPem);
    await _writeSecret(_privateKeyPassphraseKey, secrets.privateKeyPassphrase);
  }

  Future<void> _writeSecret(String key, String value) async {
    if (value.trim().isEmpty) {
      await _secureStorage.delete(key: key);
      return;
    }

    await _secureStorage.write(key: key, value: value);
  }

  Future<String> _readSecret(String key, String legacyKey) async {
    return await _secureStorage.read(key: key) ??
        await _secureStorage.read(key: legacyKey) ??
        '';
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
