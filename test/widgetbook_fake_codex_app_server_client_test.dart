import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/widgetbook/support/fake_codex_app_server_client.dart';

void main() {
  test('returns summary and history thread contracts', () async {
    final client = WidgetbookFakeCodexAppServerClient();

    final summary = await client.readThread(threadId: 'thread_widgetbook');
    final history = await client.readThreadWithTurns(
      threadId: 'thread_widgetbook',
    );

    expect(summary, isNotNull);
    expect(summary.id, 'thread_widgetbook');
    expect(history, isNotNull);
    expect(history.id, 'thread_widgetbook');
    expect(history.turns, isEmpty);
  });
}
