import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_process_launcher.dart';

void main() {
  test('rejects remote mode for the generic process launcher path', () async {
    var localCalls = 0;

    await expectLater(
      () => openCodexAppServerProcess(
        profile: _profile(ConnectionMode.remote),
        secrets: const ConnectionSecrets(password: 'secret'),
        emitEvent: (_) {},
        localLauncher:
            ({required profile, required secrets, required emitEvent}) {
              localCalls += 1;
              throw StateError('should not use local launcher');
            },
      ),
      throwsA(
        isA<CodexAppServerException>().having(
          (error) => error.message,
          'message',
          contains('managed-owner websocket transport path'),
        ),
      ),
    );

    expect(localCalls, 0);
  });

  test('delegates local mode to the local launcher', () async {
    var localCalls = 0;

    await openCodexAppServerProcess(
      profile: _profile(ConnectionMode.local),
      secrets: const ConnectionSecrets(),
      emitEvent: (_) {},
      localLauncher:
          ({required profile, required secrets, required emitEvent}) async {
            localCalls += 1;
            return _FakeProcess();
          },
    );

    expect(localCalls, 1);
  });

  test(
    'rejects remote mode for the generic transport opener path',
    () async {
      var localCalls = 0;

      await expectLater(
        () => openCodexAppServerTransport(
          profile: _profile(ConnectionMode.remote),
          secrets: const ConnectionSecrets(password: 'secret'),
          emitEvent: (_) {},
          localLauncher:
              ({required profile, required secrets, required emitEvent}) {
                localCalls += 1;
                throw StateError('should not use local launcher');
              },
        ),
        throwsA(
          isA<CodexAppServerException>().having(
            (error) => error.message,
            'message',
            contains('managed-owner websocket transport path'),
          ),
        ),
      );

      expect(localCalls, 0);
    },
  );

  test(
    'opens a transport that delegates local mode to the local launcher',
    () async {
      var localCalls = 0;

      final transport = await openCodexAppServerTransport(
        profile: _profile(ConnectionMode.local),
        secrets: const ConnectionSecrets(),
        emitEvent: (_) {},
        localLauncher:
            ({required profile, required secrets, required emitEvent}) async {
              localCalls += 1;
              return _FakeProcess();
            },
      );

      expect(transport, isA<CodexAppServerTransport>());
      expect(localCalls, 1);
      await transport.close();
    },
  );
}

ConnectionProfile _profile(ConnectionMode mode) {
  return ConnectionProfile.defaults().copyWith(
    connectionMode: mode,
    host: 'example.com',
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
  );
}

final class _FakeProcess implements CodexAppServerProcess {
  final _stdinController = StreamController<Uint8List>();
  final _stdoutController = StreamController<Uint8List>.broadcast();
  final _stderrController = StreamController<Uint8List>.broadcast();

  @override
  Stream<Uint8List> get stdout => _stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => _stderrController.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdinController.sink;

  @override
  Future<void> get done => Future<void>.value();

  @override
  int? get exitCode => 0;

  @override
  Future<void> close() async {
    unawaited(_stdinController.close());
    await _stdoutController.close();
    await _stderrController.close();
  }
}
