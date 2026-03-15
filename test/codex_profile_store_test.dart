import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_profile_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesAsyncPlatform? originalAsyncPlatform;

  setUp(() {
    originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'load migrates legacy profile data into SharedPreferencesAsync',
    () async {
      final profile = ConnectionProfile.defaults().copyWith(
        host: 'example.com',
        username: 'vince',
        workspaceDir: '/workspace/app',
      );
      SharedPreferences.setMockInitialValues(<String, Object>{
        'codex_pocket.profile': jsonEncode(profile.toJson()),
        'pocket_relay.preferences': jsonEncode(<String, Object>{
          'themeMode': 'dark',
        }),
      });
      final secureStorage = _FakeFlutterSecureStorage(<String, String>{
        'codex_pocket.secret.password': 'secret',
      });
      final preferences = SharedPreferencesAsync();
      final store = SecureCodexProfileStore(
        secureStorage: secureStorage,
        preferences: preferences,
      );

      final saved = await store.load();

      expect(saved.profile.host, 'example.com');
      expect(saved.profile.username, 'vince');
      expect(saved.profile.workspaceDir, '/workspace/app');
      expect(saved.secrets.password, 'secret');
      expect(
        await preferences.getString('pocket_relay.profile'),
        jsonEncode(profile.toJson()),
      );
      expect(await preferences.getString('codex_pocket.profile'), isNull);
      expect(await preferences.getString('pocket_relay.preferences'), isNull);
      expect(secureStorage.data['pocket_relay.secret.password'], 'secret');
      expect(secureStorage.data['codex_pocket.secret.password'], isNull);
    },
  );

  test('save writes profile data to SharedPreferencesAsync', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'pocket_relay.preferences': jsonEncode(<String, Object>{
        'themeMode': 'dark',
      }),
    });
    final secureStorage = _FakeFlutterSecureStorage(<String, String>{});
    final preferences = SharedPreferencesAsync();
    final store = SecureCodexProfileStore(
      secureStorage: secureStorage,
      preferences: preferences,
    );
    final profile = ConnectionProfile.defaults().copyWith(
      host: 'relay.example.com',
      username: 'vince',
    );
    final secrets = const ConnectionSecrets(
      password: 'secret',
      privateKeyPem: 'pem',
      privateKeyPassphrase: 'phrase',
    );

    await store.save(profile, secrets);

    expect(
      await preferences.getString('pocket_relay.profile'),
      jsonEncode(profile.toJson()),
    );
    expect(await preferences.getString('pocket_relay.preferences'), isNull);
    expect(secureStorage.data['pocket_relay.secret.password'], 'secret');
    expect(secureStorage.data['pocket_relay.secret.private_key'], 'pem');
    expect(
      secureStorage.data['pocket_relay.secret.private_key_passphrase'],
      'phrase',
    );
  });
}

class _FakeFlutterSecureStorage extends FlutterSecureStorage {
  _FakeFlutterSecureStorage(this.data);

  final Map<String, String> data;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
      return;
    }
    data[key] = value;
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data[key];
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}
