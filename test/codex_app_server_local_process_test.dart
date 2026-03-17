import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_local_process.dart';

void main() {
  test('builds a local macOS command for a plain codex binary', () {
    final invocation = buildLocalCodexAppServerInvocation(
      profile: _profile(),
      platform: TargetPlatform.macOS,
    );

    expect(invocation.executable, 'bash');
    expect(invocation.arguments, <String>[
      '-lc',
      'codex app-server --listen stdio://',
    ]);
  });

  test('builds a local Windows command for a plain codex binary', () {
    final invocation = buildLocalCodexAppServerInvocation(
      profile: _profile(),
      platform: TargetPlatform.windows,
    );

    expect(invocation.executable, 'cmd.exe');
    expect(invocation.arguments, <String>[
      '/C',
      'codex app-server --listen stdio://',
    ]);
  });

  test('emits a diagnostic event when local process startup fails', () async {
    final events = <CodexAppServerEvent>[];

    await expectLater(
      openLocalCodexAppServerProcess(
        profile: _profile(),
        secrets: const ConnectionSecrets(),
        emitEvent: events.add,
        processStarter:
            ({
              required executable,
              required arguments,
              required workingDirectory,
            }) {
              throw const ProcessException(
                'bash',
                <String>[],
                'missing shell',
                127,
              );
            },
      ),
      throwsA(isA<ProcessException>()),
    );

    expect(events.single, isA<CodexAppServerDiagnosticEvent>());
    final diagnostic = events.single as CodexAppServerDiagnosticEvent;
    expect(diagnostic.isError, isTrue);
    expect(
      diagnostic.message,
      contains('Failed to start local Codex app-server'),
    );
  });
}

ConnectionProfile _profile() {
  return ConnectionProfile.defaults().copyWith(
    connectionMode: ConnectionMode.local,
    workspaceDir: '/workspace',
    codexPath: 'codex',
  );
}
