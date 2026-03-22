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
    final state = ConnectionWorkspaceRecoveryState.fromJson(
      <String, dynamic>{
        'connectionId': 'conn_primary',
        'draftText': 'Draft',
        'selectedThreadId': '   ',
        'backgroundedAt': '2026-03-22T10:00:00.000Z',
      },
    );

    expect(state.connectionId, 'conn_primary');
    expect(state.draftText, 'Draft');
    expect(state.selectedThreadId, isNull);
    expect(state.backgroundedAt, isNotNull);
  });

  test(
    'secure store does not persist draft text to SharedPreferences',
    () async {
      final preferences = SharedPreferencesAsync();
      final store = SecureConnectionWorkspaceRecoveryStore(
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

      final loadedState = await store.load();
      expect(loadedState, isNotNull);
      expect(loadedState!.connectionId, 'conn_primary');
      expect(loadedState.selectedThreadId, 'thread_saved');
      expect(loadedState.draftText, isEmpty);
    },
  );

  test(
    'secure store removes previously persisted legacy draft text on load',
    () async {
      final preferences = SharedPreferencesAsync();
      await preferences.setString(
        'pocket_relay.workspace.recovery_state',
        '{"connectionId":"conn_primary","selectedThreadId":"thread_saved","draftText":"legacy secret","backgroundedAt":"2026-03-22T12:00:00.000Z"}',
      );
      final store = SecureConnectionWorkspaceRecoveryStore(
        preferences: preferences,
      );

      final loadedState = await store.load();
      final rawState = await preferences.getString(
        'pocket_relay.workspace.recovery_state',
      );

      expect(loadedState, isNotNull);
      expect(loadedState!.draftText, isEmpty);
      expect(rawState, isNotNull);
      expect(rawState, isNot(contains('legacy secret')));
      expect(rawState, isNot(contains('draftText')));
    },
  );
}
