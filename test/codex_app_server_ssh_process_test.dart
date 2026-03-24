import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_relay/src/core/models/connection_models.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_client.dart';
import 'package:pocket_relay/src/features/chat/transport/app_server/codex_app_server_ssh_process.dart';

void main() {
  test('builds a remote command for a plain codex binary', () {
    final command = buildSshCodexAppServerCommand(
      profile: _profile().copyWith(codexPath: 'codex'),
    );

    expect(
      command,
      "bash -lc 'cd '\"'\"'/workspace'\"'\"' && codex app-server --listen stdio://'",
    );
  });

  test('builds a remote command for a launch command with spaces', () {
    final command = buildSshCodexAppServerCommand(
      profile: _profile().copyWith(codexPath: 'just codex-mcp'),
    );

    expect(
      command,
      "bash -lc 'cd '\"'\"'/workspace'\"'\"' && just codex-mcp app-server --listen stdio://'",
    );
  });

  test(
    'emits a typed connect-failed event when bootstrap connect fails',
    () async {
      final events = <CodexAppServerEvent>[];

      await expectLater(
        openSshCodexAppServerProcess(
          profile: _profile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          emitEvent: events.add,
          sshBootstrap:
              ({required profile, required secrets, required verifyHostKey}) {
                throw SSHSocketError('connection refused');
              },
        ),
        throwsA(isA<SSHSocketError>()),
      );

      expect(events.single, isA<CodexAppServerSshConnectFailedEvent>());
      final event = events.single as CodexAppServerSshConnectFailedEvent;
      expect(event.host, 'example.com');
      expect(event.port, 22);
      expect(event.message, 'connection refused');
    },
  );

  test(
    'emits a typed host-key mismatch event without a duplicate connect failure',
    () async {
      final events = <CodexAppServerEvent>[];

      await expectLater(
        openSshCodexAppServerProcess(
          profile: _profile().copyWith(hostFingerprint: 'aa:bb:cc:dd'),
          secrets: const ConnectionSecrets(password: 'secret'),
          emitEvent: events.add,
          sshBootstrap:
              ({required profile, required secrets, required verifyHostKey}) {
                final accepted = verifyHostKey('ssh-ed25519', '11:22:33:44');
                expect(accepted, isFalse);
                throw SSHHostkeyError('Hostkey verification failed');
              },
        ),
        throwsA(isA<SSHHostkeyError>()),
      );

      expect(events, hasLength(1));
      expect(events.single, isA<CodexAppServerSshHostKeyMismatchEvent>());
      final event = events.single as CodexAppServerSshHostKeyMismatchEvent;
      expect(event.keyType, 'ssh-ed25519');
      expect(event.expectedFingerprint, 'aa:bb:cc:dd');
      expect(event.actualFingerprint, '11:22:33:44');
    },
  );

  test('emits a typed auth-failed event when authentication fails', () async {
    final events = <CodexAppServerEvent>[];
    final client = _FakeSshBootstrapClient(
      authenticateError: SSHAuthFailError('Permission denied'),
    );

    await expectLater(
      openSshCodexAppServerProcess(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        emitEvent: events.add,
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return client;
            },
      ),
      throwsA(isA<SSHAuthFailError>()),
    );

    expect(events.single, isA<CodexAppServerSshAuthenticationFailedEvent>());
    final event = events.single as CodexAppServerSshAuthenticationFailedEvent;
    expect(event.username, 'vince');
    expect(event.authMode, AuthMode.password);
    expect(event.message, 'Permission denied');
    expect(client.closeCalls, 1);
  });

  test(
    'emits an unpinned-host-key event and rejects the connection',
    () async {
      final events = <CodexAppServerEvent>[];

      await expectLater(
        openSshCodexAppServerProcess(
          profile: _profile(),
          secrets: const ConnectionSecrets(password: 'secret'),
          emitEvent: events.add,
          sshBootstrap:
              ({required profile, required secrets, required verifyHostKey}) {
                final accepted = verifyHostKey(
                  'ssh-ed25519',
                  '7a:9f:d7:dc:2e:f2',
                );
                expect(accepted, isFalse);
                throw SSHHostkeyError('Hostkey verification failed');
              },
        ),
        throwsA(isA<SSHHostkeyError>()),
      );

      expect(events, hasLength(1));
      expect(events.single, isA<CodexAppServerUnpinnedHostKeyEvent>());
      final event = events.single as CodexAppServerUnpinnedHostKeyEvent;
      expect(event.host, 'example.com');
      expect(event.port, 22);
      expect(event.keyType, 'ssh-ed25519');
      expect(event.fingerprint, '7a:9f:d7:dc:2e:f2');
    },
  );

  test(
    'emits authenticated and remote-process-started events on success',
    () async {
      final events = <CodexAppServerEvent>[];
      final process = _FakeCodexAppServerProcess();
      final client = _FakeSshBootstrapClient(process: process);

      final launched = await openSshCodexAppServerProcess(
        profile: _profile().copyWith(hostFingerprint: '7a:9f:d7:dc:2e:f2'),
        secrets: const ConnectionSecrets(password: 'secret'),
        emitEvent: events.add,
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              final accepted = verifyHostKey(
                'ssh-ed25519',
                '7a:9f:d7:dc:2e:f2',
              );
              expect(accepted, isTrue);
              return client;
            },
      );

      expect(launched, same(process));
      expect(events, hasLength(2));
      expect(events[0], isA<CodexAppServerSshAuthenticatedEvent>());
      expect(events[1], isA<CodexAppServerSshRemoteProcessStartedEvent>());
      final started = events[1] as CodexAppServerSshRemoteProcessStartedEvent;
      expect(started.username, 'vince');
      expect(started.command, contains('codex app-server --listen stdio://'));
      expect(client.launchCommands, hasLength(1));
    },
  );

  test('emits a typed remote-launch-failed event when exec fails', () async {
    final events = <CodexAppServerEvent>[];
    final client = _FakeSshBootstrapClient(
      launchError: SSHChannelRequestError('exec request denied'),
    );

    await expectLater(
      openSshCodexAppServerProcess(
        profile: _profile(),
        secrets: const ConnectionSecrets(password: 'secret'),
        emitEvent: events.add,
        sshBootstrap:
            ({
              required profile,
              required secrets,
              required verifyHostKey,
            }) async {
              return client;
            },
      ),
      throwsA(isA<SSHChannelRequestError>()),
    );

    expect(events, hasLength(2));
    expect(events[0], isA<CodexAppServerSshAuthenticatedEvent>());
    expect(events[1], isA<CodexAppServerSshRemoteLaunchFailedEvent>());
    final event = events[1] as CodexAppServerSshRemoteLaunchFailedEvent;
    expect(event.message, 'exec request denied');
    expect(event.command, contains('codex app-server --listen stdio://'));
    expect(client.closeCalls, 1);
  });
}

