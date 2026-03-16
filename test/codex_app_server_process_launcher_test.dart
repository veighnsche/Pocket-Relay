import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/infrastructure/app_server/codex_app_server_process_launcher.dart';

void main() {
  test('delegates remote mode to the remote launcher', () async {
    var remoteCalls = 0;
    var localCalls = 0;

    await openCodexAppServerProcess(
      profile: _profile(ConnectionMode.remote),
      secrets: const ConnectionSecrets(password: 'secret'),
      emitEvent: (_) {},
      remoteLauncher:
          ({required profile, required secrets, required emitEvent}) async {
            remoteCalls += 1;
            return _FakeProcess();
          },
      localLauncher:
          ({required profile, required secrets, required emitEvent}) {
            localCalls += 1;
            throw StateError('should not use local launcher');
          },
    );

    expect(remoteCalls, 1);
    expect(localCalls, 0);
  });

  test('delegates local mode to the local launcher', () async {
    var remoteCalls = 0;
    var localCalls = 0;

    await openCodexAppServerProcess(
      profile: _profile(ConnectionMode.local),
      secrets: const ConnectionSecrets(),
      emitEvent: (_) {},
      remoteLauncher:
          ({required profile, required secrets, required emitEvent}) {
            remoteCalls += 1;
            throw StateError('should not use remote launcher');
          },
      localLauncher:
          ({required profile, required secrets, required emitEvent}) async {
            localCalls += 1;
            return _FakeProcess();
          },
    );

    expect(remoteCalls, 0);
    expect(localCalls, 1);
  });
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
    await _stdinController.close();
    await _stdoutController.close();
    await _stderrController.close();
  }
}
