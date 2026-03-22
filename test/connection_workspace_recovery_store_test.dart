import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/workspace/infrastructure/connection_workspace_recovery_store.dart';
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
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = originalAsyncPlatform;
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('fromJson normalizes blank selectedThreadId to null', () {
    final state = ConnectionWorkspaceRecoveryState.fromJson(<String, dynamic>{
      'connectionId': 'conn_primary',
      'draftText': 'Draft',
      'selectedThreadId': '   ',
      'backgroundedAt': '2026-03-22T10:00:00.000Z',
    });

    expect(state.connectionId, 'conn_primary');
    expect(state.draftText, 'Draft');
    expect(state.selectedThreadId, isNull);
    expect(state.backgroundedAt, isNotNull);
  });

  test(
    'secure store keeps draft text out of SharedPreferences and restores it from secure storage',
    () async {
      final secureStorage = _FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final store = SecureConnectionWorkspaceRecoveryStore(
        secureStorage: secureStorage,
        preferences: preferences,
      );

      await store.save(
        ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          selectedThreadId: 'thread_saved',
          draftText: 'super secret draft',
          backgroundedAt: DateTime.utc(2026, 3, 22, 12),
        ),
      );

      final rawState = await preferences.getString(
        'pocket_relay.workspace.recovery_state',
      );

      expect(rawState, isNotNull);
      expect(rawState, isNot(contains('super secret draft')));
      expect(rawState, isNot(contains('draftText')));
      expect(
        secureStorage.data['pocket_relay.workspace.recovery_state.draft_text'],
        'super secret draft',
      );

      final loadedState = await store.load();
      expect(loadedState, isNotNull);
      expect(loadedState!.connectionId, 'conn_primary');
      expect(loadedState.selectedThreadId, 'thread_saved');
      expect(loadedState.draftText, 'super secret draft');
    },
  );

  test(
    'secure store migrates legacy preference-backed draft text into secure storage on load',
    () async {
      final secureStorage = _FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'pocket_relay.workspace.recovery_state',
        '{"connectionId":"conn_primary","selectedThreadId":"thread_saved","draftText":"legacy secret","backgroundedAt":"2026-03-22T12:00:00.000Z"}',
      );
      final store = SecureConnectionWorkspaceRecoveryStore(
        secureStorage: secureStorage,
        preferences: preferences,
      );

      final loadedState = await store.load();
      final rawState = await preferences.getString(
        'pocket_relay.workspace.recovery_state',
      );

      expect(loadedState, isNotNull);
      expect(loadedState!.draftText, 'legacy secret');
      expect(rawState, isNotNull);
      expect(rawState, isNot(contains('legacy secret')));
      expect(rawState, isNot(contains('draftText')));
      expect(
        secureStorage.data['pocket_relay.workspace.recovery_state.draft_text'],
        'legacy secret',
      );
    },
  );
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
