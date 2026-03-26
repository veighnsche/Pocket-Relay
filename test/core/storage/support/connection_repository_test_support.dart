import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void registerConnectionRepositoryStorageLifecycle() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferencesAsyncPlatform? originalAsyncPlatform;

  setUp(() {
    originalAsyncPlatform = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });
}

SecureCodexConnectionRepository buildSecureConnectionRepository({
  required FakeFlutterSecureStorage secureStorage,
  required SharedPreferencesAsync preferences,
  required String Function() connectionIdGenerator,
}) {
  return SecureCodexConnectionRepository(
    secureStorage: secureStorage,
    preferences: preferences,
    connectionIdGenerator: connectionIdGenerator,
  );
}

Future<void> writeConnectionIndex(
  SharedPreferencesAsync preferences, {
  required List<String> orderedConnectionIds,
}) async {
  await preferences.setString(
    'pocket_relay.connections.index',
    jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'orderedConnectionIds': orderedConnectionIds,
    }),
  );
}

Future<void> writeStoredConnectionProfile(
  SharedPreferencesAsync preferences, {
  required String connectionId,
  required ConnectionProfile profile,
}) async {
  await preferences.setString(
    'pocket_relay.connection.$connectionId.profile',
    jsonEncode(profile.toJson()),
  );
}

class FakeFlutterSecureStorage extends FlutterSecureStorage {
  FakeFlutterSecureStorage(this.data);

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
  Future<Map<String, String>> readAll({
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return Map<String, String>.from(data);
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
