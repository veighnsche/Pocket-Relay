import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_thread_read_fixture_sanitizer.dart';

void main() {
  test(
    'sanitizes live thread/read fixtures while preserving protocol shape',
    () {
      final rawFixture = _loadFixture(
        'test/fixtures/app_server/thread_read/reference_nested_history.json',
      );

      final sanitized = CodexAppServerThreadReadFixtureSanitizer().sanitize(
        rawFixture,
      );

      final thread = sanitized['thread'] as Map<String, dynamic>;
      final turns = thread['turns'] as List<dynamic>;
      final turn = turns.single as Map<String, dynamic>;
      final items = turn['items'] as List<dynamic>;
      final userItem = items.first as Map<String, dynamic>;
      final userContent =
          (userItem['content'] as List<dynamic>).single as Map<String, dynamic>;

      expect(thread['id'], '<thread_1>');
      expect(thread['preview'], '<preview_1>');
      expect(thread['path'], '<path_1>');
      expect(thread['cwd'], '<cwd_1>');
      expect(thread['name'], '<name_1>');
      expect((thread['source'] as Map<String, dynamic>)['kind'], 'app-server');
      expect(turn['id'], '<turn_1>');
      expect(userItem['id'], '<item_1>');
      expect(userItem['type'], 'userMessage');
      expect(userItem['status'], 'completed');
      expect(userContent['type'], 'text');
      expect(userContent['text'], '<text_1>');
    },
  );
}

Map<String, dynamic> _loadFixture(String path) {
  final text = File(path).readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}
