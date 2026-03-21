import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_conversation_state_store.dart';
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

  test('loadState returns empty state when no saved connection state exists', () async {
    final preferences = SharedPreferencesAsync();
    final store = SecureCodexConnectionConversationStateStore(
      preferences: preferences,
    );

    final state = await store.loadState('conn_a');

    expect(state, const SavedConnectionConversationState());
  });

  test('saveState persists only normalized selectedThreadId', () async {
    final preferences = SharedPreferencesAsync();
    final store = SecureCodexConnectionConversationStateStore(
      preferences: preferences,
    );

    await store.saveState(
      'conn_a',
      const SavedConnectionConversationState(
        selectedThreadId: ' thread_saved ',
      ),
    );

    expect(
      await preferences.getString(
        'pocket_relay.connection.conn_a.conversation_state',
      ),
      jsonEncode(<String, Object?>{'selectedThreadId': 'thread_saved'}),
    );
  });

  test('deleteState removes saved conversation state', () async {
    final preferences = SharedPreferencesAsync();
    final store = SecureCodexConnectionConversationStateStore(
      preferences: preferences,
    );

    await store.saveState(
      'conn_a',
      const SavedConnectionConversationState(selectedThreadId: 'thread_saved'),
    );

    await store.deleteState('conn_a');

    expect(
      await preferences.getString(
        'pocket_relay.connection.conn_a.conversation_state',
      ),
      isNull,
    );
  });
}