ConnectionProfile _profile() {
  return const ConnectionProfile(
    label: 'Developer Box',
    host: 'example.com',
    port: 22,
    username: 'vince',
    workspaceDir: '/workspace',
    codexPath: 'codex',
    authMode: AuthMode.password,
    hostFingerprint: '',
    dangerouslyBypassSandbox: false,
    ephemeralSession: false,
  );
}

final class _FakeSshBootstrapClient implements CodexSshBootstrapClient {
  _FakeSshBootstrapClient({
    this.process,
    this.authenticateError,
    this.launchError,
  });

  final CodexAppServerProcess? process;
  final Object? authenticateError;
  final Object? launchError;

  int closeCalls = 0;
  final List<String> launchCommands = <String>[];

  @override
  Future<void> authenticate() async {
    if (authenticateError != null) {
      throw authenticateError!;
    }
  }

  @override
  Future<CodexAppServerProcess> launchProcess(String command) async {
    launchCommands.add(command);
    if (launchError != null) {
      throw launchError!;
    }
    return process ?? _FakeCodexAppServerProcess();
  }

  @override
  Future<CodexSshForwardChannel> forwardLocal(
    String remoteHost,
    int remotePort, {
    String localHost = 'localhost',
    int localPort = 0,
  }) {
    throw UnimplementedError('forwardLocal is not used in these tests');
  }

  @override
  void close() {
    closeCalls += 1;
  }
}

final class _FakeCodexAppServerProcess implements CodexAppServerProcess {
  final _stdoutController = StreamController<Uint8List>.broadcast();
  final _stderrController = StreamController<Uint8List>.broadcast();
  final _stdinController = StreamController<Uint8List>();
  final _doneCompleter = Completer<void>();

  @override
  Stream<Uint8List> get stdout => _stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => _stderrController.stream;

  @override
  StreamSink<Uint8List> get stdin => _stdinController.sink;

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  int? get exitCode => 0;

  @override
  Future<void> close() async {
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    await _stdoutController.close();
    await _stderrController.close();
    await _stdinController.close();
  }
}
