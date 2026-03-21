import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_thread_read_decoder.dart';

void main() {
  const decoder = CodexAppServerThreadReadDecoder();

  test('decodes nested thread/read history fixture', () {
    final thread = decoder.decodeHistoryResponse(
      _loadFixture(
        'test/fixtures/app_server/thread_read/reference_nested_history.json',
      ),
      fallbackThreadId: 'thread_nested',
    );

    expect(thread.id, 'thread_nested');
    expect(thread.name, 'Saved thread');
    expect(thread.preview, 'Restore this');
    expect(thread.cwd, '/workspace');
    expect(thread.path, '/workspace/.codex/threads/thread_nested.json');
    expect(thread.modelProvider, 'openai');
    expect(thread.sourceKind, 'app-server');
    expect(thread.agentNickname, 'builder');
    expect(thread.agentRole, 'worker');
    expect(thread.promptCount, 1);
    expect(thread.turns, hasLength(1));
    expect(thread.turns.single.id, 'turn_saved');
    expect(thread.turns.single.items, hasLength(2));
  });

  test('decodes flat thread/read history fixture', () {
    final thread = decoder.decodeHistoryResponse(
      _loadFixture(
        'test/fixtures/app_server/thread_read/reference_flat_history.json',
      ),
      fallbackThreadId: 'thread_flat',
    );

    expect(thread.id, 'thread_flat');
    expect(thread.name, 'Saved thread');
    expect(thread.preview, 'Restore this');
    expect(thread.cwd, '/workspace');
    expect(thread.modelProvider, 'openai');
    expect(thread.sourceKind, 'app-server');
    expect(thread.promptCount, 1);
    expect(thread.turns, hasLength(1));
    expect(thread.turns.single.id, 'turn_saved');
    expect(thread.turns.single.items, hasLength(2));
  });
}

Map<String, dynamic> _loadFixture(String path) {
  final text = File(path).readAsStringSync();
  return jsonDecode(text) as Map<String, dynamic>;
}
