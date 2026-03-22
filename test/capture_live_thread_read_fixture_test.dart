import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/capture_live_thread_read_fixture.dart';

void main() {
  test('buildCodexLaunchInvocation preserves shell launch commands on POSIX', () {
    final invocation = buildCodexLaunchInvocation(
      r'PATH="$HOME/bin:$PATH" codex',
      platform: TargetPlatform.macOS,
    );

    expect(invocation.executable, 'bash');
    expect(invocation.arguments, <String>[
      '-lc',
      r'PATH="$HOME/bin:$PATH" codex app-server --listen stdio://',
    ]);
  });

  test(
    'buildCodexLaunchInvocation preserves chained shell wrappers on POSIX',
    () {
      final invocation = buildCodexLaunchInvocation(
        'source ~/.asdf/asdf.sh && codex',
        platform: TargetPlatform.linux,
      );

      expect(invocation.executable, 'bash');
      expect(invocation.arguments, <String>[
        '-lc',
        'source ~/.asdf/asdf.sh && codex app-server --listen stdio://',
      ]);
    },
  );

  test('buildCodexLaunchInvocation preserves shell launch commands on Windows', () {
    final invocation = buildCodexLaunchInvocation(
      'codex.cmd',
      platform: TargetPlatform.windows,
    );

    expect(invocation.executable, 'cmd.exe');
    expect(invocation.arguments, <String>[
      '/C',
      'codex.cmd app-server --listen stdio://',
    ]);
  });

  test('buildCodexLaunchInvocation rejects a blank command', () {
    expect(
      () => buildCodexLaunchInvocation('   '),
      throwsFormatException,
    );
  });
}
