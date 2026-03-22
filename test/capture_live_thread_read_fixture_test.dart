import 'package:flutter_test/flutter_test.dart';

import '../tool/capture_live_thread_read_fixture.dart';

void main() {
  test('buildCodexLaunchInvocation splits executable and arguments', () {
    final invocation = buildCodexLaunchInvocation(
      'just --justfile "dev tools/Justfile" codex-mcp',
    );

    expect(invocation.executable, 'just');
    expect(invocation.arguments, <String>[
      '--justfile',
      'dev tools/Justfile',
      'codex-mcp',
    ]);
  });

  test('buildCodexLaunchInvocation rejects unterminated quoting', () {
    expect(
      () => buildCodexLaunchInvocation('"unterminated'),
      throwsFormatException,
    );
  });
}
