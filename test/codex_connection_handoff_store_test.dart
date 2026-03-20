import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/storage/codex_connection_handoff_store.dart';
import 'package:pocket_relay/src/core/storage/codex_conversation_handoff_store.dart';
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

  test(
    'load migrates legacy per-connection handoff data into conversation state',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'pocket_relay.connection.conn_secondary.conversation_handoff':
            jsonEncode(<String, Object?>{'resumeThreadId': 'thread_legacy'}),
      });

      final preferences = SharedPreferencesAsync();
      final store = SecureCodexConnectionHandoffStore(preferences: preferences);

      final handoff = await store.load('conn_secondary');

      expect(handoff.normalizedResumeThreadId, 'thread_legacy');
      expect(
        await preferences.getString(
          'pocket_relay.connection.conn_secondary.conversation_handoff',
        ),
        isNull,
      );
      expect(
        await preferences.getString(
          'pocket_relay.connection.conn_secondary.conversation_state',
        ),
        isNotNull,
      );
    },
  );

  test('save and delete isolate handoffs by connection id', () async {
    final preferences = SharedPreferencesAsync();
    final store = SecureCodexConnectionHandoffStore(preferences: preferences);

    await store.save(
      'conn_a',
      const SavedConversationHandoff(resumeThreadId: 'thread_a'),
    );
    await store.save(
      'conn_b',
      const SavedConversationHandoff(resumeThreadId: 'thread_b'),
    );
    await store.delete('conn_a');

    expect(await store.load('conn_a'), const SavedConversationHandoff());
    expect(
      await store.load('conn_b'),
      const SavedConversationHandoff(resumeThreadId: 'thread_b'),
    );
  });
}
