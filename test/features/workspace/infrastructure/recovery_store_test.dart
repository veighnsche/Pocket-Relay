import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/workspace/domain/connection_workspace_state.dart';
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
      'backgroundedLifecycleState': 'paused',
    });

    expect(state.connectionId, 'conn_primary');
    expect(state.draftText, 'Draft');
    expect(state.selectedThreadId, isNull);
    expect(state.backgroundedAt, isNotNull);
    expect(
      state.backgroundedLifecycleState,
      ConnectionWorkspaceBackgroundLifecycleState.paused,
    );
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
        secureStorage
            .data['pocket_relay.workspace.recovery_state.draft_text.conn_primary'],
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
        secureStorage
            .data['pocket_relay.workspace.recovery_state.draft_text.conn_primary'],
        'legacy secret',
      );
    },
  );

  test(
    'secure store migrates legacy global secure drafts into a connection-scoped key on load',
    () async {
      final secureStorage = _FakeFlutterSecureStorage(<String, String>{
        'pocket_relay.workspace.recovery_state.draft_text': 'legacy global',
      });
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'pocket_relay.workspace.recovery_state',
        '{"connectionId":"conn_primary","selectedThreadId":"thread_saved","backgroundedAt":"2026-03-22T12:00:00.000Z"}',
      );
      final store = SecureConnectionWorkspaceRecoveryStore(
        secureStorage: secureStorage,
        preferences: preferences,
      );

      final loadedState = await store.load();

      expect(loadedState, isNotNull);
      expect(loadedState!.draftText, 'legacy global');
      expect(
        secureStorage
            .data['pocket_relay.workspace.recovery_state.draft_text.conn_primary'],
        'legacy global',
      );
      expect(
        secureStorage.data['pocket_relay.workspace.recovery_state.draft_text'],
        isNull,
      );
    },
  );

  test(
    'secure store keeps drafts bound to their connection when a later metadata write is interrupted',
    () async {
      final secureStorage = _FakeFlutterSecureStorage(<String, String>{});
      final preferences = SharedPreferencesAsync();
      final store = SecureConnectionWorkspaceRecoveryStore(
        secureStorage: secureStorage,
        preferences: preferences,
      );

      await store.save(
        const ConnectionWorkspaceRecoveryState(
          connectionId: 'conn_primary',
          selectedThreadId: 'thread_primary',
          draftText: 'primary draft',
        ),
      );

      secureStorage
              .data['pocket_relay.workspace.recovery_state.draft_text.conn_secondary'] =
          'secondary draft';

      final loadedState = await store.load();

      expect(loadedState, isNotNull);
      expect(loadedState!.connectionId, 'conn_primary');
      expect(loadedState.draftText, 'primary draft');
    },
  );

  test(
    'legacy preference drafts stay persisted if secure migration fails before completion',
    () async {
      final secureStorage = _ThrowingFlutterSecureStorage(
        <String, String>{},
        keyToThrowOn:
            'pocket_relay.workspace.recovery_state.draft_text.conn_primary',
      );
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'pocket_relay.workspace.recovery_state',
        '{"connectionId":"conn_primary","selectedThreadId":"thread_saved","draftText":"legacy secret","backgroundedAt":"2026-03-22T12:00:00.000Z"}',
      );
      final store = SecureConnectionWorkspaceRecoveryStore(
        secureStorage: secureStorage,
        preferences: preferences,
      );

      await expectLater(store.load(), throwsA(isA<StateError>()));

      expect(
        await preferences.getString('pocket_relay.workspace.recovery_state'),
        contains('"draftText":"legacy secret"'),
      );
    },
  );

  test(
    'secure store clears corrupted recovery metadata and throws a typed corruption exception',
    () async {
      final secureStorage = _FakeFlutterSecureStorage(<String, String>{
        'pocket_relay.workspace.recovery_state.draft_text': 'legacy global',
      });
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'pocket_relay.workspace.recovery_state',
        '{not valid json',
      );
      final store = SecureConnectionWorkspaceRecoveryStore(
        secureStorage: secureStorage,
        preferences: preferences,
      );

      await expectLater(
        store.load(),
        throwsA(
          isA<ConnectionWorkspaceRecoveryStoreCorruptedException>().having(
            (error) => error.detail,
            'detail',
            contains('malformed JSON'),
          ),
        ),
      );

      expect(
        await preferences.getString('pocket_relay.workspace.recovery_state'),
        isNull,
      );
      expect(
        secureStorage.data['pocket_relay.workspace.recovery_state.draft_text'],
        isNull,
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

class _ThrowingFlutterSecureStorage extends _FakeFlutterSecureStorage {
  _ThrowingFlutterSecureStorage(super.data, {required this.keyToThrowOn});

  final String keyToThrowOn;

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
    if (key == keyToThrowOn) {
      throw StateError('secure storage unavailable');
    }
    await super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}
